import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/post_model.dart';
import '../../services/auth_service.dart';
import '../../services/block_service.dart';
import '../../services/post_service.dart';
import '../../services/storage_service.dart';
import '../../services/like_service.dart';
import '../../widgets/report_content_sheet.dart';
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
  VideoPlayerController? _videoController;
  bool _isVideoPlaying = true;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likesCount;
    _commentCount = widget.post.commentsCount;
    _checkLikeStatus();
    if (widget.post.isVideo) _initVideo();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _initVideo() {
    _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.post.imageUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.setLooping(true);
          _videoController!.play();
        }
      });
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
      // Show premium loading overlay
      showGeneralDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 250),
        transitionBuilder: (ctx, anim, secondAnim, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          );
        },
        pageBuilder: (ctx, anim, secondAnim) {
          return Material(
            type: MaterialType.transparency,
            child: PopScope(
            canPop: false,
            child: Stack(
              children: [
                // Frosted glass background
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                // Center card
                Center(
                  child: Container(
                    width: 200,
                    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF2A2A2A),
                          Color(0xFF1A1A1A),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFF29F05).withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF29F05).withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated icon + spinner ring
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 56,
                                height: 56,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: const Color(0xFFF29F05).withOpacity(0.8),
                                ),
                              ),
                              const _PulsingIcon(
                                icon: Icons.delete_outline,
                                color: Color(0xFFF29F05),
                                size: 26,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Deleting',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Cleaning up your post...',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          );
        },
      );

      try {
        final storageService = StorageService();
        await storageService.deletePostImage(widget.post.uid, widget.post.postId, mediaType: widget.post.mediaType);

        final postService = PostService();
        await postService.deletePost(widget.post.postId, widget.post.uid);

        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // Return to previous page
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Close loading dialog
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

  void _showOptionsMenu() {
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
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Report Post', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _reportPost();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: Text('Block @${widget.username}', style: const TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmBlock();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _reportPost() async {
    final uid = widget.currentUid.isNotEmpty
        ? widget.currentUid
        : context.read<AuthService>().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    final reason = await ReportContentSheet.show(context, title: 'Report Post');
    if (reason == null || !mounted) return;

    final blockService = BlockService();
    try {
      await blockService.reportPost(
        reporterUid: uid,
        reportedUid: widget.post.uid,
        postId: widget.post.postId,
        reason: reason,
      );
      await blockService.hidePost(uid, widget.post.postId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Report received — removed from your feed. We review reports within 24 hours.'),
            backgroundColor: Colors.green,
          ),
        );
        // Return to previous screen; 'reported' lets the feed remove it instantly
        Navigator.pop(context, 'reported');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit report: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmBlock() {
    final uid = widget.currentUid.isNotEmpty
        ? widget.currentUid
        : context.read<AuthService>().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Block @${widget.username}? Their content will be removed from your feed and they won\'t be able to message you.',
          style: const TextStyle(color: Colors.grey),
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
                await BlockService().blockUser(uid, widget.post.uid);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('User blocked'), backgroundColor: Colors.green),
                  );
                  Navigator.pop(context, 'blocked');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to block user: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Block', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
            )
          else
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: _showOptionsMenu,
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

            // Post Media — constrained to max 4:5 aspect ratio
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.width * 1.25, // 4:5
              ),
              child: Container(
                width: double.infinity,
                color: const Color(0xFF111111),
                child: widget.post.isVideo
                    ? _buildVideoPlayer()
                    : Image.network(
                        widget.post.imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            height: MediaQuery.of(context).size.width,
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
                        errorBuilder: (_, __, ___) => SizedBox(
                          height: MediaQuery.of(context).size.width,
                          child: const Center(
                            child: Icon(Icons.broken_image,
                                size: 64, color: Colors.grey),
                          ),
                        ),
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

  Widget _buildVideoPlayer() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return SizedBox(
        height: MediaQuery.of(context).size.width,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFF29F05)),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
        setState(() => _isVideoPlaying = _videoController!.value.isPlaying);
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _videoController!.value.aspectRatio,
            child: VideoPlayer(_videoController!),
          ),
          // Play/pause overlay
          if (!_isVideoPlaying)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 40),
            ),
          // Mute button
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                final vol = _videoController!.value.volume;
                _videoController!.setVolume(vol > 0 ? 0 : 1);
                setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  _videoController!.value.volume > 0 ? Icons.volume_up : Icons.volume_off,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          // Progress bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFFF29F05),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing icon widget for the delete loading overlay
class _PulsingIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _PulsingIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Icon(widget.icon, color: widget.color, size: widget.size),
    );
  }
}
