import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../utils/logger_service.dart';

class DatabaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<bool> isUsernameTaken(String username) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      return result.docs.isNotEmpty;
    } catch (e, stackTrace) {
      LoggerService.logError('Error checking username uniqueness', e, stackTrace);
      // Fail safe: assume taken to prevent duplicates if DB is down, 
      // or false to allow retry? 
      // Better to throw so UI handles "network error" instead of creating duplicate.
      rethrow;
    }
  }
}
