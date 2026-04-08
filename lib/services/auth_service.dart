import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  // Delete account permanently: wipes Firestore data + Storage + Firebase Auth
  Future<void> deleteAccountPermanently() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No user signed in');
    final uid = user.uid;

    try {
      // 0. Get username before deleting user doc (needed to delete username reservation)
      final userDoc = await _firestore.collection('users').doc(uid).get();
      final username = userDoc.data()?['username'] as String?;

      // 1. Delete user's posts and their subcollections
      final postsSnapshot = await _firestore
          .collection('posts')
          .where('uid', isEqualTo: uid)
          .get();
      for (final doc in postsSnapshot.docs) {
        final commentsSnapshot = await doc.reference.collection('comments').get();
        for (final comment in commentsSnapshot.docs) {
          await comment.reference.delete();
        }
        final likesSnapshot = await doc.reference.collection('likes').get();
        for (final like in likesSnapshot.docs) {
          await like.reference.delete();
        }
        await doc.reference.delete();
      }

      // 2. Delete user's chats and messages
      final chatsSnapshot = await _firestore
          .collection('chats')
          .where('participants', arrayContains: uid)
          .get();
      for (final doc in chatsSnapshot.docs) {
        final messagesSnapshot = await doc.reference.collection('messages').get();
        for (final msg in messagesSnapshot.docs) {
          await msg.reference.delete();
        }
        await doc.reference.delete();
      }

      // 3. Delete notifications (sent TO this user)
      final notifsSnapshot = await _firestore
          .collection('notifications')
          .where('recipientUid', isEqualTo: uid)
          .get();
      for (final doc in notifsSnapshot.docs) {
        await doc.reference.delete();
      }

      // 4. Delete follow relationships (subcollections under users/{uid})
      final followersSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();
      for (final doc in followersSnapshot.docs) {
        await doc.reference.delete();
      }

      final followingSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      for (final doc in followingSnapshot.docs) {
        await doc.reference.delete();
      }

      // 5. Delete blocked users subcollection
      final blockedSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('blockedUsers')
          .get();
      for (final doc in blockedSnapshot.docs) {
        await doc.reference.delete();
      }

      // 6. Delete username reservation
      if (username != null && username.isNotEmpty) {
        await _firestore.collection('usernames').doc(username.toLowerCase()).delete();
      }

      // 7. Delete user document
      await _firestore.collection('users').doc(uid).delete();

      // 8. Delete Firebase Auth account (must be last — loses permissions after this)
      await user.delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting account permanently', e, stackTrace);
      rethrow;
    }
  }

  // Get Current User
  User? get currentUser => _auth.currentUser;
}
