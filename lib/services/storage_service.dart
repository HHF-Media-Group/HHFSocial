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

  // Upload Post Image
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

  // Upload Post Video (with real progress tracking)
  Future<String?> uploadPostVideo(
    String uid,
    File video,
    String postId, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final ref = _storage.ref().child('posts').child(uid).child('$postId.mp4');
      
      final uploadTask = ref.putFile(
        video,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Stream real progress
      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((event) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        });
      }

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e, stackTrace) {
      LoggerService.logError('Error uploading post video', e, stackTrace);
      rethrow;
    }
  }

  // Upload Video Thumbnail
  Future<String?> uploadVideoThumbnail(String uid, File thumbnail, String postId) async {
    try {
      final ref = _storage.ref().child('posts').child(uid).child('${postId}_thumb.jpg');
      
      final uploadTask = await ref.putFile(
        thumbnail,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e, stackTrace) {
      LoggerService.logError('Error uploading video thumbnail', e, stackTrace);
      rethrow;
    }
  }

  // Delete Profile Picture
  Future<void> deleteProfilePicture(String uid) async {
    try {
      final ref = _storage.ref().child('profile_pictures').child('$uid.jpg');
      await ref.delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting profile picture', e, stackTrace);
    }
  }

  // Delete Post Media (handles both image and video)
  Future<void> deletePostImage(String uid, String postId, {String mediaType = 'image'}) async {
    try {
      if (mediaType == 'video') {
        // Delete video file
        final videoRef = _storage.ref().child('posts').child(uid).child('$postId.mp4');
        await videoRef.delete();
        // Delete thumbnail
        try {
          final thumbRef = _storage.ref().child('posts').child(uid).child('${postId}_thumb.jpg');
          await thumbRef.delete();
        } catch (_) {}
      } else {
        final ref = _storage.ref().child('posts').child(uid).child('$postId.jpg');
        await ref.delete();
      }
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting post media', e, stackTrace);
    }
  }

  // Delete Image (Generic URL based)
  Future<void> deleteImage(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting image from URL', e, stackTrace);
    }
  }
}
