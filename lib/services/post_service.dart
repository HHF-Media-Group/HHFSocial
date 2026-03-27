import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../utils/logger_service.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new post
  Future<PostModel> createPost({
    required String uid,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final docRef = _firestore.collection('posts').doc();
      final post = PostModel(
        postId: docRef.id,
        uid: uid,
        imageUrl: imageUrl,
        caption: caption,
        createdAt: DateTime.now(),
        likesCount: 0,
      );

      await docRef.set(post.toMap());

      // Increment post count on user doc
      await _firestore.collection('users').doc(uid).update({
        'postsCount': FieldValue.increment(1),
      });

      return post;
    } catch (e, stackTrace) {
      LoggerService.logError('Error creating post', e, stackTrace);
      rethrow;
    }
  }

  // Generate a Firestore document ID (for coordinating Storage + Firestore)
  String generatePostId() {
    return _firestore.collection('posts').doc().id;
  }

  // Create a post with a specific postId (used when Storage upload happens first)
  Future<PostModel> createPostWithId({
    required String postId,
    required String uid,
    required String imageUrl,
    String? caption,
  }) async {
    try {
      final docRef = _firestore.collection('posts').doc(postId);
      final post = PostModel(
        postId: postId,
        uid: uid,
        imageUrl: imageUrl,
        caption: caption,
        createdAt: DateTime.now(),
        likesCount: 0,
      );

      await docRef.set(post.toMap());

      // Increment post count on user doc
      await _firestore.collection('users').doc(uid).update({
        'postsCount': FieldValue.increment(1),
      });

      return post;
    } catch (e, stackTrace) {
      LoggerService.logError('Error creating post with ID', e, stackTrace);
      rethrow;
    }
  }

  // Get user's posts (paginated, newest first)
  Future<List<PostModel>> getUserPosts(String uid, {int limit = 18, DocumentSnapshot? lastDoc}) async {
    try {
      Query query = _firestore
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting user posts', e, stackTrace);
      return [];
    }
  }

  // Get a single post
  Future<PostModel?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists) {
        return PostModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting post', e, stackTrace);
      return null;
    }
  }

  // Delete a post
  Future<void> deletePost(String postId, String uid) async {
    try {
      final postRef = _firestore.collection('posts').doc(postId);

      // 1. Delete all likes subcollection docs
      final likesSnapshot = await postRef.collection('likes').get();
      for (final doc in likesSnapshot.docs) {
        await doc.reference.delete();
      }

      // 2. Delete all comments subcollection docs
      final commentsSnapshot = await postRef.collection('comments').get();
      for (final doc in commentsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 3. Delete the post document
      await postRef.delete();

      // 4. Decrement post count on user doc
      await _firestore.collection('users').doc(uid).update({
        'postsCount': FieldValue.increment(-1),
      });

      // 5. Delete all notifications referencing this post (best-effort)
      try {
        final notifSnapshot = await _firestore
            .collection('notifications')
            .where('recipientUid', isEqualTo: uid)
            .where('postId', isEqualTo: postId)
            .get();
        for (final doc in notifSnapshot.docs) {
          await doc.reference.delete();
        }
      } catch (_) {
        // Non-critical — don't block post deletion
      }
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting post', e, stackTrace);
      rethrow;
    }
  }

  // Get feed posts from a list of followed user UIDs
  Future<List<PostModel>> getFeedPosts(List<String> followingUids, {int limit = 50}) async {
    if (followingUids.isEmpty) return [];

    try {
      final List<PostModel> allPosts = [];

      // Firestore whereIn supports max 10 items — batch the queries
      for (var i = 0; i < followingUids.length; i += 10) {
        final batch = followingUids.sublist(
          i,
          i + 10 > followingUids.length ? followingUids.length : i + 10,
        );

        final snapshot = await _firestore
            .collection('posts')
            .where('uid', whereIn: batch)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();

        allPosts.addAll(
          snapshot.docs.map((doc) => PostModel.fromMap(doc.data())),
        );
      }

      // Sort all results by createdAt descending and take top N
      allPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (allPosts.length > limit) {
        return allPosts.sublist(0, limit);
      }
      return allPosts;
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting feed posts', e, stackTrace);
      return [];
    }
  }

  /// Discovery feed: followed posts first (priority), then shuffled posts
  /// from non-followed users. Excludes the current user's own posts.
  Future<List<PostModel>> getDiscoveryFeed({
    required String currentUid,
    required List<String> followingUids,
    int followedLimit = 30,
    int discoveryLimit = 20,
  }) async {
    try {
      // 1. Get followed users' posts (priority)
      final followedPosts = followingUids.isNotEmpty
          ? await getFeedPosts(followingUids, limit: followedLimit)
          : <PostModel>[];

      final followedPostIds = followedPosts.map((p) => p.postId).toSet();

      // 2. Get recent posts from ALL users (discovery pool)
      final discoverySnapshot = await _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(followedLimit + discoveryLimit + 10) // fetch extra to filter
          .get();

      final discoveryPosts = discoverySnapshot.docs
          .map((doc) => PostModel.fromMap(doc.data()))
          .where((p) =>
              p.uid != currentUid &&          // exclude own posts
              !followedPostIds.contains(p.postId)) // exclude already shown
          .toList();

      // 3. Shuffle discovery posts for variety
      discoveryPosts.shuffle();

      // 4. Take only what we need
      final trimmedDiscovery = discoveryPosts.length > discoveryLimit
          ? discoveryPosts.sublist(0, discoveryLimit)
          : discoveryPosts;

      // 5. Combine: followed first, then discovery
      return [...followedPosts, ...trimmedDiscovery];
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting discovery feed', e, stackTrace);
      return [];
    }
  }

  /// Paginated global posts query for infinite scroll.
  /// Returns (posts, lastDocSnapshot) for cursor-based pagination.
  Future<({List<PostModel> posts, DocumentSnapshot? lastDoc})> getPaginatedPosts({
    required String currentUid,
    DocumentSnapshot? startAfter,
    int pageSize = 15,
  }) async {
    try {
      Query query = _firestore
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      final posts = snapshot.docs
          .map((doc) => PostModel.fromMap(doc.data() as Map<String, dynamic>))
          .where((p) => p.uid != currentUid) // exclude own posts
          .toList();

      final lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return (posts: posts, lastDoc: lastDoc);
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting paginated posts', e, stackTrace);
      return (posts: <PostModel>[], lastDoc: null);
    }
  }
}
