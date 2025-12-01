import 'package:firebase_auth/firebase_auth.dart';

class AuthExceptionHandler {
  static String generateErrorMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'email-already-in-use':
          return 'This email address is already in use.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'operation-not-allowed':
          return 'Email/password accounts are not enabled.';
        case 'weak-password':
          return 'Password is too weak. Please use a stronger password.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        case 'credential-already-in-use':
            return 'This credential is already associated with a different user account.';
        case 'invalid-credential':
            return 'Sorry, your password was incorrect. Please double-check your password.';
        default:
          return 'An error occurred: ${error.message}';
      }
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }
}
