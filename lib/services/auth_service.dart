import 'package:firebase_auth/firebase_auth.dart';
import '../utils/logger_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

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

  // Get Current User
  User? get currentUser => _auth.currentUser;
}
