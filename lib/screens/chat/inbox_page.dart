import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/database_service.dart';
import '../../services/block_service.dart';
import 'chat_detail_page.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  State<InboxPage> createState() => InboxPageState();
}

class InboxPageState extends State<InboxPage> with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final DatabaseService _dbService = DatabaseService();
  final BlockService _blockService = BlockService();
  String? _currentUid;
  List<String> _blockedUids = [];
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _currentUid = context.read<AuthService>().currentUser?.uid;
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadBlockedUsers();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  void reload() {
    _loadBlockedUsers();
    if (mounted) setState(() {});
  }

  Future<void> _loadBlockedUsers() async {
    if (_currentUid == null) return;
    final blocked = await _blockService.getBlockedUsers(_currentUid!);
    if (mounted) setState(() => _blockedUids = blocked);
  }

  Future<void> _onRefresh() async {
    await _loadBlockedUsers();
    // Small delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUid == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1F1F1F),
        body: Center(child: Text('Not logged in', style: TextStyle(color: Colors.grey))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: const Text(
          'Messages',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: _chatService.getUserChats(_currentUid!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return _buildShimmerList();
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[700]),
                  const SizedBox(height: 12),
                  Text('Error loading messages', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry', style: TextStyle(color: Color(0xFFF29F05))),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data ?? [];

          if (chats.isEmpty) {
            return RefreshIndicator(
              color: const Color(0xFFF29F05),
              backgroundColor: const Color(0xFF2A2A2A),
              onRefresh: _onRefresh,
              child: ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.6,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A2A2A),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No messages yet',
                            style: TextStyle(color: Colors.grey[400], fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Search for users to start a conversation',
                            style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFFF29F05),
            backgroundColor: const Color(0xFF2A2A2A),
            onRefresh: _onRefresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: chats.length,
              separatorBuilder: (_, __) => Padding(
                padding: const EdgeInsets.only(left: 76),
                child: Divider(color: Colors.grey[800]!.withOpacity(0.5), height: 1),
              ),
              itemBuilder: (context, index) {
                return _ChatTile(
                  chat: chats[index],
                  currentUid: _currentUid!,
                  dbService: _dbService,
                  blockService: _blockService,
                  shimmerController: _shimmerController,
                  onTap: (user) => _openChat(chats[index], user),
                  onBlock: () => _loadBlockedUsers(),
                );
              },
            ),
          );
        },
      ),
    );
  }

  /// Shimmer loading skeleton for the inbox list
  Widget _buildShimmerList() {
    return ListView.builder(
      itemCount: 8,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            final shimmerValue = _shimmerController.value;
            final opacity = 0.3 + 0.4 * (0.5 + 0.5 * (1.0 - (2.0 * (shimmerValue - 0.5)).abs()));

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  // Avatar skeleton
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(80, 80, 80, opacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username skeleton
                        Container(
                          width: 100 + (index % 3) * 30,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(80, 80, 80, opacity),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Message preview skeleton
                        Container(
                          width: 160 + (index % 2) * 40,
                          height: 10,
                          decoration: BoxDecoration(
                            color: Color.fromRGBO(60, 60, 60, opacity),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Time skeleton
                  Container(
                    width: 28,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color.fromRGBO(60, 60, 60, opacity),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openChat(ChatModel chat, UserModel otherUser) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDetailPage(
          chatId: chat.chatId,
          currentUid: _currentUid!,
          otherUser: otherUser,
        ),
      ),
    );
  }
}

class _ChatTile extends StatefulWidget {
  final ChatModel chat;
  final String currentUid;
  final DatabaseService dbService;
  final BlockService blockService;
  final AnimationController shimmerController;
  final Function(UserModel) onTap;
  final VoidCallback onBlock;

  const _ChatTile({
    required this.chat,
    required this.currentUid,
    required this.dbService,
    required this.blockService,
    required this.shimmerController,
    required this.onTap,
    required this.onBlock,
  });

  @override
  State<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends State<_ChatTile> {
  UserModel? _otherUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final otherUid = widget.chat.otherUid(widget.currentUid);
    if (otherUid.isEmpty) return;
    final user = await widget.dbService.getUser(otherUid);
    if (mounted) setState(() { _otherUser = user; _isLoading = false; });
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  void _showOptions() {
    if (_otherUser == null) return;
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
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmBlock();
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
          'Block @${_otherUser!.username}? They won\'t be able to message you.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await widget.blockService.blockUser(widget.currentUid, _otherUser!.uid);
              widget.onBlock();
              if (mounted) {
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
              await widget.blockService.reportUser(
                reporterUid: widget.currentUid,
                reportedUid: _otherUser!.uid,
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
    if (_isLoading || _otherUser == null) {
      return _buildTileShimmer();
    }

    final unread = widget.chat.unreadFor(widget.currentUid);
    final hasUnread = unread > 0;

    return InkWell(
      onTap: () => widget.onTap(_otherUser!),
      onLongPress: _showOptions,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar with online-like ring for unread
            Container(
              decoration: hasUnread
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFF29F05), width: 2),
                    )
                  : null,
              padding: hasUnread ? const EdgeInsets.all(2) : null,
              child: CircleAvatar(
                radius: hasUnread ? 26 : 28,
                backgroundColor: const Color(0xFF333333),
                backgroundImage: _otherUser!.profilePictureUrl != null
                    ? NetworkImage(_otherUser!.profilePictureUrl!)
                    : null,
                child: _otherUser!.profilePictureUrl == null
                    ? const Icon(Icons.person, color: Colors.grey, size: 28)
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            // Name + message preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherUser!.username,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    widget.chat.lastMessage.isEmpty
                        ? 'Tap to start chatting'
                        : widget.chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasUnread ? Colors.white70 : Colors.grey[600],
                      fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Time + unread badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo(widget.chat.lastMessageAt),
                  style: TextStyle(
                    color: hasUnread ? const Color(0xFFF29F05) : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (hasUnread) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF29F05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTileShimmer() {
    return AnimatedBuilder(
      animation: widget.shimmerController,
      builder: (context, child) {
        final shimmerValue = widget.shimmerController.value;
        final opacity = 0.3 + 0.4 * (0.5 + 0.5 * (1.0 - (2.0 * (shimmerValue - 0.5)).abs()));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(80, 80, 80, opacity),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(80, 80, 80, opacity),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 180,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(60, 60, 60, opacity),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
