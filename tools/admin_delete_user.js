#!/usr/bin/env node
/**
 * HHF Social — World-Class Admin Profile Takedown & Cascade Purge Tool
 *
 * Performs a complete, idempotent 10-step moderation takedown of a user profile
 * across Firebase Authentication, Cloud Storage, and Cloud Firestore, including
 * cross-user counter reconciliation (followers, following, likes, comments,
 * unread messages) and App Store Guideline 1.2 report resolution.
 *
 * Authentication (automatic fallback order):
 *   1. --service-account <path> or GOOGLE_APPLICATION_CREDENTIALS env var
 *   2. Local signed-in Firebase CLI session (firebase-tools configstore)
 *
 * Usage:
 *   node tools/admin_delete_user.js --username ilovenastysluts1k --dry-run
 *   node tools/admin_delete_user.js --username ilovenastysluts1k --execute --block-username
 *   node tools/admin_delete_user.js --uid <UID> --execute
 */

const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');

const PROJECT_ID = 'hhf-social';
const STORAGE_BUCKET = 'hhf-social.firebasestorage.app';
const FIRESTORE_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const STORAGE_BASE = `https://storage.googleapis.com/storage/v1/b/${encodeURIComponent(STORAGE_BUCKET)}/o`;
const AUTH_BASE = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT_ID}`;

// ─────────────────────────────────────────────────────────────────────────────
// CLI Argument Parsing
// ─────────────────────────────────────────────────────────────────────────────
function parseArgs(argv) {
  const args = {
    username: null,
    uid: null,
    dryRun: true,
    execute: false,
    blockUsername: true,
    serviceAccountPath: process.env.GOOGLE_APPLICATION_CREDENTIALS || null,
  };

  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--username' && argv[i + 1]) {
      args.username = argv[++i].toLowerCase().trim().replace(/^@/, '');
    } else if (arg === '--uid' && argv[i + 1]) {
      args.uid = argv[++i].trim();
    } else if (arg === '--service-account' && argv[i + 1]) {
      args.serviceAccountPath = argv[++i];
    } else if (arg === '--dry-run') {
      args.dryRun = true;
      args.execute = false;
    } else if (arg === '--execute') {
      args.execute = true;
      args.dryRun = false;
    } else if (arg === '--block-username') {
      args.blockUsername = true;
    } else if (arg === '--release-username') {
      args.blockUsername = false;
    }
  }

  return args;
}

// ─────────────────────────────────────────────────────────────────────────────
// Authentication (Service Account JWT OR Firebase CLI Session)
// ─────────────────────────────────────────────────────────────────────────────
async function getAccessToken(serviceAccountPath) {
  // 1. Service Account JSON file if provided
  if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
    const sa = JSON.parse(fs.readFileSync(serviceAccountPath, 'utf8'));
    const now = Math.floor(Date.now() / 1000);
    const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
    const claim = Buffer.from(
      JSON.stringify({
        iss: sa.client_email,
        sub: sa.client_email,
        aud: 'https://oauth2.googleapis.com/token',
        iat: now,
        exp: now + 3600,
        scope: [
          'https://www.googleapis.com/auth/cloud-platform',
          'https://www.googleapis.com/auth/firebase',
          'https://www.googleapis.com/auth/identitytoolkit',
          'https://www.googleapis.com/auth/userinfo.email',
        ].join(' '),
      })
    ).toString('base64url');

    const signer = crypto.createSign('RSA-SHA256');
    signer.update(`${header}.${claim}`);
    const signature = signer.sign(sa.private_key, 'base64url');
    const assertion = `${header}.${claim}.${signature}`;

    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    });
    if (!res.ok) {
      throw new Error(`Service account token exchange failed: ${await res.text()}`);
    }
    const data = await res.json();
    console.log(`✓ Authenticated via Service Account (${sa.client_email})`);
    return data.access_token;
  }

  // 2. Fallback to signed-in Firebase CLI session
  const possiblePaths = [
    path.join(process.env.APPDATA || '', 'npm', 'node_modules', 'firebase-tools', 'lib', 'auth.js'),
    path.join(os.homedir(), '.nvm', 'versions', 'node', process.version, 'lib', 'node_modules', 'firebase-tools', 'lib', 'auth.js'),
    '/usr/local/lib/node_modules/firebase-tools/lib/auth.js',
  ];

  for (const authPath of possiblePaths) {
    if (fs.existsSync(authPath)) {
      const fbAuth = require(authPath);
      const account = fbAuth.getGlobalDefaultAccount();
      if (account && account.tokens && account.tokens.refresh_token) {
        const tokenObj = await fbAuth.getAccessToken(
          account.tokens.refresh_token,
          account.tokens.scopes || []
        );
        console.log(`✓ Authenticated via Firebase CLI (${account.user.email})`);
        return tokenObj.access_token;
      }
    }
  }

  throw new Error(
    'No credentials found. Either log in with `firebase login` or pass `--service-account <path/to/key.json>`.'
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REST Helpers (Firestore, Storage, Auth)
// ─────────────────────────────────────────────────────────────────────────────
function createApiClient(token) {
  const headers = {
    Authorization: `Bearer ${token}`,
    'x-goog-user-project': PROJECT_ID,
    'Content-Type': 'application/json',
  };

  async function request(url, options = {}) {
    const res = await fetch(url, {
      ...options,
      headers: { ...headers, ...(options.headers || {}) },
    });
    if (res.status === 404) return null;
    const text = await res.text();
    const json = text ? JSON.parse(text) : {};
    if (!res.ok) {
      const err = new Error(`HTTP ${res.status} on ${url}: ${text}`);
      err.status = res.status;
      err.body = json;
      throw err;
    }
    return json;
  }

  // Convert Firestore REST field map into plain JS object
  function fromFirestoreFields(fields = {}) {
    const out = {};
    for (const [k, v] of Object.entries(fields)) {
      if ('stringValue' in v) out[k] = v.stringValue;
      else if ('integerValue' in v) out[k] = Number(v.integerValue);
      else if ('doubleValue' in v) out[k] = Number(v.doubleValue);
      else if ('booleanValue' in v) out[k] = v.booleanValue;
      else if ('nullValue' in v) out[k] = null;
      else if ('timestampValue' in v) out[k] = v.timestampValue;
      else if ('arrayValue' in v) {
        out[k] = (v.arrayValue.values || []).map((item) => fromFirestoreFields({ item }).item);
      } else if ('mapValue' in v) {
        out[k] = fromFirestoreFields(v.mapValue.fields || {});
      }
    }
    return out;
  }

  function toFirestoreValue(val) {
    if (val === null || val === undefined) return { nullValue: null };
    if (typeof val === 'string') return { stringValue: val };
    if (typeof val === 'boolean') return { booleanValue: val };
    if (typeof val === 'number') {
      return Number.isInteger(val)
        ? { integerValue: String(val) }
        : { doubleValue: val };
    }
    if (val instanceof Date) return { timestampValue: val.toISOString() };
    if (Array.isArray(val)) {
      return { arrayValue: { values: val.map(toFirestoreValue) } };
    }
    if (typeof val === 'object') {
      const fields = {};
      for (const [k, v] of Object.entries(val)) {
        fields[k] = toFirestoreValue(v);
      }
      return { mapValue: { fields } };
    }
    return { stringValue: String(val) };
  }

  function docIdFromName(name) {
    const parts = name.split('/');
    return parts[parts.length - 1];
  }

  return {
    request,
    fromFirestoreFields,
    toFirestoreValue,
    docIdFromName,

    async getDoc(relPath) {
      const doc = await request(`${FIRESTORE_BASE}/${relPath}`);
      if (!doc || !doc.name) return null;
      return {
        id: docIdFromName(doc.name),
        name: doc.name,
        relPath,
        data: fromFirestoreFields(doc.fields),
      };
    },

    async setDoc(relPath, dataObj) {
      const fields = {};
      for (const [k, v] of Object.entries(dataObj)) {
        fields[k] = toFirestoreValue(v);
      }
      return request(`${FIRESTORE_BASE}/${relPath}`, {
        method: 'PATCH',
        body: JSON.stringify({ fields }),
      });
    },

    async patchFields(relPath, dataObj) {
      const fields = {};
      const maskParams = [];
      for (const [k, v] of Object.entries(dataObj)) {
        fields[k] = toFirestoreValue(v);
        maskParams.push(`updateMask.fieldPaths=${encodeURIComponent(k)}`);
      }
      return request(`${FIRESTORE_BASE}/${relPath}?${maskParams.join('&')}`, {
        method: 'PATCH',
        body: JSON.stringify({ fields }),
      });
    },

    async deleteDoc(relPath) {
      return request(`${FIRESTORE_BASE}/${relPath}`, { method: 'DELETE' });
    },

    async incrementField(relPath, fieldPath, delta) {
      return request(`https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:commit`, {
        method: 'POST',
        body: JSON.stringify({
          writes: [
            {
              transform: {
                document: `projects/${PROJECT_ID}/databases/(default)/documents/${relPath}`,
                fieldTransforms: [
                  {
                    fieldPath,
                    increment: { integerValue: String(delta) },
                  },
                ],
              },
              currentDocument: { exists: true },
            },
          ],
        }),
      });
    },

    async listSubcollection(parentRelPath, subcollectionId) {
      const docs = [];
      let pageToken = '';
      const basePath = parentRelPath
        ? `${FIRESTORE_BASE}/${parentRelPath}/${subcollectionId}`
        : `${FIRESTORE_BASE}/${subcollectionId}`;
      do {
        const q = pageToken ? `?pageSize=300&pageToken=${encodeURIComponent(pageToken)}` : '?pageSize=300';
        const res = await request(`${basePath}${q}`);
        if (res && res.documents) {
          for (const d of res.documents) {
            const rel = d.name.split('/documents/')[1];
            docs.push({
              id: docIdFromName(d.name),
              name: d.name,
              relPath: rel,
              data: fromFirestoreFields(d.fields),
            });
          }
        }
        pageToken = (res && res.nextPageToken) || '';
      } while (pageToken);
      return docs;
    },

    async runQuery(structuredQuery) {
      const res = await request(`${FIRESTORE_BASE}:runQuery`, {
        method: 'POST',
        body: JSON.stringify({ structuredQuery }),
      });
      if (!Array.isArray(res)) return [];
      return res
        .filter((r) => r.document)
        .map((r) => {
          const d = r.document;
          return {
            id: docIdFromName(d.name),
            name: d.name,
            relPath: d.name.split('/documents/')[1],
            data: fromFirestoreFields(d.fields),
          };
        });
    },

    async queryWhere(collectionId, fieldPath, op, value, allDescendants = false) {
      return this.runQuery({
        from: [{ collectionId, allDescendants }],
        where: {
          fieldFilter: {
            field: { fieldPath },
            op,
            value: toFirestoreValue(value),
          },
        },
      });
    },

    async listStoragePrefix(prefix) {
      const items = [];
      let pageToken = '';
      do {
        const params = new URLSearchParams({ prefix });
        if (pageToken) params.set('pageToken', pageToken);
        const res = await request(`${STORAGE_BASE}?${params.toString()}`);
        if (res && Array.isArray(res.items)) {
          items.push(...res.items);
        }
        pageToken = (res && res.nextPageToken) || '';
      } while (pageToken);
      return items;
    },

    async deleteStorageObject(objectName) {
      return request(`${STORAGE_BASE}/${encodeURIComponent(objectName)}`, {
        method: 'DELETE',
      });
    },

    async lookupAuthUser(uid) {
      const res = await request(`${AUTH_BASE}/accounts:lookup`, {
        method: 'POST',
        body: JSON.stringify({ localId: [uid] }),
      });
      return res && res.users && res.users[0] ? res.users[0] : null;
    },

    async disableAndRevokeAuthUser(uid) {
      return request(`${AUTH_BASE}/accounts:update`, {
        method: 'POST',
        body: JSON.stringify({
          localId: uid,
          disableUser: true,
          validSince: String(Math.floor(Date.now() / 1000)),
        }),
      });
    },

    async deleteAuthUser(uid) {
      return request(`${AUTH_BASE}/accounts:delete`, {
        method: 'POST',
        body: JSON.stringify({ localId: uid }),
      });
    },
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Takedown Pipeline
// ─────────────────────────────────────────────────────────────────────────────
async function main() {
  const args = parseArgs(process.argv);
  if (!args.username && !args.uid) {
    console.error('Usage: node tools/admin_delete_user.js --username <username> [--dry-run | --execute]');
    process.exit(1);
  }

  console.log('═══════════════════════════════════════════════════════════════════');
  console.log(` HHF SOCIAL — PROFILE TAKEDOWN (${args.dryRun ? 'DRY RUN - NO WRITES' : 'LIVE EXECUTION'})`);
  console.log('═══════════════════════════════════════════════════════════════════');

  const token = await getAccessToken(args.serviceAccountPath);
  const api = createApiClient(token);

  // ── Step 1: Resolve Target UID & Profile Info ──
  let uid = args.uid;
  let username = args.username;

  if (username) {
    const usernameDoc = await api.getDoc(`usernames/${username}`);
    if (usernameDoc && usernameDoc.data.uid && usernameDoc.data.uid !== 'BANNED_MODERATED') {
      uid = usernameDoc.data.uid;
      console.log(`[1/10] Resolved target handle -> UID: ${uid}`);
    } else {
      const matches = await api.queryWhere('users', 'username', 'EQUAL', username);
      if (matches.length > 0) {
        uid = matches[0].id;
        console.log(`[1/10] Resolved via users query -> UID: ${uid}`);
      }
    }
  }

  if (!uid) {
    console.log(`[1/10] Target user not found in usernames or users collection.`);
    return;
  }

  const userDoc = await api.getDoc(`users/${uid}`);
  if (userDoc) {
    username = (userDoc.data.username || username || '').toLowerCase();
    console.log(`       User Doc Found:`);
    console.log(`         • UID:        ${uid}`);
    console.log(`         • Email:      ${userDoc.data.email}`);
    console.log(`         • Followers:  ${userDoc.data.followersCount ?? 0}`);
    console.log(`         • Following:  ${userDoc.data.followingCount ?? 0}`);
  } else {
    console.log(`       User document users/${uid} already absent (continuing cleanup for orphaned artifacts).`);
  }

  // ── Step 2: Check & Disable Firebase Auth Account (Kill Switch) ──
  let authUser = null;
  try {
    authUser = await api.lookupAuthUser(uid);
  } catch (e) {
    console.log(`[2/10] Auth lookup note: ${e.message}`);
  }

  if (authUser) {
    console.log(`[2/10] Firebase Auth record found: email=${authUser.email}, disabled=${!!authUser.disabled}`);
    if (args.execute) {
      await api.disableAndRevokeAuthUser(uid);
      console.log(`       ✓ Disabled Auth user and revoked refresh tokens immediately.`);
    }
  } else {
    console.log(`[2/10] No active Firebase Auth record found for UID ${uid}.`);
  }

  // ── Step 3: Storage Assets (Posts, Profile Picture, Chat Images) ──
  const postFiles = await api.listStoragePrefix(`posts/${uid}/`);
  const profileFiles = await api.listStoragePrefix(`profile_pictures/${uid}`);
  const chatFiles = await api.listStoragePrefix(`chat_images/${uid}/`);
  const allStorageFiles = [...postFiles, ...profileFiles, ...chatFiles];

  console.log(
    `[3/10] Storage files found: ${allStorageFiles.length} total ` +
      `(posts: ${postFiles.length}, profile_pictures: ${profileFiles.length}, chat_images: ${chatFiles.length})`
  );
  if (args.execute && allStorageFiles.length > 0) {
    let deletedFiles = 0;
    for (const file of allStorageFiles) {
      try {
        await api.deleteStorageObject(file.name);
        deletedFiles++;
      } catch (e) {
        console.warn(`       ! Failed to delete storage object ${file.name}: ${e.message}`);
      }
    }
    console.log(`       ✓ Deleted ${deletedFiles}/${allStorageFiles.length} Storage files.`);
  }

  // ── Step 4: User's Posts + Likes/Comments Subcollections ──
  const userPosts = await api.queryWhere('posts', 'uid', 'EQUAL', uid);
  console.log(`[4/10] User's posts found: ${userPosts.length}`);
  for (const post of userPosts) {
    const likes = await api.listSubcollection(`posts/${post.id}`, 'likes');
    const comments = await api.listSubcollection(`posts/${post.id}`, 'comments');
    console.log(
      `       • Post ${post.id} (${post.data.mediaType || 'image'}): ${likes.length} likes, ${comments.length} comments`
    );
    if (args.execute) {
      for (const l of likes) await api.deleteDoc(l.relPath);
      for (const c of comments) await api.deleteDoc(c.relPath);
      await api.deleteDoc(`posts/${post.id}`);
    }
  }
  if (args.execute && userPosts.length > 0) {
    console.log(`       ✓ Deleted ${userPosts.length} posts and all nested likes/comments.`);
  }

  // ── Step 5: Reconcile Followers (Users following targetUid) ──
  const followers = await api.listSubcollection(`users/${uid}`, 'followers');
  console.log(`[5/10] Followers to reconcile: ${followers.length}`);
  if (args.execute) {
    for (const f of followers) {
      const followerUid = f.id;
      const otherFollowingDoc = await api.getDoc(`users/${followerUid}/following/${uid}`);
      if (otherFollowingDoc) {
        await api.deleteDoc(`users/${followerUid}/following/${uid}`);
        const followerUserDoc = await api.getDoc(`users/${followerUid}`);
        if (followerUserDoc && (followerUserDoc.data.followingCount || 0) > 0) {
          await api.incrementField(`users/${followerUid}`, 'followingCount', -1);
        }
      }
      await api.deleteDoc(f.relPath);
    }
    if (followers.length > 0) {
      console.log(`       ✓ Removed ${uid} from ${followers.length} followers' following lists & decremented followingCount.`);
    }
  }

  // ── Step 6: Reconcile Following (Users followed by targetUid) ──
  const following = await api.listSubcollection(`users/${uid}`, 'following');
  console.log(`[6/10] Following relationships to reconcile: ${following.length}`);
  if (args.execute) {
    for (const f of following) {
      const followedUid = f.id;
      const otherFollowerDoc = await api.getDoc(`users/${followedUid}/followers/${uid}`);
      if (otherFollowerDoc) {
        await api.deleteDoc(`users/${followedUid}/followers/${uid}`);
        const followedUserDoc = await api.getDoc(`users/${followedUid}`);
        if (followedUserDoc && (followedUserDoc.data.followersCount || 0) > 0) {
          await api.incrementField(`users/${followedUid}`, 'followersCount', -1);
        }
      }
      await api.deleteDoc(f.relPath);
    }
    if (following.length > 0) {
      console.log(`       ✓ Removed ${uid} from ${following.length} users' followers lists & decremented followersCount.`);
    }
  }

  // ── Step 7: Clean Up Target User's Likes & Comments on Other Users' Posts ──
  const allPosts = await api.listSubcollection('', 'posts'.replace(/^\//, ''));
  const otherPosts = allPosts.filter((p) => p.data.uid !== uid);
  let externalLikesRemoved = 0;
  let externalCommentsRemoved = 0;

  for (const post of otherPosts) {
    // Check if targetUid liked this post (O(1) doc lookup)
    const likeDoc = await api.getDoc(`posts/${post.id}/likes/${uid}`);
    if (likeDoc) {
      externalLikesRemoved++;
      if (args.execute) {
        await api.deleteDoc(`posts/${post.id}/likes/${uid}`);
        if ((post.data.likesCount || 0) > 0) {
          await api.incrementField(`posts/${post.id}`, 'likesCount', -1);
        }
      }
    }

    // Check comments on this post if it has comments
    if ((post.data.commentsCount || 0) > 0) {
      const comments = await api.listSubcollection(`posts/${post.id}`, 'comments');
      const userComments = comments.filter((c) => c.data.uid === uid);
      if (userComments.length > 0) {
        externalCommentsRemoved += userComments.length;
        if (args.execute) {
          for (const c of userComments) {
            await api.deleteDoc(c.relPath);
          }
          const dec = Math.min(post.data.commentsCount || 0, userComments.length);
          if (dec > 0) {
            await api.incrementField(`posts/${post.id}`, 'commentsCount', -dec);
          }
        }
      }
    }
  }
  console.log(
    `[7/10] External interactions across ${otherPosts.length} other posts: ` +
      `${externalLikesRemoved} likes, ${externalCommentsRemoved} comments`
  );

  // ── Step 8: Chats, Messages & Unread Counter Reconciliation ──
  const chats = await api.queryWhere('chats', 'participants', 'ARRAY_CONTAINS', uid);
  console.log(`[8/10] Chats involving user: ${chats.length}`);
  for (const chat of chats) {
    const msgs = await api.listSubcollection(`chats/${chat.id}`, 'messages');
    const participants = Array.isArray(chat.data.participants) ? chat.data.participants : [];
    const otherUid = participants.find((p) => p !== uid);
    const unreadForOther =
      chat.data.unreadCount && otherUid ? Number(chat.data.unreadCount[otherUid] || 0) : 0;

    console.log(
      `       • Chat ${chat.id} (with ${otherUid || 'unknown'}): ${msgs.length} messages, unreadForOther=${unreadForOther}`
    );

    if (args.execute) {
      if (otherUid && unreadForOther > 0) {
        const otherUserDoc = await api.getDoc(`users/${otherUid}`);
        const currentTotalUnread = Number((otherUserDoc && otherUserDoc.data.unreadMessages) || 0);
        const decrementBy = Math.min(currentTotalUnread, unreadForOther);
        if (decrementBy > 0) {
          await api.incrementField(`users/${otherUid}`, 'unreadMessages', -decrementBy);
        }
      }
      for (const m of msgs) {
        await api.deleteDoc(m.relPath);
      }
      await api.deleteDoc(`chats/${chat.id}`);
    }
  }

  // ── Step 9: Notifications (Both Received and Sent) & Reports Resolution ──
  const receivedNotifs = await api.queryWhere('notifications', 'recipientUid', 'EQUAL', uid);
  const sentNotifs = await api.queryWhere('notifications', 'senderUid', 'EQUAL', uid);
  const notifMap = new Map();
  for (const n of [...receivedNotifs, ...sentNotifs]) notifMap.set(n.id, n);

  console.log(
    `[9/10] Notifications to purge: ${notifMap.size} ` +
      `(received: ${receivedNotifs.length}, sent: ${sentNotifs.length})`
  );
  if (args.execute) {
    for (const n of notifMap.values()) {
      await api.deleteDoc(n.relPath);
    }
  }

  const reports = await api.queryWhere('reports', 'reportedUid', 'EQUAL', uid);
  console.log(`       Reports against user: ${reports.length}`);
  if (args.execute && reports.length > 0) {
    for (const r of reports) {
      await api.patchFields(r.relPath, {
        status: 'resolved',
        resolution: 'account_deleted_prohibited_content',
        resolvedAt: new Date(),
      });
    }
    console.log(`       ✓ Marked ${reports.length} reports as resolved.`);
  }

  // ── Step 10: User Subcollections, User Doc, Username Tombstone & Auth Delete ──
  const blockedUsers = await api.listSubcollection(`users/${uid}`, 'blockedUsers');
  const hiddenPosts = await api.listSubcollection(`users/${uid}`, 'hiddenPosts');
  console.log(
    `[10/10] Finalizing user doc & auth deletion ` +
      `(blockedUsers: ${blockedUsers.length}, hiddenPosts: ${hiddenPosts.length}, blockUsername: ${args.blockUsername})`
  );

  if (args.execute) {
    for (const b of blockedUsers) await api.deleteDoc(b.relPath);
    for (const h of hiddenPosts) await api.deleteDoc(h.relPath);

    if (userDoc) {
      await api.deleteDoc(`users/${uid}`);
      console.log(`       ✓ Deleted Firestore document users/${uid}`);
    }

    if (username) {
      if (args.blockUsername) {
        await api.setDoc(`usernames/${username}`, {
          uid: 'BANNED_MODERATED',
          banned: true,
          previousUid: uid,
          moderatedAt: new Date(),
          reason: 'Prohibited content takedown',
        });
        console.log(`       ✓ Tombstoned username reservation (handle permanently blocked from re-registration)`);
      } else {
        await api.deleteDoc(`usernames/${username}`);
        console.log(`       ✓ Deleted username reservation`);
      }
    }

    if (authUser) {
      await api.deleteAuthUser(uid);
      console.log(`       ✓ Permanently deleted Firebase Auth user (${uid})`);
    }
  }

  console.log('═══════════════════════════════════════════════════════════════════');
  if (args.dryRun) {
    console.log(' DRY RUN COMPLETE. Re-run with --execute to perform the takedown.');
  } else {
    console.log(` TAKEDOWN COMPLETE FOR UID (${uid}).`);
  }
  console.log('═══════════════════════════════════════════════════════════════════');
}

main().catch((err) => {
  console.error('\n❌ Fatal error:', err.message || err);
  process.exit(1);
});
