import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String notificationId;
  final String recipientUid;
  final String senderUid;
  final String senderUsername;
  final String? senderProfilePic;
  final String type; // "follow", "like", "comment"
  final String? postId;
  final String? postImageUrl;
  final String? commentText;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.notificationId,
    required this.recipientUid,
    required this.senderUid,
    required this.senderUsername,
    this.senderProfilePic,
    required this.type,
    this.postId,
    this.postImageUrl,
    this.commentText,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'recipientUid': recipientUid,
      'senderUid': senderUid,
      'senderUsername': senderUsername,
      'senderProfilePic': senderProfilePic,
      'type': type,
      'postId': postId,
      'postImageUrl': postImageUrl,
      'commentText': commentText,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    DateTime parseCreatedAt() {
      final value = map['createdAt'];
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return NotificationModel(
      notificationId: map['notificationId'] ?? '',
      recipientUid: map['recipientUid'] ?? '',
      senderUid: map['senderUid'] ?? '',
      senderUsername: map['senderUsername'] ?? '',
      senderProfilePic: map['senderProfilePic'],
      type: map['type'] ?? '',
      postId: map['postId'],
      postImageUrl: map['postImageUrl'],
      commentText: map['commentText'],
      isRead: map['isRead'] ?? false,
      createdAt: parseCreatedAt(),
    );
  }
}
