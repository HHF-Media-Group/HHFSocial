import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../services/database_service.dart';
import '../../utils/validators.dart';

class EditProfilePage extends StatefulWidget {
  final UserModel user;

  const EditProfilePage({super.key, required this.user});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _bioController;
  late TextEditingController _websiteController;

  final DatabaseService _databaseService = DatabaseService();

  bool _isSaving = false;
  bool _hasChanges = false;

  // Username availability state
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  String? _usernameError;
  Timer? _usernameDebounce;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _usernameController = TextEditingController(text: widget.user.username);
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _websiteController = TextEditingController(text: widget.user.website ?? '');

    // Listen for changes
    _fullNameController.addListener(_onFieldChanged);
    _usernameController.addListener(_onUsernameChanged);
    _bioController.addListener(_onFieldChanged);
    _websiteController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _fullNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    final hasChanges = _fullNameController.text.trim() != widget.user.fullName ||
        _usernameController.text.trim().toLowerCase() != widget.user.username.toLowerCase() ||
        (_bioController.text.trim()) != (widget.user.bio ?? '') ||
        (_websiteController.text.trim()) != (widget.user.website ?? '');
    
    if (hasChanges != _hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  void _onUsernameChanged() {
    _onFieldChanged();
    
    final newUsername = _usernameController.text.trim().toLowerCase();
    final originalUsername = widget.user.username.toLowerCase();

    // If same as original, clear status
    if (newUsername == originalUsername) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
        _usernameError = null;
      });
      _usernameDebounce?.cancel();
      return;
    }

    // Validate format first
    final formatError = Validators.validateUsername(newUsername);
    if (formatError != null) {
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = null;
        _usernameError = null; // Let the form validator handle format errors
      });
      _usernameDebounce?.cancel();
      return;
    }

    // Debounce the availability check (500ms)
    setState(() {
      _isCheckingUsername = true;
      _isUsernameAvailable = null;
      _usernameError = null;
    });

    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final isTaken = await _databaseService.isUsernameTaken(newUsername);
        if (mounted && _usernameController.text.trim().toLowerCase() == newUsername) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = !isTaken;
            _usernameError = isTaken ? 'Username is already taken' : null;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isCheckingUsername = false;
            _isUsernameAvailable = null;
            _usernameError = 'Could not check availability';
          });
        }
      }
    });
  }

  Widget _buildUsernameStatus() {
    if (_isCheckingUsername) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFF29F05),
        ),
      );
    }

    if (_isUsernameAvailable == true) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 20);
    }

    if (_isUsernameAvailable == false) {
      return const Icon(Icons.cancel, color: Colors.red, size: 20);
    }

    return const SizedBox.shrink();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    // Block save if username is being checked or unavailable
    if (_isCheckingUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait while username is being checked'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isUsernameAvailable == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Username is not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final newUsername = _usernameController.text.trim().toLowerCase();
      final originalUsername = widget.user.username.toLowerCase();
      final usernameChanged = newUsername != originalUsername;

      // 1. Handle username change (atomic swap)
      if (usernameChanged) {
        await _databaseService.changeUsername(
          widget.user.uid,
          originalUsername,
          newUsername,
        );
      }

      // 2. Build updates map for other fields
      final Map<String, dynamic> updates = {};
      
      final newFullName = _fullNameController.text.trim();
      if (newFullName != widget.user.fullName) {
        updates['fullName'] = newFullName;
      }

      final newBio = _bioController.text.trim();
      if (newBio != (widget.user.bio ?? '')) {
        updates['bio'] = newBio.isEmpty ? null : newBio;
      }

      String newWebsite = _websiteController.text.trim();
      // Auto-prepend https:// if user typed a URL without protocol
      if (newWebsite.isNotEmpty &&
          !newWebsite.startsWith('http://') &&
          !newWebsite.startsWith('https://')) {
        newWebsite = 'https://$newWebsite';
      }
      if (newWebsite != (widget.user.website ?? '')) {
        updates['website'] = newWebsite.isEmpty ? null : newWebsite;
      }

      // 3. Save field updates
      if (updates.isNotEmpty) {
        await _databaseService.updateUserProfile(widget.user.uid, updates);
      }

      // 4. Build updated UserModel to return
      final updatedUser = widget.user.copyWith(
        username: usernameChanged ? newUsername : null,
        fullName: newFullName != widget.user.fullName ? newFullName : null,
        bio: newBio.isNotEmpty ? newBio : null,
        website: newWebsite.isNotEmpty ? newWebsite : null,
        clearBio: newBio.isEmpty && widget.user.bio != null,
        clearWebsite: newWebsite.isEmpty && widget.user.website != null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, updatedUser);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
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
        leading: TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ),
        leadingWidth: 80,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: (_hasChanges && !_isSaving) ? _saveProfile : null,
            child: Text(
              'Done',
              style: TextStyle(
                color: (_hasChanges && !_isSaving)
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
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  // Profile Picture Section
                  Center(
                    child: Column(
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
                            child: widget.user.profilePictureUrl != null
                                ? Image.network(
                                    widget.user.profilePictureUrl!,
                                    fit: BoxFit.cover,
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
                        const SizedBox(height: 8),
                        Text(
                          'Change profile photo on your Profile page',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(color: Color(0xFF333333)),
                  const SizedBox(height: 16),

                  // Full Name
                  _buildTextField(
                    label: 'Name',
                    controller: _fullNameController,
                    validator: Validators.validateFullName,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 20),

                  // Username
                  _buildTextField(
                    label: 'Username',
                    controller: _usernameController,
                    validator: Validators.validateUsername,
                    suffixWidget: _buildUsernameStatus(),
                    errorText: _usernameError,
                  ),
                  const SizedBox(height: 20),

                  // Bio
                  _buildTextField(
                    label: 'Bio',
                    controller: _bioController,
                    validator: Validators.validateBio,
                    maxLines: 3,
                    maxLength: 150,
                  ),
                  const SizedBox(height: 20),

                  // Website
                  _buildTextField(
                    label: 'Website',
                    controller: _websiteController,
                    validator: Validators.validateWebsite,
                    keyboardType: TextInputType.url,
                    hintText: 'https://yourwebsite.com',
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Loading overlay
          if (_isSaving)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFF29F05)),
                    SizedBox(height: 16),
                    Text(
                      'Saving...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? Function(String?)? validator,
    Widget? suffixWidget,
    String? errorText,
    String? hintText,
    int maxLines = 1,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            isDense: true,
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[700], fontSize: 16),
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF444444)),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF29F05)),
            ),
            errorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.red),
            ),
            suffixIcon: suffixWidget != null
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: suffixWidget,
                  )
                : null,
            suffixIconConstraints: const BoxConstraints(
              minHeight: 20,
              minWidth: 20,
            ),
            errorText: errorText,
            errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
            counterStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      ],
    );
  }
}
