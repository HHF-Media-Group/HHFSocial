import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import '../utils/logger_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Generate deterministic chat ID from two UIDs (sorted alphabetically)
  String getChatId(String uid1, String uid2) {
    final sorted = [uid1, uid2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  /// Get or create a chat between two users
  Future<String> getOrCreateChat(String uid1, String uid2) async {
    try {
      final chatId = getChatId(uid1, uid2);
      final docRef = _firestore.collection('chats').doc(chatId);
      final sorted = [uid1, uid2]..sort();

      // set() with merge: true but only providing chatId + participants
      // - New doc: creates with just these fields (sendMessage fills the rest)
      // - Existing doc: no-op (same values), doesn't touch lastMessage/unreadCount
      await docRef.set({
        'chatId': chatId,
        'participants': sorted,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageSenderUid': '',
        'unreadCount': {uid1: 0, uid2: 0},
      }, SetOptions(mergeFields: ['chatId', 'participants']));

      return chatId;
    } catch (e, stackTrace) {
      // If doc already exists and set fails, just return the chatId
      final chatId = getChatId(uid1, uid2);
      LoggerService.logError('Error creating chat', e, stackTrace);
      return chatId;
    }
  }

  /// Send a text or image message
  Future<void> sendMessage(
    String chatId,
    String senderUid, 
    String text, {
    String type = 'text',
    String? imageUrl,
  }) async {
    try {
      final messageRef = _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc();

      final message = MessageModel(
        messageId: messageRef.id,
        senderUid: senderUid,
        text: text,
        type: type,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
      );

      // Get chat to find the recipient UID
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
      final recipientUid = participants.firstWhere(
        (uid) => uid != senderUid,
        orElse: () => '',
      );

      // Batch write: message + update chat doc + increment user unread
      final batch = _firestore.batch();

      // 1. Add message
      batch.set(messageRef, message.toMap());

      // 2. Update chat doc
      batch.update(_firestore.collection('chats').doc(chatId), {
        'lastMessage': type == 'image' ? '📷 Photo' : text,
        'lastMessageSenderUid': senderUid,
        'lastMessageAt': Timestamp.fromDate(DateTime.now()),
        'unreadCount.$recipientUid': FieldValue.increment(1),
      });

      // 3. Increment recipient's unreadMessages on user doc
      if (recipientUid.isNotEmpty) {
        batch.update(_firestore.collection('users').doc(recipientUid), {
          'unreadMessages': FieldValue.increment(1),
        });
      }

      await batch.commit();
    } catch (e, stackTrace) {
      LoggerService.logError('Error sending message', e, stackTrace);
      rethrow;
    }
  }

  /// Delete a message
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .delete();
    } catch (e, stackTrace) {
      LoggerService.logError('Error deleting message', e, stackTrace);
      rethrow;
    }
  }

  /// Edit a message's text
  Future<void> editMessage(String chatId, String messageId, String newText) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'text': newText,
        'edited': true,
      });
    } catch (e, stackTrace) {
      LoggerService.logError('Error editing message', e, stackTrace);
      rethrow;
    }
  }

  /// Get messages stream (real-time, paginated)
  Stream<List<MessageModel>> getMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limitToLast(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data()))
            .toList());
  }

  /// Load older messages (for pagination — returns static list, not stream)
  Future<List<MessageModel>> getOlderMessages(
    String chatId, {
    required DocumentSnapshot startBefore,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .endBeforeDocument(startBefore)
          .limitToLast(limit)
          .get();

      return snapshot.docs
          .map((doc) => MessageModel.fromMap(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      LoggerService.logError('Error loading older messages', e, stackTrace);
      return [];
    }
  }

  /// Get the first message document snapshot (for pagination cursor)
  Future<DocumentSnapshot?> getFirstMessageDoc(String chatId) async {
    try {
      final snapshot = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: false)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty ? snapshot.docs.first : null;
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting first message doc', e, stackTrace);
      return null;
    }
  }

  /// Get user's chats stream (real-time, sorted by most recent)
  Stream<List<ChatModel>> getUserChats(String uid) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatModel.fromMap(doc.data()))
            .toList());
  }

  /// Mark chat as read for a user
  Future<void> markAsRead(String chatId, String uid) async {
    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      final currentUnread = (chatDoc.data()?['unreadCount'] as Map<String, dynamic>?)?[uid] ?? 0;

      if (currentUnread > 0) {
        final batch = _firestore.batch();

        // Reset unread on chat doc
        batch.update(_firestore.collection('chats').doc(chatId), {
          'unreadCount.$uid': 0,
        });

        // Decrement user's global unread counter
        batch.update(_firestore.collection('users').doc(uid), {
          'unreadMessages': FieldValue.increment(-currentUnread),
        });

        await batch.commit();
      }
    } catch (e, stackTrace) {
      LoggerService.logError('Error marking chat as read', e, stackTrace);
    }
  }

  /// Get total unread message count (O(1) — reads from user doc)
  Future<int> getTotalUnreadCount(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['unreadMessages'] ?? 0;
    } catch (e, stackTrace) {
      LoggerService.logError('Error getting unread count', e, stackTrace);
      return 0;
    }
  }

  /// Upload and send an image message
  Future<void> sendImage(String chatId, String senderUid, File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref = _storage
          .ref()
          .child('chat_images')
          .child(senderUid)
          .child('$timestamp.jpg');

      final uploadTask = await ref.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final imageUrl = await uploadTask.ref.getDownloadURL();

      await sendMessage(
        chatId,
        senderUid,
        '📷 Photo',
        type: 'image',
        imageUrl: imageUrl,
      );
    } catch (e, stackTrace) {
      LoggerService.logError('Error sending image message', e, stackTrace);
      rethrow;
    }
  }
}
