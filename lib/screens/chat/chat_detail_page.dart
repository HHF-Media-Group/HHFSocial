import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../services/chat_service.dart';
import '../../services/block_service.dart';
import '../profile/user_profile_page.dart';

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String currentUid;
  final UserModel otherUser;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.currentUid,
    required this.otherUser,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final ChatService _chatService = ChatService();
  final BlockService _blockService = BlockService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isSending = false;
  bool _isSendingImage = false;
  bool _isBlockedByOther = false;
  bool _hasBlockedOther = false;

  @override
  void initState() {
    super.initState();
    _chatService.markAsRead(widget.chatId, widget.currentUid);
    _checkBlockStatus();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkBlockStatus() async {
    final blockedByOther = await _blockService.isBlockedBy(widget.currentUid, widget.otherUser.uid);
    final hasBlocked = await _blockService.isBlocked(widget.currentUid, widget.otherUser.uid);
    if (mounted) {
      setState(() {
        _isBlockedByOther = blockedByOther;
        _hasBlockedOther = hasBlocked;
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await _chatService.sendMessage(widget.chatId, widget.currentUid, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _sendImage() async {
    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 80,
    );

    if (pickedFile == null) return;

    setState(() => _isSendingImage = true);
    try {
      await _chatService.sendImage(widget.chatId, widget.currentUid, File(pickedFile.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingImage = false);
    }
  }

  void _showBlockReportMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
            ),
            ListTile(
              leading: Icon(
                _hasBlockedOther ? Icons.check_circle : Icons.block,
                color: _hasBlockedOther ? Colors.green : Colors.red,
              ),
              title: Text(
                _hasBlockedOther ? 'Unblock @${widget.otherUser.username}' : 'Block @${widget.otherUser.username}',
                style: const TextStyle(color: Colors.white),
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (_hasBlockedOther) {
                  _confirmUnblock();
                } else {
                  _confirmBlock();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Report User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmBlock() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Block @${widget.otherUser.username}? They won\'t be able to message you.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _blockService.blockUser(widget.currentUid, widget.otherUser.uid);
              if (mounted) {
                setState(() => _hasBlockedOther = true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User blocked'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmUnblock() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Unblock User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Unblock @${widget.otherUser.username}? They will be able to message you again.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _blockService.unblockUser(widget.currentUid, widget.otherUser.uid);
              if (mounted) {
                setState(() => _hasBlockedOther = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User unblocked'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Unblock', style: TextStyle(color: Color(0xFFF29F05))),
          ),
        ],
      ),
    );
  }

  void _showReportDialog() {
    final reasons = ['Spam', 'Harassment', 'Inappropriate content', 'Fake account', 'Other'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Report User', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) => ListTile(
            title: Text(reason, style: const TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(ctx);
              await _blockService.reportUser(
                reporterUid: widget.currentUid,
                reportedUid: widget.otherUser.uid,
                reason: reason,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. Thank you.'), backgroundColor: Colors.green),
                );
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leadingWidth: 30,
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => UserProfilePage(user: widget.otherUser)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF333333),
                backgroundImage: widget.otherUser.profilePictureUrl != null
                    ? NetworkImage(widget.otherUser.profilePictureUrl!)
                    : null,
                child: widget.otherUser.profilePictureUrl == null
                    ? const Icon(Icons.person, color: Colors.grey, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  widget.otherUser.username,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showBlockReportMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: _chatService.getMessages(widget.chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFFF29F05)),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.waving_hand, size: 48, color: Colors.grey[700]),
                        const SizedBox(height: 12),
                        Text(
                          'Say hello to @${widget.otherUser.username}!',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // Mark as read whenever new messages arrive
                _chatService.markAsRead(widget.chatId, widget.currentUid);

                // Reverse the list: newest at index 0 (bottom of screen)
                final reversed = messages.reversed.toList();

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: reversed.length,
                  itemBuilder: (context, index) {
                    final msg = reversed[index];
                    final isMe = msg.senderUid == widget.currentUid;

                    // Date separator: in reversed list, check the NEXT index
                    // (which is the chronologically earlier message)
                    final showDate = index == reversed.length - 1 ||
                        !_isSameDay(reversed[index + 1].createdAt, msg.createdAt);

                    return Column(
                      children: [
                        if (showDate) _buildDateSeparator(msg.createdAt),
                        _buildMessageBubble(msg, isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Blocked banner or input bar
          if (_isBlockedByOther)
            Container(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              color: const Color(0xFF2A2A2A),
              child: const Text(
                'You cannot reply to this conversation.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            )
          else if (_hasBlockedOther)
            Container(
              padding: EdgeInsets.only(
                left: 16, right: 16, top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              color: const Color(0xFF2A2A2A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('You blocked this user. ', style: TextStyle(color: Colors.grey, fontSize: 14)),
                  GestureDetector(
                    onTap: _confirmUnblock,
                    child: const Text('Unblock', style: TextStyle(color: Color(0xFFF29F05), fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    String label;
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      label = 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildMessageBubble(MessageModel msg, bool isMe) {
    return GestureDetector(
      onLongPress: () => _showMessageActions(msg, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: isMe ? const Color(0xFFF29F05) : const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
            ),
          ),
          child: msg.isImage && msg.imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Image.network(
                        msg.imageUrl!,
                        width: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const SizedBox(
                            width: 220, height: 160,
                            child: Center(child: CircularProgressIndicator(color: Color(0xFFF29F05), strokeWidth: 2)),
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8, bottom: 4, top: 2),
                        child: Text(
                          DateFormat.jm().format(msg.createdAt),
                          style: TextStyle(color: isMe ? Colors.black54 : Colors.grey, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.text,
                        style: TextStyle(
                          color: isMe ? Colors.black : Colors.white,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (msg.edited)
                            Text(
                              'edited  ',
                              style: TextStyle(
                                color: isMe ? Colors.black38 : Colors.grey[600],
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          Text(
                            DateFormat.jm().format(msg.createdAt),
                            style: TextStyle(color: isMe ? Colors.black54 : Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  void _showMessageActions(MessageModel msg, bool isMe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2)),
            ),
            // Message preview
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                msg.isImage ? '📷 Photo' : msg.text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
            const Divider(color: Color(0xFF444444), height: 1),
            // Copy (always available for text)
            if (!msg.isImage)
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white70),
                title: const Text('Copy', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: msg.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message copied'),
                      backgroundColor: Color(0xFF333333),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            // Edit (only for own text messages)
            if (isMe && !msg.isImage)
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFFF29F05)),
                title: const Text('Edit', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditDialog(msg);
                },
              ),
            // Delete (only for own messages)
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(msg);
                },
              ),
            // Report (only for other's messages)
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.orange),
                title: const Text('Report', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportMessage(msg);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(MessageModel msg) {
    final editController = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Edit Message', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: editController,
          autofocus: true,
          maxLines: 5,
          minLines: 1,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1F1F1F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final newText = editController.text.trim();
              Navigator.pop(ctx);
              if (newText.isEmpty || newText == msg.text) return;
              try {
                await _chatService.editMessage(widget.chatId, msg.messageId, newText);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to edit: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFFF29F05), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(MessageModel msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Delete Message', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This message will be permanently deleted.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _chatService.deleteMessage(widget.chatId, msg.messageId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Message deleted'),
                      backgroundColor: Color(0xFF333333),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _reportMessage(MessageModel msg) {
    final reasons = ['Spam', 'Harassment', 'Inappropriate content', 'Other'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Report Message', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) => ListTile(
            title: Text(reason, style: const TextStyle(color: Colors.white)),
            onTap: () async {
              Navigator.pop(ctx);
              await _blockService.reportMessage(
                reporterUid: widget.currentUid,
                reportedUid: msg.senderUid,
                chatId: widget.chatId,
                messageId: msg.messageId,
                reason: reason,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted. Thank you.'), backgroundColor: Colors.green),
                );
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 12, right: 8, top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF2A2A2A),
        border: Border(top: BorderSide(color: Color(0xFF333333), width: 0.5)),
      ),
      child: Row(
        children: [
          // Image attach
          IconButton(
            icon: _isSendingImage
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF29F05)),
                  )
                : const Icon(Icons.image, color: Colors.grey),
            onPressed: _isSendingImage ? null : _sendImage,
          ),
          // Text input
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Colors.grey[600]),
                filled: true,
                fillColor: const Color(0xFF1F1F1F),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 4),
          // Send button
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFFF29F05)),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
