import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../models/post_model.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';
import '../../services/post_service.dart';
import '../post/create_post_page.dart';
import '../post/post_detail_page.dart';
import 'edit_profile_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  UserModel? _user;
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;
  final DatabaseService _databaseService = DatabaseService();
  final StorageService _storageService = StorageService();
  final PostService _postService = PostService();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final authService = context.read<AuthService>();
    final uid = authService.currentUser?.uid;
    
    if (uid != null) {
      final user = await _databaseService.getUser(uid);
      final posts = await _postService.getUserPosts(uid);
      if (mounted) {
        setState(() {
          _user = user;
          _posts = posts;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _navigateToCreatePost() async {
    if (_user == null) return;
    final newPost = await Navigator.push<PostModel>(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePostPage(uid: _user!.uid),
      ),
    );
    if (newPost != null && mounted) {
      setState(() {
        _posts.insert(0, newPost);
      });
    }
  }

  Future<void> _navigateToPostDetail(PostModel post) async {
    final deleted = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(
          post: post,
          currentUid: _user!.uid,
          username: _user!.username,
          profilePictureUrl: _user!.profilePictureUrl,
        ),
      ),
    );
    if (deleted == true && mounted) {
      setState(() {
        _posts.removeWhere((p) => p.postId == post.postId);
      });
    }
  }

  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF333333),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFF29F05)),
              title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage();
              },
            ),
            if (_user?.profilePictureUrl != null) ...[
              const Divider(color: Color(0xFF444444)),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove Profile Picture', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _removeProfilePicture();
                },
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final File imageFile = File(pickedFile.path);
      final downloadUrl = await _storageService.uploadProfilePicture(
        _user!.uid,
        imageFile,
      );

      if (downloadUrl != null) {
        await _databaseService.updateProfilePicture(_user!.uid, downloadUrl);
        
        setState(() {
          _user = _user!.copyWith(profilePictureUrl: downloadUrl);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _removeProfilePicture() async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      // Evict image from cache to prevent "ghost" images
      if (_user?.profilePictureUrl != null) {
        await NetworkImage(_user!.profilePictureUrl!).evict();
      }

      // Delete from storage (using UID is more robust)
      await _storageService.deleteProfilePicture(_user!.uid);

      // Update Firestore
      await _databaseService.removeProfilePicture(_user!.uid);

      if (mounted) {
        setState(() {
          // Explicitly clear the profile picture in local state
          _user = _user!.copyWith(clearProfilePicture: true);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove picture: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        title: Text(
          _user?.username ?? 'Profile',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              // TODO: Settings menu
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFF29F05)))
          : RefreshIndicator(
              onRefresh: _loadUserData,
              color: const Color(0xFFF29F05),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Profile Picture
                          GestureDetector(
                            onTap: _isUploadingImage ? null : _showImageOptions,
                            child: Stack(
                              children: [
                                Container(
                                  width: 86,
                                  height: 86,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFF29F05),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _user?.profilePictureUrl != null
                                        ? Image.network(
                                            _user!.profilePictureUrl!,
                                            fit: BoxFit.cover,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const Center(
                                                child: CircularProgressIndicator(
                                                  color: Color(0xFFF29F05),
                                                  strokeWidth: 2,
                                                ),
                                              );
                                            },
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person,
                                                size: 40,
                                                color: Colors.grey,
                                              );
                                            },
                                          )
                                        : Container(
                                            color: const Color(0xFF333333),
                                            child: const Icon(
                                              Icons.person,
                                              size: 40,
                                              color: Colors.grey,
                                            ),
                                          ),
                                  ),
                                ),
                                if (_isUploadingImage)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black.withOpacity(0.5),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFF29F05),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF29F05),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          // Stats
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatColumn('${_posts.length}', 'Posts'),
                                _buildStatColumn('0', 'Followers'),
                                _buildStatColumn('0', 'Following'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Name, Bio and Website
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _user?.fullName ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@${_user?.username ?? ''}',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          if (_user?.bio != null && _user!.bio!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              _user!.bio!,
                              style: const TextStyle(
                                color: Color(0xFFE0E0E0),
                                fontSize: 14,
                              ),
                            ),
                          ],
                          if (_user?.website != null && _user!.website!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.link, color: Color(0xFFF29F05), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  _user!.website!,
                                  style: const TextStyle(
                                    color: Color(0xFFF29F05),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Edit Profile Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            if (_user == null) return;
                            final updatedUser = await Navigator.push<UserModel>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfilePage(user: _user!),
                              ),
                            );
                            if (updatedUser != null && mounted) {
                              setState(() {
                                _user = updatedUser;
                              });
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF444444)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            'Edit Profile',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Photos Header
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0xFF333333)),
                          bottom: BorderSide(color: Color(0xFFF29F05), width: 2),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Center(
                        child: Icon(
                          Icons.grid_on,
                          color: Color(0xFFF29F05),
                        ),
                      ),
                    ),
                    // Empty State or Photo Grid
                    if (_posts.isEmpty) ...[
                      const SizedBox(height: 80),
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.camera_alt_outlined,
                                size: 48,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Share Photos',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'When you share photos, they will\nappear on your profile.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => _navigateToCreatePost(),
                              child: const Text(
                                'Share your first photo',
                                style: TextStyle(
                                  color: Color(0xFFF29F05),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _posts.length,
                        itemBuilder: (context, index) {
                          final post = _posts[index];
                          return GestureDetector(
                            onTap: () => _navigateToPostDetail(post),
                            child: Image.network(
                              post.imageUrl,
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
                                child: const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
