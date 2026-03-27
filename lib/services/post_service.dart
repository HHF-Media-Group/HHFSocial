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
}
