import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../utils/logger_service.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload Profile Picture
  Future<String?> uploadProfilePicture(String uid, File image) async {
    try {
      final ref = _storage.ref().child('profile_pictures').child('$uid.jpg');
      
      final uploadTask = await ref.putFile(
        image,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e, stackTrace) {
      LoggerService.logError('Error uploading profile picture', e, stackTrace);
      rethrow;
    }
  }

  // Upload Post Image (for future use)
  Future<String?> uploadPostImage(String uid, File image, String postId) async {
    try {
      final ref = _storage.ref().child('posts').child(uid).child('$postId.jpg');
      
      final uploadTask = await ref.putFile(
        image,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e, stackTrace) {
      LoggerService.logError('Error uploading post image', e, stackTrace);
      rethrow;
    }
  }

  // Delete Image (Robust method using UID)
  Future<void> deleteProfilePicture(String uid) async {
    try {
      // Direct path reference is more robust than refFromURL
      final ref = _storage.ref().child('profile_pictures').child('$uid.jpg');
      await ref.delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting profile picture', e, stackTrace);
      // We don't rethrow here because if the file doesn't exist (e.g. already deleted),
      // we still want the UI to update and remove the link from Firestore.
    }
  }

  // Delete Post Image (Robust method using UID and postId)
  Future<void> deletePostImage(String uid, String postId) async {
    try {
      final ref = _storage.ref().child('posts').child(uid).child('$postId.jpg');
      await ref.delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting post image', e, stackTrace);
    }
  }

  // Delete Image (Generic URL based - kept for other uses if needed)
  Future<void> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting image from URL', e, stackTrace);
    }
  }
}
