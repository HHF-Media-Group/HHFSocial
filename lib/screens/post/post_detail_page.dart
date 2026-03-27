import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/post_model.dart';
import '../../services/auth_service.dart';
import '../../services/post_service.dart';
import '../../services/storage_service.dart';
import '../../services/like_service.dart';
import 'comments_sheet.dart';

class PostDetailPage extends StatefulWidget {
  final PostModel post;
  final String currentUid;
  final String username;
  final String? profilePictureUrl;

  const PostDetailPage({
    super.key,
    required this.post,
    required this.currentUid,
    required this.username,
    this.profilePictureUrl,
  });

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  final LikeService _likeService = LikeService();
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  bool _isLikeLoading = true;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likesCount;
    _commentCount = widget.post.commentsCount;
    _checkLikeStatus();
  }

  Future<void> _checkLikeStatus() async {
    final uid = widget.currentUid.isNotEmpty
        ? widget.currentUid
        : context.read<AuthService>().currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      setState(() => _isLikeLoading = false);
      return;
    }

    final liked = await _likeService.hasLiked(uid, widget.post.postId);
    if (mounted) {
      setState(() {
        _isLiked = liked;
        _isLikeLoading = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    final uid = widget.currentUid.isNotEmpty
        ? widget.currentUid
        : context.read<AuthService>().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    // Optimistic update
    setState(() {
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        await _likeService.likePost(uid, widget.post.postId);
      } else {
        await _likeService.unlikePost(uid, widget.post.postId);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = !_isLiked;
          _likeCount += _isLiked ? 1 : -1;
        });
      }
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Post',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(color: Colors.grey, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final storageService = StorageService();
        await storageService.deletePostImage(widget.post.uid, widget.post.postId);

        final postService = PostService();
        await postService.deletePost(widget.post.postId, widget.post.uid);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete post: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = widget.post.uid == widget.currentUid;
    final formattedDate =
        DateFormat('MMMM d, yyyy').format(widget.post.createdAt);

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Post',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deletePost(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Header
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFF29F05),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: widget.profilePictureUrl != null
                          ? Image.network(
                              widget.profilePictureUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.person,
                                size: 20,
                                color: Colors.grey,
                              ),
                            )
                          : Container(
                              color: const Color(0xFF333333),
                              child: const Icon(
                                Icons.person,
                                size: 20,
                                color: Colors.grey,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Post Image
            SizedBox(
              width: double.infinity,
              child: Image.network(
                widget.post.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: MediaQuery.of(context).size.width,
                    color: const Color(0xFF333333),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: const Color(0xFFF29F05),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  height: MediaQuery.of(context).size.width,
                  color: const Color(0xFF333333),
                  child: const Icon(Icons.broken_image,
                      size: 64, color: Colors.grey),
                ),
              ),
            ),

            // Like Row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: GestureDetector(
                onTap: _isLikeLoading ? null : _toggleLike,
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return ScaleTransition(
                            scale: animation, child: child);
                      },
                      child: Icon(
                        _isLiked ? Icons.favorite : Icons.favorite_border,
                        key: ValueKey(_isLiked),
                        color: _isLiked ? Colors.red : Colors.grey[400],
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_likeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Comment button
                    GestureDetector(
                      onTap: _openComments,
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline,
                              color: Colors.grey[400], size: 24),
                          const SizedBox(width: 8),
                          Text(
                            '$_commentCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Caption & Date
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.post.caption != null &&
                      widget.post.caption!.isNotEmpty) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${widget.username}  ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: widget.post.caption!,
                            style: const TextStyle(
                              color: Color(0xFFE0E0E0),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _openComments() async {
    await CommentsSheet.show(context, widget.post.postId);
    // Refresh comment count after closing
    if (mounted) {
      final postService = PostService();
      final freshPost = await postService.getPost(widget.post.postId);
      if (freshPost != null && mounted) {
        setState(() {
          _commentCount = freshPost.commentsCount;
        });
      }
    }
  }
}
