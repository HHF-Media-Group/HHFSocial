import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger_service.dart';

class BlockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Block a user
  Future<void> blockUser(String currentUid, String blockedUid) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blockedUsers')
          .doc(blockedUid)
          .set({
        'blockedUid': blockedUid,
        'blockedAt': Timestamp.now(),
      });

      // Also file a report so the developer is notified of the block
      // (App Store Guideline 1.2). Best-effort — never fail the block itself.
      try {
        await _firestore.collection('reports').add({
          'reporterUid': currentUid,
          'reportedUid': blockedUid,
          'reason': 'User blocked',
          'type': 'block',
          'createdAt': Timestamp.now(),
        });
      } catch (e, stackTrace) {
        LoggerService.logError('Error filing block report', e, stackTrace);
      }
    } catch (e, stackTrace) {
      LoggerService.logError('Error blocking user', e, stackTrace);
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String currentUid, String blockedUid) async {
    try {
      await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blockedUsers')
          .doc(blockedUid)
          .delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error unblocking user', e, stackTrace);
      rethrow;
    }
  }

  /// Check if currentUid has blocked otherUid
  Future<bool> isBlocked(String currentUid, String otherUid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('blockedUsers')
          .doc(otherUid)
          .get();
      return doc.exists;
    } catch (e, stackTrace) {
      LoggerService.logError('Error checking block status', e, stackTrace);
      return false;
    }
  }

  /// Check if otherUid has blocked currentUid
  Future<bool> isBlockedBy(String currentUid, String otherUid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(otherUid)
          .collection('blockedUsers')
          .doc(currentUid)
          .get();
      return doc.exists;
    } catch (e, stackTrace) {
      LoggerService.logError('Error checking blocked-by status', e, stackTrace);
      return false;
    }
  }

  /// Get list of blocked user UIDs
  Future<List<String>> getBlockedUsers(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('blockedUsers')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting blocked users', e, stackTrace);
      return [];
    }
  }

  /// Report a user
  Future<void> reportUser({
    required String reporterUid,
    required String reportedUid,
    required String reason,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterUid': reporterUid,
        'reportedUid': reportedUid,
        'reason': reason,
        'type': 'user',
        'createdAt': Timestamp.now(),
      });
    } catch (e, stackTrace) {
      LoggerService.logError('Error reporting user', e, stackTrace);
      rethrow;
    }
  }

  /// Report a post
  Future<void> reportPost({
    required String reporterUid,
    required String reportedUid,
    required String postId,
    required String reason,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterUid': reporterUid,
        'reportedUid': reportedUid,
        'postId': postId,
        'reason': reason,
        'type': 'post',
        'createdAt': Timestamp.now(),
      });
    } catch (e, stackTrace) {
      LoggerService.logError('Error reporting post', e, stackTrace);
      rethrow;
    }
  }

  /// Report a comment
  Future<void> reportComment({
    required String reporterUid,
    required String reportedUid,
    required String postId,
    required String commentId,
    required String reason,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterUid': reporterUid,
        'reportedUid': reportedUid,
        'postId': postId,
        'commentId': commentId,
        'reason': reason,
        'type': 'comment',
        'createdAt': Timestamp.now(),
      });
    } catch (e, stackTrace) {
      LoggerService.logError('Error reporting comment', e, stackTrace);
      rethrow;
    }
  }

  /// Hide a post for the current user (persisted, used after reporting)
  Future<void> hidePost(String uid, String postId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('hiddenPosts')
          .doc(postId)
          .set({
        'postId': postId,
        'hiddenAt': Timestamp.now(),
      });
    } catch (e, stackTrace) {
      LoggerService.logError('Error hiding post', e, stackTrace);
      // Non-critical — the post is already removed locally
    }
  }

  /// Get IDs of posts the user has hidden (reported)
  Future<Set<String>> getHiddenPostIds(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('hiddenPosts')
          .get();
      return snapshot.docs.map((doc) => doc.id).toSet();
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting hidden posts', e, stackTrace);
      return {};
    }
  }

  /// Report a message
  Future<void> reportMessage({
    required String reporterUid,
    required String reportedUid,
    required String chatId,
    required String messageId,
    required String reason,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'reporterUid': reporterUid,
        'reportedUid': reportedUid,
        'chatId': chatId,
        'messageId': messageId,
        'reason': reason,
        'type': 'message',
        'createdAt': Timestamp.now(),
      });
    } catch (e, stackTrace) {
      LoggerService.logError('Error reporting message', e, stackTrace);
      rethrow;
    }
  }
}
