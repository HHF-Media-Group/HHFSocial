import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../utils/logger_service.dart';

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Create a notification
  Future<void> createNotification({
    required String recipientUid,
    required String senderUid,
    required String senderUsername,
    String? senderProfilePic,
    required String type,
    String? postId,
    String? postImageUrl,
    String? commentText,
  }) async {
    // Don't notify yourself
    if (recipientUid == senderUid) return;

    try {
      final docRef = _firestore.collection('notifications').doc();
      final notification = NotificationModel(
        notificationId: docRef.id,
        recipientUid: recipientUid,
        senderUid: senderUid,
        senderUsername: senderUsername,
        senderProfilePic: senderProfilePic,
        type: type,
        postId: postId,
        postImageUrl: postImageUrl,
        commentText: commentText,
        createdAt: DateTime.now(),
      );
      await docRef.set(notification.toMap());
    } catch (e, stackTrace) {
      LoggerService.logError('Error creating notification', e, stackTrace);
      // Don't rethrow — notifications are fire-and-forget
    }
  }

  /// Get notifications for a user (newest first)
  Future<List<NotificationModel>> getNotifications(String uid, {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('recipientUid', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => NotificationModel.fromMap(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting notifications', e, stackTrace);
      return [];
    }
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
    } catch (e, stackTrace) {
      LoggerService.logError('Error marking notification read', e, stackTrace);
    }
  }

  /// Mark all notifications as read for a user
  Future<void> markAllAsRead(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('recipientUid', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e, stackTrace) {
      LoggerService.logError('Error marking all read', e, stackTrace);
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('notifications')
          .where('recipientUid', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();
      return snapshot.size;
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting unread count', e, stackTrace);
      return 0;
    }
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection('notifications').doc(notificationId).delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting notification', e, stackTrace);
    }
  }
}
