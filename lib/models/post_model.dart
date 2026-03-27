import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String uid;
  final String imageUrl;
  final String mediaType; // "image" or "video"
  final String? thumbnailUrl; // video thumbnail URL
  final String? caption;
  final DateTime createdAt;
  final int likesCount;
  final int commentsCount;

  PostModel({
    required this.postId,
    required this.uid,
    required this.imageUrl,
    this.mediaType = 'image',
    this.thumbnailUrl,
    this.caption,
    required this.createdAt,
    this.likesCount = 0,
    this.commentsCount = 0,
  });

  bool get isVideo => mediaType == 'video';

  /// Returns the best image URL for thumbnails/grids
  String get displayImageUrl => thumbnailUrl ?? imageUrl;

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'uid': uid,
      'imageUrl': imageUrl,
      'mediaType': mediaType,
      'thumbnailUrl': thumbnailUrl,
      'caption': caption,
      'createdAt': Timestamp.fromDate(createdAt),
      'likesCount': likesCount,
      'commentsCount': commentsCount,
    };
  }

  factory PostModel.fromMap(Map<String, dynamic> map) {
    DateTime parseCreatedAt() {
      final value = map['createdAt'];
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return PostModel(
      postId: map['postId'] ?? '',
      uid: map['uid'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      mediaType: map['mediaType'] ?? 'image', // backward compatible
      thumbnailUrl: map['thumbnailUrl'],
      caption: map['caption'],
      createdAt: parseCreatedAt(),
      likesCount: map['likesCount'] ?? 0,
      commentsCount: map['commentsCount'] ?? 0,
    );
  }

  PostModel copyWith({
    String? postId,
    String? uid,
    String? imageUrl,
    String? mediaType,
    String? thumbnailUrl,
    String? caption,
    DateTime? createdAt,
    int? likesCount,
    int? commentsCount,
    bool clearCaption = false,
  }) {
    return PostModel(
      postId: postId ?? this.postId,
      uid: uid ?? this.uid,
      imageUrl: imageUrl ?? this.imageUrl,
      mediaType: mediaType ?? this.mediaType,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      caption: clearCaption ? null : (caption ?? this.caption),
      createdAt: createdAt ?? this.createdAt,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
    );
  }
}
