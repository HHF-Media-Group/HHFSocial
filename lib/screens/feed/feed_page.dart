import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/post_service.dart';
import '../../services/follow_service.dart';
import '../../services/like_service.dart';
import '../post/post_detail_page.dart';
import '../post/comments_sheet.dart';
import '../profile/user_profile_page.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => FeedPageState();
}

class FeedPageState extends State<FeedPage> {
  final PostService _postService = PostService();
  final FollowService _followService = FollowService();
  final DatabaseService _databaseService = DatabaseService();
  final LikeService _likeService = LikeService();
  final ScrollController _scrollController = ScrollController();

  List<PostModel> _posts = [];
  Map<String, UserModel> _userCache = {};
  Map<String, bool> _likedPosts = {};
  Map<String, int> _likeCounts = {};
  Map<String, int> _commentCounts = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _currentUid;
  List<String> _followingUids = [];
  DocumentSnapshot? _lastDocument;

  // Track which post is showing the heart animation
  String? _animatingPostId;

  @override
  void initState() {
    super.initState();
    _currentUid = context.read<AuthService>().currentUser?.uid;
    _scrollController.addListener(_onScroll);
    _loadFeed();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  /// Public method to reload the feed (called on tab switch)
  void reload() {
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    if (_currentUid == null) return;

    setState(() {
      _isLoading = true;
      _lastDocument = null;
      _hasMore = true;
    });

    _followingUids = await _followService.getFollowing(_currentUid!);

    // First page: followed first, then discovery
    final result = await _postService.getPaginatedPosts(
      currentUid: _currentUid!,
      pageSize: 20,
    );

    // Also get followed posts for priority
    List<PostModel> followedPosts = [];
    if (_followingUids.isNotEmpty) {
      followedPosts = await _postService.getFeedPosts(_followingUids, limit: 15);
    }

    // Merge: followed first, then paginated (dedupe)
    final followedIds = followedPosts.map((p) => p.postId).toSet();
    final discoveryPosts = result.posts
        .where((p) => !followedIds.contains(p.postId))
        .toList();

    final allPosts = [...followedPosts, ...discoveryPosts];

    _lastDocument = result.lastDoc;
    if (result.posts.isEmpty) _hasMore = false;

    await _hydratePostData(allPosts, replace: true);
  }

  Future<void> _loadMore() async {
    if (_currentUid == null || _lastDocument == null) return;

    setState(() => _isLoadingMore = true);

    final result = await _postService.getPaginatedPosts(
      currentUid: _currentUid!,
      startAfter: _lastDocument,
      pageSize: 15,
    );

    _lastDocument = result.lastDoc;
    if (result.posts.isEmpty) {
      if (mounted) setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
      return;
    }

    // Remove duplicates (posts already in feed)
    final existingIds = _posts.map((p) => p.postId).toSet();
    final newPosts = result.posts
        .where((p) => !existingIds.contains(p.postId))
        .toList();

    await _hydratePostData(newPosts, replace: false);
  }

  /// Fetches user data, like status, and counts for a list of posts.
  /// If [replace] is true, replaces the entire feed; otherwise appends.
  Future<void> _hydratePostData(List<PostModel> posts, {required bool replace}) async {
    final uniqueUids = posts.map((p) => p.uid).toSet().toList();
    final users = await _databaseService.getUsersByIds(uniqueUids);
    final userMap = {for (var u in users) u.uid: u};

    final postIds = posts.map((p) => p.postId).toList();
    final likedMap = await _likeService.batchCheckLikes(_currentUid!, postIds);

    final countMap = {for (var p in posts) p.postId: p.likesCount};
    final commentCountMap = {for (var p in posts) p.postId: p.commentsCount};

    if (mounted) {
      setState(() {
        if (replace) {
          _posts = posts;
          _userCache = userMap;
          _likedPosts = likedMap;
          _likeCounts = countMap;
          _commentCounts = commentCountMap;
        } else {
          _posts.addAll(posts);
          _userCache.addAll(userMap);
          _likedPosts.addAll(likedMap);
          _likeCounts.addAll(countMap);
          _commentCounts.addAll(commentCountMap);
        }
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _toggleLike(String postId) async {
    if (_currentUid == null) return;

    final isLiked = _likedPosts[postId] ?? false;

    // Optimistic update
    setState(() {
      _likedPosts[postId] = !isLiked;
      _likeCounts[postId] = (_likeCounts[postId] ?? 0) + (isLiked ? -1 : 1);
    });

    try {
      if (isLiked) {
        await _likeService.unlikePost(_currentUid!, postId);
      } else {
        await _likeService.likePost(_currentUid!, postId);
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          _likedPosts[postId] = isLiked;
          _likeCounts[postId] = (_likeCounts[postId] ?? 0) + (isLiked ? 1 : -1);
        });
      }
    }
  }

  void _onDoubleTap(String postId) {
    final isLiked = _likedPosts[postId] ?? false;

    // Only like on double-tap, never unlike
    if (!isLiked) {
      _toggleLike(postId);
    }

    // Trigger heart animation
    setState(() => _animatingPostId = postId);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _animatingPostId = null);
    });
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

  void _navigateToUserProfile(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserProfilePage(user: user)),
    );
  }

  void _navigateToPostDetail(PostModel post, UserModel? user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailPage(
          post: post,
          currentUid: _currentUid ?? '',
          username: user?.username ?? '',
          profilePictureUrl: user?.profilePictureUrl,
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
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset('assets/icon.png', height: 32),
            const SizedBox(width: 10),
            const Text(
              'Post Feed',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFF29F05),
                fontSize: 22,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF29F05)),
            )
          : _posts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadFeed,
                  color: const Color(0xFFF29F05),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: _posts.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Loading footer
                      if (index == _posts.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: _isLoadingMore
                                ? const CircularProgressIndicator(
                                    color: Color(0xFFF29F05),
                                    strokeWidth: 2,
                                  )
                                : Text(
                                    'Scroll for more',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                          ),
                        );
                      }
                      final post = _posts[index];
                      final user = _userCache[post.uid];
                      return _buildPostCard(post, user);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 72, color: Colors.grey[700]),
          const SizedBox(height: 16),
          const Text(
            'Your feed is empty',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Follow people to see their\nposts and updates here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(PostModel post, UserModel? user) {
    final isLiked = _likedPosts[post.postId] ?? false;
    final likeCount = _likeCounts[post.postId] ?? post.likesCount;
    final isAnimating = _animatingPostId == post.postId;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with double-tap to like
          GestureDetector(
            onTap: () => _navigateToPostDetail(post, user),
            onDoubleTap: () => _onDoubleTap(post.postId),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(
                      post.displayImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
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
                        child: const Center(
                          child: Icon(Icons.broken_image,
                              color: Colors.grey, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
                // Video play icon overlay
                if (post.isVideo)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                    ),
                  ),
                // Animated heart overlay on double-tap
                if (isAnimating)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value > 0.8 ? 2.0 - (value * 1.25) : 1.0,
                        child: Transform.scale(
                          scale: value,
                          child: const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 80,
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          // Gold accent divider
          Container(
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFF29F05),
                  Color(0xFFFFD54F),
                  Color(0xFFF29F05),
                ],
              ),
            ),
          ),

          // Bottom info panel
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                GestureDetector(
                  onTap: user != null
                      ? () => _navigateToUserProfile(user)
                      : null,
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF444444),
                        backgroundImage: user?.profilePictureUrl != null
                            ? NetworkImage(user!.profilePictureUrl!)
                            : null,
                        child: user?.profilePictureUrl == null
                            ? const Icon(Icons.person,
                                color: Colors.grey, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          user?.username ?? 'unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Text(
                        _timeAgo(post.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Caption
                if (post.caption != null && post.caption!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: RichText(
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${user?.username ?? ''} ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: post.caption!,
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Actions row - like + comment
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      // Like button
                      GestureDetector(
                        onTap: () => _toggleLike(post.postId),
                        child: Row(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) {
                                return ScaleTransition(
                                    scale: animation, child: child);
                              },
                              child: Icon(
                                isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                key: ValueKey(isLiked),
                                color: isLiked
                                    ? Colors.red
                                    : Colors.grey[500],
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$likeCount',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Comment button
                      GestureDetector(
                        onTap: () => _openComments(post.postId),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline,
                                color: Colors.grey[500], size: 20),
                            const SizedBox(width: 6),
                            Text(
                              '${_commentCounts[post.postId] ?? post.commentsCount}',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openComments(String postId) async {
    await CommentsSheet.show(context, postId);
    // Refresh comment count after sheet closes
    if (mounted) {
      _loadFeed();
    }
  }
}
