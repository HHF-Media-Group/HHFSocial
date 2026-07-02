import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_player/video_player.dart';
import '../../models/post_model.dart';
import '../../services/post_service.dart';
import '../../services/storage_service.dart';
import '../../utils/content_filter.dart';

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
  File? _selectedVideo;
  File? _videoThumbnail;
  VideoPlayerController? _videoController;
  bool _isPosting = false;
  bool _isCompressing = false;
  bool _isPickerActive = false;
  double _uploadProgress = 0;
  String _mediaType = 'image';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMediaPicker());
  }

  @override
  void dispose() {
    _captionController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  /// Show bottom sheet to choose photo or video
  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2A2A2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Create New Post',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF29F05).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Color(0xFFF29F05)),
                ),
                title: const Text('Photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Choose a photo from gallery', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage();
                },
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF29F05).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.videocam, color: Color(0xFFF29F05)),
                ),
                title: const Text('Video', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text('Choose a video (max 60s)', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickVideo();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).then((_) {
      // Only pop if picker is NOT active and no media exists
      if (!_isPickerActive && _selectedImage == null && _selectedVideo == null && mounted) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _pickImage() async {
    _isPickerActive = true;
    final XFile? pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    _isPickerActive = false;

    if (pickedFile != null) {
      _videoController?.dispose();
      _videoController = null;
      setState(() {
        _selectedImage = File(pickedFile.path);
        _selectedVideo = null;
        _videoThumbnail = null;
        _mediaType = 'image';
      });
    } else if (_selectedImage == null && _selectedVideo == null) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _pickVideo() async {
    _isPickerActive = true;
    final XFile? pickedFile = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 60),
    );
    _isPickerActive = false;

    if (pickedFile != null) {
      setState(() => _isCompressing = true);

      try {
        // Compress video
        final info = await VideoCompress.compressVideo(
          pickedFile.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );

        if (info == null || info.file == null) {
          throw Exception('Video compression failed');
        }

        // Generate thumbnail
        final thumbnailFile = await VideoCompress.getFileThumbnail(
          pickedFile.path,
          quality: 75,
          position: -1, // default position
        );

        // Initialize video preview
        _videoController?.dispose();
        final controller = VideoPlayerController.file(info.file!);
        await controller.initialize();
        controller.setLooping(true);
        controller.play();

        setState(() {
          _selectedVideo = info.file;
          _videoThumbnail = thumbnailFile;
          _selectedImage = null;
          _mediaType = 'video';
          _videoController = controller;
          _isCompressing = false;
        });
      } catch (e) {
        setState(() => _isCompressing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to process video: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (_selectedImage == null && _selectedVideo == null) {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _sharePost() async {
    if (_selectedImage == null && _selectedVideo == null) return;

    // Objectionable-content filter on the caption (App Store Guideline 1.2)
    if (ContentFilter.containsObjectionableContent(_captionController.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This caption violates our community guidelines.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isPosting = true;
      _uploadProgress = 0.1;
    });

    try {
      final postId = PostService().generatePostId();

      if (_mediaType == 'video' && _selectedVideo != null) {
        // Upload video with real progress tracking
        setState(() => _uploadProgress = 0.1);
        final videoUrl = await _storageService.uploadPostVideo(
          widget.uid, _selectedVideo!, postId,
          onProgress: (progress) {
            if (mounted) {
              // Map upload progress (0-1) to UI progress range (0.15 - 0.75)
              setState(() => _uploadProgress = 0.15 + (progress * 0.6));
            }
          },
        );

        setState(() => _uploadProgress = 0.8);

        // Upload thumbnail
        String? thumbnailUrl;
        if (_videoThumbnail != null) {
          thumbnailUrl = await _storageService.uploadVideoThumbnail(
            widget.uid, _videoThumbnail!, postId,
          );
        }

        setState(() => _uploadProgress = 0.9);

        if (videoUrl == null) throw Exception('Failed to upload video');

        final caption = _captionController.text.trim();
        final post = await _postService.createPostWithId(
          postId: postId,
          uid: widget.uid,
          imageUrl: videoUrl,
          caption: caption.isNotEmpty ? caption : null,
          mediaType: 'video',
          thumbnailUrl: thumbnailUrl,
        );

        setState(() => _uploadProgress = 1.0);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video shared! 🎬'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, post);
        }
      } else if (_selectedImage != null) {
        // Image upload (existing flow)
        setState(() => _uploadProgress = 0.3);
        final imageUrl = await _storageService.uploadPostImage(
          widget.uid, _selectedImage!, postId,
        );

        setState(() => _uploadProgress = 0.7);

        if (imageUrl == null) throw Exception('Failed to upload image');

        final caption = _captionController.text.trim();
        final post = await _postService.createPostWithId(
          postId: postId,
          uid: widget.uid,
          imageUrl: imageUrl,
          caption: caption.isNotEmpty ? caption : null,
        );

        setState(() => _uploadProgress = 1.0);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Post shared! 🎉'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, post);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.red),
        );
        setState(() {
          _isPosting = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  bool get _hasMedia => _selectedImage != null || _selectedVideo != null;

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
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_hasMedia && !_isPosting && !_isCompressing) ? _sharePost : null,
            child: Text(
              'Share',
              style: TextStyle(
                color: (_hasMedia && !_isPosting && !_isCompressing)
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
                // Media Preview
                _buildMediaPreview(),

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

                // Change Media Button
                if (_hasMedia && !_isPosting)
                  TextButton.icon(
                    onPressed: _showMediaPicker,
                    icon: const Icon(Icons.swap_horiz, color: Color(0xFFF29F05)),
                    label: Text(
                      _mediaType == 'video' ? 'Change Media' : 'Change Photo',
                      style: const TextStyle(color: Color(0xFFF29F05)),
                    ),
                  ),
              ],
            ),
          ),

          // Compression Overlay
          if (_isCompressing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFF29F05)),
                    SizedBox(height: 16),
                    Text('Compressing video...', style: TextStyle(color: Colors.white, fontSize: 16)),
                    SizedBox(height: 8),
                    Text('This may take a moment', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
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
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _mediaType == 'video' ? 'Uploading video...' : 'Sharing your post...',
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    if (_mediaType == 'video' && _videoController != null && _videoController!.value.isInitialized) {
      return GestureDetector(
        onTap: () {
          if (_videoController!.value.isPlaying) {
            _videoController!.pause();
          } else {
            _videoController!.play();
          }
          setState(() {});
        },
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.width),
          color: Colors.black,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
              // Play/Pause overlay
              if (!_videoController!.value.isPlaying)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
                ),
              // Duration badge
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam, color: Color(0xFFF29F05), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _formatDuration(_videoController!.value.duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_selectedImage != null) {
      return GestureDetector(
        onTap: _isPosting ? null : _showMediaPicker,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.width),
          child: Image.file(_selectedImage!, fit: BoxFit.cover),
        ),
      );
    } else {
      return GestureDetector(
        onTap: _showMediaPicker,
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.width,
          color: const Color(0xFF333333),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Tap to select media', style: TextStyle(color: Colors.grey, fontSize: 16)),
            ],
          ),
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
