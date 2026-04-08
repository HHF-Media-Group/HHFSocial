import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String chatId;
  final List<String> participants;
  final String lastMessage;
  final String lastMessageSenderUid;
  final DateTime lastMessageAt;
  final Map<String, int> unreadCount;

  ChatModel({
    required this.chatId,
    required this.participants,
    this.lastMessage = '',
    this.lastMessageSenderUid = '',
    required this.lastMessageAt,
    this.unreadCount = const {},
  });

  /// Get the other participant's UID
  String otherUid(String currentUid) {
    return participants.firstWhere((uid) => uid != currentUid, orElse: () => '');
  }

  /// Get unread count for a specific user
  int unreadFor(String uid) => unreadCount[uid] ?? 0;

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageSenderUid': lastMessageSenderUid,
      'lastMessageAt': Timestamp.fromDate(lastMessageAt),
      'unreadCount': unreadCount,
    };
  }

  factory ChatModel.fromMap(Map<String, dynamic> map) {
    DateTime parseLastMessageAt() {
      final value = map['lastMessageAt'];
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    return ChatModel(
      chatId: map['chatId'] ?? '',
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageSenderUid: map['lastMessageSenderUid'] ?? '',
      lastMessageAt: parseLastMessageAt(),
      unreadCount: Map<String, int>.from(map['unreadCount'] ?? {}),
    );
  }
}
