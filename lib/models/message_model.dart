import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String messageId;
  final String senderUid;
  final String text;
  final String type; // "text" or "image"
  final String? imageUrl;
  final bool edited;
  final DateTime createdAt;

  MessageModel({
    required this.messageId,
    required this.senderUid,
    required this.text,
    this.type = 'text',
    this.imageUrl,
    this.edited = false,
    required this.createdAt,
  });

  bool get isImage => type == 'image';

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderUid': senderUid,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
      'edited': edited,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    DateTime parseCreatedAt() {
      final value = map['createdAt'];
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return MessageModel(
      messageId: map['messageId'] ?? '',
      senderUid: map['senderUid'] ?? '',
      text: map['text'] ?? '',
      type: map['type'] ?? 'text',
      imageUrl: map['imageUrl'],
      edited: map['edited'] ?? false,
      createdAt: parseCreatedAt(),
    );
  }
}
