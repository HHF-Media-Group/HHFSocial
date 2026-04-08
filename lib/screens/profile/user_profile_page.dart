import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/post_service.dart';
import '../../services/follow_service.dart';
import '../../services/chat_service.dart';
import '../../services/block_service.dart';
import '../post/post_detail_page.dart';
import '../chat/chat_detail_page.dart';
import 'follow_list_page.dart';

class UserProfilePage extends StatefulWidget {
  final UserModel user;

  const UserProfilePage({super.key, required this.user});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late UserModel _user;
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;
  int _followersCount = 0;
  final DatabaseService _databaseService = DatabaseService();
  final PostService _postService = PostService();
  final FollowService _followService = FollowService();

  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _followersCount = widget.user.followersCount;
    _currentUid = context.read<AuthService>().currentUser?.uid;
    _loadData();
  }

  Future<void> _loadData() async {
    // Fetch fresh user data from Firestore (not stale search result)
    final freshUser = await _databaseService.getUser(widget.user.uid);
    final posts = await _postService.getUserPosts(widget.user.uid);

    bool following = false;
    if (_currentUid != null) {
      following = await _followService.isFollowing(_currentUid!, widget.user.uid);
    }

    if (mounted) {
      setState(() {
        if (freshUser != null) {
          _user = freshUser;
          _followersCount = freshUser.followersCount;
        }
        _posts = posts;
        _isFollowing = following;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUid == null || _isFollowLoading) return;

    setState(() => _isFollowLoading = true);

    try {
      if (_isFollowing) {
        await _followService.unfollowUser(_currentUid!, widget.user.uid);
        setState(() {
          _isFollowing = false;
          _followersCount--;
        });
      } else {
        await _followService.followUser(_currentUid!, widget.user.uid);
        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: Text(
          user.username,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showBlockReportMenu,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF29F05)),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Header
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Profile Picture
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: const Color(0xFF333333),
                          backgroundImage: user.profilePictureUrl != null
                              ? NetworkImage(user.profilePictureUrl!)
                              : null,
                          child: user.profilePictureUrl == null
                              ? const Icon(Icons.person,
                                  size: 44, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 24),
                        // Stats
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn('${_posts.length}', 'Posts'),
                              _buildStatColumn(
                                '$_followersCount',
                                'Followers',
                                onTap: () => _openFollowList(FollowListType.followers),
                              ),
                              _buildStatColumn(
                                '${user.followingCount}',
                                'Following',
                                onTap: () => _openFollowList(FollowListType.following),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Name & Bio
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (user.bio != null && user.bio!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              user.bio!,
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 14,
                              ),
                            ),
                          ),
                        if (user.website != null && user.website!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              user.website!,
                              style: const TextStyle(
                                color: Color(0xFF5B9BD5),
                                fontSize: 14,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Follow / Following + Message Buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Follow/Following button
                        Expanded(
                          child: _isFollowing
                              ? OutlinedButton(
                                  onPressed: _isFollowLoading ? null : _toggleFollow,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFF555555)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: _isFollowLoading
                                      ? const SizedBox(
                                          height: 18, width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text('Following', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                )
                              : ElevatedButton(
                                  onPressed: _isFollowLoading ? null : _toggleFollow,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF29F05),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: _isFollowLoading
                                      ? const SizedBox(
                                          height: 18, width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                        )
                                      : const Text('Follow', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                ),
                        ),
                        const SizedBox(width: 8),
                        // Message button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _openChat,
                            icon: const Icon(Icons.chat_bubble_outline, size: 18),
                            label: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF555555)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  const Divider(color: Color(0xFF333333), height: 1),

                  // Photo Grid or Empty State
                  if (_posts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 60),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No Posts Yet',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 2,
                        mainAxisSpacing: 2,
                      ),
                      itemCount: _posts.length,
                      itemBuilder: (context, index) {
                        final post = _posts[index];
                        return GestureDetector(
                          onTap: () => _navigateToPostDetail(post),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                post.displayImageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: const Color(0xFF333333),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFF29F05),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  color: const Color(0xFF333333),
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.grey),
                                ),
                              ),
                              if (post.isVideo)
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 22,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Future<void> _navigateToPostDetail(PostModel post) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          post: post,
          currentUid: '', // Empty string → delete button won't show (not owner)
          username: widget.user.username,
          profilePictureUrl: widget.user.profilePictureUrl,
        ),
      ),
    );
  }

  Widget _buildStatColumn(String count, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  void _openFollowList(FollowListType type) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FollowListPage(
          uid: _user.uid,
          username: _user.username,
          listType: type,
        ),
      ),
    );
  }

  void _openChat() async {
    if (_currentUid == null) return;
    if (_currentUid == _user.uid) return; // Can't message yourself

    try {
      // Check if blocked
      final blockService = BlockService();
      final blockedByOther = await blockService.isBlockedBy(_currentUid!, _user.uid);
      if (blockedByOther && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot message this user.'), backgroundColor: Colors.red),
        );
        return;
      }

      final chatService = ChatService();
      final chatId = await chatService.getOrCreateChat(_currentUid!, _user.uid);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatDetailPage(
              chatId: chatId,
              currentUid: _currentUid!,
              otherUser: _user,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening chat: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showBlockReportMenu() {
    final blockService = BlockService();
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
            FutureBuilder<bool>(
              future: blockService.isBlocked(_currentUid ?? '', _user.uid),
              builder: (context, snapshot) {
                final isBlocked = snapshot.data ?? false;
                return ListTile(
                  leading: Icon(
                    isBlocked ? Icons.check_circle : Icons.block,
                    color: isBlocked ? Colors.green : Colors.red,
                  ),
                  title: Text(
                    isBlocked ? 'Unblock @${_user.username}' : 'Block @${_user.username}',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isBlocked) {
                      _confirmUnblock(blockService);
                    } else {
                      _confirmBlock(blockService);
                    }
                  },
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.orange),
              title: const Text('Report User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog(blockService);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmBlock(BlockService blockService) {
    if (_currentUid == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Block @${_user.username}? They won\'t be able to message you.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await blockService.blockUser(_currentUid!, _user.uid);
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

  void _confirmUnblock(BlockService blockService) {
    if (_currentUid == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Unblock User', style: TextStyle(color: Colors.white)),
        content: Text(
          'Unblock @${_user.username}?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await blockService.unblockUser(_currentUid!, _user.uid);
              if (mounted) {
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

  void _showReportDialog(BlockService blockService) {
    if (_currentUid == null) return;
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
              await blockService.reportUser(
                reporterUid: _currentUid!,
                reportedUid: _user.uid,
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
}
