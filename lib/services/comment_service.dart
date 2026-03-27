import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/comment_model.dart';
import '../utils/logger_service.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Add a comment to a post (atomic batch write)
  Future<CommentModel> addComment({
    required String postId,
    required String uid,
    required String username,
    String? profilePictureUrl,
    required String text,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Create comment doc
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc();

      final comment = CommentModel(
        commentId: commentRef.id,
        postId: postId,
        uid: uid,
        username: username,
        profilePictureUrl: profilePictureUrl,
        text: text,
        createdAt: DateTime.now(),
      );

      batch.set(commentRef, comment.toMap());

      // 2. Increment commentsCount on the post document
      final postRef = _firestore.collection('posts').doc(postId);
      batch.update(postRef, {
        'commentsCount': FieldValue.increment(1),
      });

      await batch.commit();
      return comment;
    } catch (e, stackTrace) {
      LoggerService.logError('Error adding comment', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a comment (atomic batch write)
  Future<void> deleteComment(String postId, String commentId) async {
    try {
      final batch = _firestore.batch();

      // 1. Delete comment doc
      final commentRef = _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .doc(commentId);
      batch.delete(commentRef);

      // 2. Decrement commentsCount
      final postRef = _firestore.collection('posts').doc(postId);
      batch.update(postRef, {
        'commentsCount': FieldValue.increment(-1),
      });

      await batch.commit();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting comment', e, stackTrace);
      rethrow;
    }
  }

  /// Get all comments for a post (oldest first)
  Future<List<CommentModel>> getComments(String postId) async {
    try {
      final snapshot = await _firestore
          .collection('posts')
          .doc(postId)
          .collection('comments')
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => CommentModel.fromMap(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting comments', e, stackTrace);
      return [];
    }
  }
}
