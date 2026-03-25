import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/storage_service.dart';

class CreatePostPage extends StatefulWidget {
  final String uid;

  const CreatePostPage({super.key, required this.uid});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  final PostService _postService = PostService();
  final StorageService _storageService = StorageService();

  File? _selectedImage;
  bool _isPosting = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    // Auto-open gallery on page load
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickImage());
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    } else if (_selectedImage == null) {
      // User cancelled without selecting — go back
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _sharePost() async {
    if (_selectedImage == null) return;

    setState(() {
      _isPosting = true;
      _uploadProgress = 0.2;
    });

    try {
      // Generate a unique post ID
      final postId = DateTime.now().millisecondsSinceEpoch.toString();

      setState(() => _uploadProgress = 0.4);

      // 1. Upload image to Storage
      final imageUrl = await _storageService.uploadPostImage(
        widget.uid,
        _selectedImage!,
        postId,
      );

      setState(() => _uploadProgress = 0.7);

      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      // 2. Create post in Firestore
      final caption = _captionController.text.trim();
      final post = await _postService.createPost(
        uid: widget.uid,
        imageUrl: imageUrl,
        caption: caption.isNotEmpty ? caption : null,
      );

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post shared! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, post);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share post: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isPosting = false;
          _uploadProgress = 0;
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
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isPosting ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'New Post',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_selectedImage != null && !_isPosting) ? _sharePost : null,
            child: Text(
              'Share',
              style: TextStyle(
                color: (_selectedImage != null && !_isPosting)
                    ? const Color(0xFFF29F05)
                    : Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                // Image Preview
                if (_selectedImage != null)
                  GestureDetector(
                    onTap: _isPosting ? null : _pickImage,
                    child: Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.width,
                      ),
                      child: Image.file(
                        _selectedImage!,
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.width,
                      color: const Color(0xFF333333),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined,
                              size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Tap to select a photo',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Caption Input
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _captionController,
                    enabled: !_isPosting,
                    maxLines: 5,
                    minLines: 2,
                    maxLength: 2200,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Write a caption...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      border: InputBorder.none,
                      counterStyle: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ),

                // Change Photo Button
                if (_selectedImage != null && !_isPosting)
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library, color: Color(0xFFF29F05)),
                    label: const Text(
                      'Change Photo',
                      style: TextStyle(color: Color(0xFFF29F05)),
                    ),
                  ),
              ],
            ),
          ),

          // Upload Progress Overlay
          if (_isPosting)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _uploadProgress,
                        strokeWidth: 4,
                        color: const Color(0xFFF29F05),
                        backgroundColor: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${(_uploadProgress * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sharing your post...',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
