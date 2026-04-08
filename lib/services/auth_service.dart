import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/logger_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Auth State Stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign In
  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result;
    } catch (e, stackTrace) {
      LoggerService.logError('Error signing in', e, stackTrace);
      rethrow;
    }
  }

  // Sign Up
  Future<UserCredential?> signUpWithEmailAndPassword(
      String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return result;
    } catch (e, stackTrace) {
      LoggerService.logError('Error signing up', e, stackTrace);
      rethrow;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, stackTrace) {
      LoggerService.logError('Error signing out', e, stackTrace);
    }
  }
  
  // Send Email Verification
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No user is currently signed in.',
      );
    }
    try {
      await user.sendEmailVerification();
    } catch (e, stackTrace) {
      LoggerService.logError('Error sending email verification', e, stackTrace);
      rethrow;
    }
  }

  // Send Password Reset Email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e, stackTrace) {
      LoggerService.logError('Error sending password reset email', e, stackTrace);
      rethrow;
    }
  }

  // Reload User
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e, stackTrace) {
      LoggerService.logError('Error reloading user', e, stackTrace);
      rethrow;
    }
  }

  // Delete User (Rollback)
  Future<void> deleteUser() async {
    try {
      await _auth.currentUser?.delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting user', e, stackTrace);
      // Don't rethrow here, we want to try our best to clean up but not crash the error handling flow
    }
  }

  // Re-authenticate user (required before destructive operations)
  Future<void> reauthenticate(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    final credential = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  // Delete account permanently: wipes Firestore data + Storage files + Firebase Auth
  // Each step is wrapped in try/catch so one failure doesn't block the rest
  Future<void> deleteAccountPermanently() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    final uid = user.uid;

    String? username;

    // 0. Get username before deleting user doc
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      username = userDoc.data()?['username'] as String?;
    } catch (e, st) {
      LoggerService.logError('Delete: failed to get username', e, st);
    }

    // 1. Delete user's posts, subcollections, AND storage images
    try {
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .get();
      LoggerService.logInfo('Delete: found ${postsSnapshot.docs.length} posts to delete');
      for (final doc in postsSnapshot.docs) {
        try {
          final comments = await doc.reference.collection('comments').get();
          for (final c in comments.docs) { await c.reference.delete(); }
          final likes = await doc.reference.collection('likes').get();
          for (final l in likes.docs) { await l.reference.delete(); }
          await doc.reference.delete();
        } catch (e, st) {
          LoggerService.logError('Delete: failed to delete post ${doc.id}', e, st);
        }
      }
    } catch (e, st) {
      LoggerService.logError('Delete: failed to query posts', e, st);
    }

    // 2. Delete post images from Storage
    try {
      final storageRef = _storage.ref().child('posts/$uid');
      final listResult = await storageRef.listAll();
      LoggerService.logInfo('Delete: found ${listResult.items.length} post storage files');
      for (final item in listResult.items) {
        try { await item.delete(); } catch (_) {}
      }
    } catch (e, st) {
      LoggerService.logError('Delete: failed to delete post storage', e, st);
    }

    // 3. Delete profile picture from Storage
    try {
      final profileRef = _storage.ref().child('profile_pictures/$uid.jpg');
      await profileRef.delete();
    } catch (e) {
      LoggerService.logInfo('Delete: profile pic cleanup: $e');
    }

    // 4. Delete chat images from Storage
    try {
      final chatImgRef = _storage.ref().child('chat_images/$uid');
      final chatImgList = await chatImgRef.listAll();
      LoggerService.logInfo('Delete: found ${chatImgList.items.length} chat image files');
      for (final item in chatImgList.items) {
        try { await item.delete(); } catch (_) {}
      }
    } catch (e, st) {
      LoggerService.logError('Delete: failed to delete chat images', e, st);
    }

    // 5. Delete user's chats and messages
    try {
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();
      LoggerService.logInfo('Delete: found ${chatsSnapshot.docs.length} chats to delete');
      for (final doc in chatsSnapshot.docs) {
        try {
          final msgs = await doc.reference.collection('messages').get();
          for (final m in msgs.docs) { await m.reference.delete(); }
          await doc.reference.delete();
        } catch (e, st) {
          LoggerService.logError('Delete: failed to delete chat ${doc.id}', e, st);
        }
      }
    } catch (e, st) {
      LoggerService.logError('Delete: failed to query chats', e, st);
    }

    // 6. Delete notifications
    try {
      final notifs = await _firestore
          .collection('notifications')
          .where('recipientUid', isEqualTo: uid)
          .get();
      LoggerService.logInfo('Delete: found ${notifs.docs.length} notifications to delete');
      for (final doc in notifs.docs) { await doc.reference.delete(); }
    } catch (e, st) {
      LoggerService.logError('Delete: failed to delete notifications', e, st);
    }

    // 7. Delete follow relationships
    try {
      final followers = await _firestore
          .collection('users').doc(uid).collection('followers').get();
      for (final doc in followers.docs) { await doc.reference.delete(); }
    } catch (e, st) {
      LoggerService.logError('Delete: failed to delete followers', e, st);
    }

    try {
      final following = await _firestore
          .collection('users').doc(uid).collection('following').get();
      for (final doc in following.docs) { await doc.reference.delete(); }
    } catch (e, st) {
      LoggerService.logError('Delete: failed to delete following', e, st);
    }

    // 8. Delete blocked users
    try {
      final blocked = await _firestore
          .collection('users').doc(uid).collection('blockedUsers').get();
      for (final doc in blocked.docs) { await doc.reference.delete(); }
    } catch (e, st) {
      LoggerService.logError('Delete: failed to delete blocked users', e, st);
    }

    // 9. Delete username reservation
    try {
      if (username != null && username.isNotEmpty) {
        await _firestore.collection('usernames').doc(username.toLowerCase()).delete();
      }
    } catch (e, st) {
      LoggerService.logError('Delete: failed to delete username', e, st);
    }

    // 10. Delete user document
    try {
      await _firestore.collection('users').doc(uid).delete();
    } catch (e, st) {
      LoggerService.logError('Delete: failed to delete user doc', e, st);
    }

    // 11. Delete Firebase Auth account (must be last — triggers auth state change)
    LoggerService.logInfo('Delete: deleting Firebase Auth account');
    await user.delete();
  }

  // Get Current User
  User? get currentUser => _auth.currentUser;
}
