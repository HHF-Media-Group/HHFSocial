import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/storage_service.dart';

class PostDetailPage extends StatelessWidget {
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

  Future<void> _deletePost(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF333333),
        title: const Text('Delete Post', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this post? This action cannot be undone.',
          style: TextStyle(color: Color(0xFFE0E0E0)),
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
        // Delete image from Storage
        final storageService = StorageService();
        await storageService.deletePostImage(post.uid, post.postId);

        // Delete post from Firestore
        final postService = PostService();
        await postService.deletePost(post.postId, post.uid);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // true = post was deleted
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
    final isOwner = post.uid == currentUid;
    final formattedDate = DateFormat('MMMM d, yyyy').format(post.createdAt);

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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Profile Picture
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
                      child: profilePictureUrl != null
                          ? Image.network(
                              profilePictureUrl!,
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
                    username,
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
                post.imageUrl,
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
                  child: const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                ),
              ),
            ),

            // Caption & Date
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.caption != null && post.caption!.isNotEmpty) ...[
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$username  ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          TextSpan(
                            text: post.caption!,
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
          ],
        ),
      ),
    );
  }
}
