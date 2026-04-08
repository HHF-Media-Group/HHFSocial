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
