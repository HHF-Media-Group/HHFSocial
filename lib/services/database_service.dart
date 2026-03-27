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

  // Update user profile fields (partial update)
  Future<void> updateUserProfile(String uid, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection('users').doc(uid).update(updates);
    } catch (e, stackTrace) {
      LoggerService.logError('Error updating user profile', e, stackTrace);
      rethrow;
    }
  }

  // Change username with atomic swap (delete old → create new)
  // Returns true on success, throws on failure with rollback
  Future<void> changeUsername(String uid, String oldUsername, String newUsername) async {
    final oldLower = oldUsername.toLowerCase();
    final newLower = newUsername.toLowerCase();

    // If username hasn't actually changed, skip
    if (oldLower == newLower) return;

    // 1. Check if new username is available
    final isTaken = await isUsernameTaken(newLower);
    if (isTaken) {
      throw Exception('Username is already taken');
    }

    // 2. Reserve new username
    try {
      await reserveUsername(newLower, uid);
    } catch (e) {
      throw Exception('Failed to reserve new username');
    }

    // 3. Update users document
    try {
      await _firestore.collection('users').doc(uid).update({
        'username': newLower,
      });
    } catch (e) {
      // Rollback: release the new username
      await releaseUsername(newLower);
      throw Exception('Failed to update profile with new username');
    }

    // 4. Release old username (cleanup, don't fail if this errors)
    await releaseUsername(oldLower);
  }

  // Search users by username prefix (case-insensitive via lowercase storage)
  Future<List<UserModel>> searchUsers(String query, {String? excludeUid, int limit = 20}) async {
    if (query.trim().isEmpty) return [];

    final searchTerm = query.toLowerCase().trim();
    // Firestore range query: >= searchTerm and < searchTerm + high Unicode char
    final endTerm = '$searchTerm\uf8ff';

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: searchTerm)
          .where('username', isLessThan: endTerm)
          .limit(limit)
          .get();

      final results = snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data()))
          .where((user) => user.uid != excludeUid) // Exclude current user
          .toList();

      return results;
    } catch (e, stackTrace) {
      LoggerService.logError('Error searching users', e, stackTrace);
      return [];
    }
  }
}

