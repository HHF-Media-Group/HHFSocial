import 'package:flutter/material.dart';
import '../../utils/app_colors.dart';
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../models/post_model.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/post_service.dart';
import '../../services/database_service.dart';
import '../post/post_detail_page.dart';
import '../profile/user_profile_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => NotificationsPageState();
}

class NotificationsPageState extends State<NotificationsPage> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _currentUid;

  @override
  void initState() {
    super.initState();
    _currentUid = context.read<AuthService>().currentUser?.uid;
    _loadNotifications();
  }

  /// Public method to reload (called on tab switch)
  void reload() {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (_currentUid == null) return;

    final notifications =
        await _notificationService.getNotifications(_currentUid!);

    if (mounted) {
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    }

    // Mark all as read after loading
    _notificationService.markAllAsRead(_currentUid!);
  }

  /// Public method to get unread count for badge
  Future<int> getUnreadCount() async {
    if (_currentUid == null) return 0;
    return _notificationService.getUnreadCount(_currentUid!);
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

  String _getActionText(NotificationModel n) {
    switch (n.type) {
      case 'follow':
        return 'started following you';
      case 'like':
        return 'liked your post';
      case 'comment':
        return 'commented: ${n.commentText ?? ''}';
      default:
        return '';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'follow':
        return Icons.person_add;
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.chat_bubble;
      default:
        return Icons.notifications;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'follow':
        return const Color(0xFF4FC3F7);
      case 'like':
        return Colors.red;
      case 'comment':
        return AppColors.primary;
      default:
        return Colors.grey;
    }
  }

  void _onNotificationTap(NotificationModel n) async {
    if (n.type == 'follow') {
      // Navigate to user profile
      final user = await DatabaseService().getUser(n.senderUid);
      if (user != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => UserProfilePage(user: user)),
        );
      }
    } else if ((n.type == 'like' || n.type == 'comment') &&
        n.postId != null) {
      // Navigate to post detail
      final post = await PostService().getPost(n.postId!);
      if (post != null && mounted) {
        final owner = await DatabaseService().getUser(post.uid);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PostDetailPage(
              post: post,
              currentUid: _currentUid ?? '',
              username: owner?.username ?? '',
              profilePictureUrl: owner?.profilePictureUrl,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Activity',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 22,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationTile(_notifications[index]);
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
          Icon(Icons.notifications_none, size: 72, color: AppColors.textHint),
          const SizedBox(height: 16),
          const Text(
            'No activity yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When someone follows you, likes or\ncomments on your posts, you\'ll see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationTile(NotificationModel n) {
    return InkWell(
      onTap: () => _onNotificationTap(n),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: n.isRead
              ? Colors.transparent
              : AppColors.surfaceElevated,
          border: const Border(
            bottom: BorderSide(color: AppColors.surfaceElevated, width: 0.5),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with type indicator
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.surface,
                  backgroundImage: n.senderProfilePic != null
                      ? NetworkImage(n.senderProfilePic!)
                      : null,
                  child: n.senderProfilePic == null
                      ? const Icon(Icons.person, color: Colors.grey, size: 22)
                      : null,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getTypeIcon(n.type),
                      size: 12,
                      color: _getTypeColor(n.type),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: n.senderUsername,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        TextSpan(
                          text: ' ${_getActionText(n)}',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(n.createdAt),
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Post thumbnail for like/comment
            if (n.postImageUrl != null) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  n.postImageUrl!,
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 44,
                    height: 44,
                    color: AppColors.surface,
                    child:
                        const Icon(Icons.image, color: Colors.grey, size: 20),
                  ),
                ),
              ),
            ],
            // Unread dot
            if (!n.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
