import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String postId;
  final String uid;
  final String username;
  final String? profilePictureUrl;
  final String text;
  final DateTime createdAt;

  CommentModel({
    required this.commentId,
    required this.postId,
    required this.uid,
    required this.username,
    this.profilePictureUrl,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'commentId': commentId,
      'postId': postId,
      'uid': uid,
      'username': username,
      'profilePictureUrl': profilePictureUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory CommentModel.fromMap(Map<String, dynamic> map) {
    DateTime parseCreatedAt() {
      final value = map['createdAt'];
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return CommentModel(
      commentId: map['commentId'] ?? '',
      postId: map['postId'] ?? '',
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      profilePictureUrl: map['profilePictureUrl'],
      text: map['text'] ?? '',
      createdAt: parseCreatedAt(),
    );
  }
}
