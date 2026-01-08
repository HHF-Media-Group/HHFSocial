import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/logger_service.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if username is already taken using the usernames collection
  Future<bool> isUsernameTaken(String username) async {
    try {
      final doc = await _firestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();
      return doc.exists;
    } catch (e, stackTrace) {
      LoggerService.logError('Error checking username uniqueness', e, stackTrace);
      rethrow;
    }
  }

  // Reserve a username (creates doc in usernames collection)
  Future<void> reserveUsername(String username, String uid) async {
    try {
      await _firestore.collection('usernames').doc(username.toLowerCase()).set({
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      LoggerService.logError('Error reserving username', e, stackTrace);
      rethrow;
    }
  }

  // Release a username (for rollback if user creation fails)
  Future<void> releaseUsername(String username) async {
    try {
      await _firestore.collection('usernames').doc(username.toLowerCase()).delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error releasing username', e, stackTrace);
      // Don't rethrow - this is cleanup
    }
  }

  Future<void> saveUser(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(user.toMap());
    } catch (e, stackTrace) {
      LoggerService.logError('Error saving user to Firestore', e, stackTrace);
      rethrow;
    }
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting user from Firestore', e, stackTrace);
      return null;
    }
  }

  // Update Profile Picture URL
  Future<void> updateProfilePicture(String uid, String url) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'profilePictureUrl': url,
      });
    } catch (e, stackTrace) {
      LoggerService.logError('Error updating profile picture', e, stackTrace);
      rethrow;
    }
  }

  // Remove Profile Picture URL
  Future<void> removeProfilePicture(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'profilePictureUrl': null,
      });
    } catch (e, stackTrace) {
      LoggerService.logError('Error removing profile picture', e, stackTrace);
      rethrow;
    }
  }
}

