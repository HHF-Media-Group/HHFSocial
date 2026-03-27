import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger_service.dart';
import 'notification_service.dart';
import 'database_service.dart';

class FollowService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Follow a user using a batch write for atomicity
  Future<void> followUser(String currentUid, String targetUid) async {
    if (currentUid == targetUid) return; // Can't follow yourself

    try {
      final batch = _firestore.batch();

      // 1. Add target to current user's "following" subcollection
      final followingRef = _firestore
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(targetUid);
      batch.set(followingRef, {
        'uid': targetUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Add current user to target's "followers" subcollection
      final followerRef = _firestore
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(currentUid);
      batch.set(followerRef, {
        'uid': currentUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Increment current user's followingCount
      final currentUserRef = _firestore.collection('users').doc(currentUid);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(1),
      });

      // 4. Increment target user's followersCount
      final targetUserRef = _firestore.collection('users').doc(targetUid);
      batch.update(targetUserRef, {
        'followersCount': FieldValue.increment(1),
      });

      await batch.commit();

      // Fire-and-forget: send follow notification
      _sendFollowNotification(currentUid, targetUid);
    } catch (e, stackTrace) {
      LoggerService.logError('Error following user', e, stackTrace);
      rethrow;
    }
  }

  /// Unfollow a user using a batch write for atomicity
  Future<void> unfollowUser(String currentUid, String targetUid) async {
    if (currentUid == targetUid) return;

    try {
      final batch = _firestore.batch();

      // 1. Remove target from current user's "following"
      final followingRef = _firestore
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(targetUid);
      batch.delete(followingRef);

      // 2. Remove current user from target's "followers"
      final followerRef = _firestore
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(currentUid);
      batch.delete(followerRef);

      // 3. Decrement current user's followingCount
      final currentUserRef = _firestore.collection('users').doc(currentUid);
      batch.update(currentUserRef, {
        'followingCount': FieldValue.increment(-1),
      });

      // 4. Decrement target user's followersCount
      final targetUserRef = _firestore.collection('users').doc(targetUid);
      batch.update(targetUserRef, {
        'followersCount': FieldValue.increment(-1),
      });

      await batch.commit();
    } catch (e, stackTrace) {
      LoggerService.logError('Error unfollowing user', e, stackTrace);
      rethrow;
    }
  }

  /// Check if current user is following target user (O(1) lookup)
  Future<bool> isFollowing(String currentUid, String targetUid) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(targetUid)
          .get();
      return doc.exists;
    } catch (e, stackTrace) {
      LoggerService.logError('Error checking follow status', e, stackTrace);
      return false;
    }
  }

  /// Get list of follower UIDs
  Future<List<String>> getFollowers(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting followers', e, stackTrace);
      return [];
    }
  }

  /// Get list of following UIDs
  Future<List<String>> getFollowing(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting following', e, stackTrace);
      return [];
    }
  }

  /// Helper: send a follow notification
  void _sendFollowNotification(String senderUid, String recipientUid) async {
    try {
      final sender = await DatabaseService().getUser(senderUid);
      if (sender == null) return;

      await NotificationService().createNotification(
        recipientUid: recipientUid,
        senderUid: senderUid,
        senderUsername: sender.username,
        senderProfilePic: sender.profilePictureUrl,
        type: 'follow',
      );
    } catch (_) {}
  }
}
