import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/comment_model.dart';
import '../../services/auth_service.dart';
import '../../services/comment_service.dart';
import '../../services/database_service.dart';
import '../../models/user_model.dart';

class CommentsSheet extends StatefulWidget {
  final String postId;

  const CommentsSheet({super.key, required this.postId});

  /// Show the comments sheet as a modal bottom sheet.
  /// Returns the updated comment count when closed.
  static Future<int?> show(BuildContext context, String postId) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsSheet(postId: postId),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final CommentService _commentService = CommentService();
  final DatabaseService _databaseService = DatabaseService();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<CommentModel> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadComments();
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid == null) return;
    final user = await _databaseService.getUser(uid);
    if (mounted && user != null) {
      setState(() => _currentUser = user);
    }
  }

  Future<void> _loadComments() async {
    final comments = await _commentService.getComments(widget.postId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    setState(() => _isSending = true);

    try {
      final comment = await _commentService.addComment(
        postId: widget.postId,
        uid: _currentUser!.uid,
        username: _currentUser!.username,
        profilePictureUrl: _currentUser!.profilePictureUrl,
        text: text,
      );

      _textController.clear();
      _focusNode.unfocus();

      if (mounted) {
        setState(() {
          _comments.add(comment);
          _isSending = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Comment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Delete this comment?',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _commentService.deleteComment(widget.postId, comment.commentId);
        if (mounted) {
          setState(() {
            _comments.removeWhere((c) => c.commentId == comment.commentId);
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo';
    return '${(diff.inDays / 365).floor()}y';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: const BoxDecoration(
          color: Color(0xFF1F1F1F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_comments.length}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF333333), height: 1),

            // Comment list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFFF29F05)),
                    )
                  : _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline,
                                  size: 48, color: Colors.grey[700]),
                              const SizedBox(height: 12),
                              Text(
                                'No comments yet',
                                style: TextStyle(
                                    color: Colors.grey[500], fontSize: 16),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Be the first to comment!',
                                style: TextStyle(
                                    color: Colors.grey[700], fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          itemCount: _comments.length,
                          itemBuilder: (context, index) {
                            return _buildCommentTile(_comments[index]);
                          },
                        ),
            ),

            // Input field
            Container(
              padding: const EdgeInsets.only(
                left: 16,
                right: 8,
                top: 8,
                bottom: 8,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A2A),
                border: Border(
                  top: BorderSide(color: Color(0xFF333333)),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF444444),
                      backgroundImage: _currentUser?.profilePictureUrl != null
                          ? NetworkImage(_currentUser!.profilePictureUrl!)
                          : null,
                      child: _currentUser?.profilePictureUrl == null
                          ? const Icon(Icons.person, color: Colors.grey, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    // Text input
                    Expanded(
                      child: TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 3,
                        minLines: 1,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          hintStyle: TextStyle(color: Colors.grey[600]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    // Send button
                    IconButton(
                      onPressed: _isSending ? null : _sendComment,
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFF29F05),
                              ),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Color(0xFFF29F05)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentTile(CommentModel comment) {
    final isOwn = _currentUser?.uid == comment.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFF444444),
            backgroundImage: comment.profilePictureUrl != null
                ? NetworkImage(comment.profilePictureUrl!)
                : null,
            child: comment.profilePictureUrl == null
                ? const Icon(Icons.person, color: Colors.grey, size: 14)
                : null,
          ),
          const SizedBox(width: 10),
          // Comment body
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _timeAgo(comment.createdAt),
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.text,
                  style: TextStyle(color: Colors.grey[300], fontSize: 13),
                ),
              ],
            ),
          ),
          // Delete button for own comments
          if (isOwn)
            GestureDetector(
              onTap: () => _deleteComment(comment),
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 2),
                child: Icon(Icons.close, size: 14, color: Colors.grey[600]),
              ),
            ),
        ],
      ),
    );
  }
}
