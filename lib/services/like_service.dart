import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger_service.dart';
import 'notification_service.dart';
import 'database_service.dart';

class LikeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Like a post (atomic batch write)
  Future<void> likePost(String uid, String postId) async {
    try {
      final batch = _firestore.batch();

      // 1. Add like doc to post's likes subcollection
      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(uid);
      batch.set(likeRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Increment likesCount on the post document
      final postRef = _firestore.collection('posts').doc(postId);
      batch.update(postRef, {
        'likesCount': FieldValue.increment(1),
      });

      await batch.commit();

      // Fire-and-forget: send like notification
      _sendLikeNotification(uid, postId);
    } catch (e, stackTrace) {
      LoggerService.logError('Error liking post', e, stackTrace);
      rethrow;
    }
  }

  /// Unlike a post (atomic batch write)
  Future<void> unlikePost(String uid, String postId) async {
    try {
      final batch = _firestore.batch();

      // 1. Remove like doc
      final likeRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(uid);
      batch.delete(likeRef);

      // 2. Decrement likesCount on the post document
      final postRef = _firestore.collection('posts').doc(postId);
      batch.update(postRef, {
        'likesCount': FieldValue.increment(-1),
      });

      await batch.commit();
    } catch (e, stackTrace) {
      LoggerService.logError('Error unliking post', e, stackTrace);
      rethrow;
    }
  }

  /// Check if user has liked a post (O(1) lookup)
  Future<bool> hasLiked(String uid, String postId) async {
    try {
      final doc = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('likes')
          .doc(uid)
          .get();
      return doc.exists;
    } catch (e, stackTrace) {
      LoggerService.logError('Error checking like status', e, stackTrace);
      return false;
    }
  }

  /// Batch check likes for multiple posts (for feed)
  Future<Map<String, bool>> batchCheckLikes(String uid, List<String> postIds) async {
    final Map<String, bool> result = {};
    try {
      // Check each post's like status in parallel
      final futures = postIds.map((postId) async {
        final liked = await hasLiked(uid, postId);
        result[postId] = liked;
      });
      await Future.wait(futures);
    } catch (e, stackTrace) {
      LoggerService.logError('Error batch checking likes', e, stackTrace);
    }
    return result;
  }

  /// Helper: send a like notification
  void _sendLikeNotification(String senderUid, String postId) async {
    try {
      // Get post to find owner and image
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) return;
      final postData = postDoc.data()!;
      final postOwnerUid = postData['uid'] as String;

      // Get sender info
      final sender = await DatabaseService().getUser(senderUid);
      if (sender == null) return;

      await NotificationService().createNotification(
        recipientUid: postOwnerUid,
        senderUid: senderUid,
        senderUsername: sender.username,
        senderProfilePic: sender.profilePictureUrl,
        type: 'like',
        postId: postId,
        postImageUrl: postData['imageUrl'] as String?,
      );
    } catch (_) {}
  }
}
