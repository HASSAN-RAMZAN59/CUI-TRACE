import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_services.dart';
import '../services/app_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final String? currentImageUrl;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentEmail,
    this.currentImageUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final AppService _appService = AppService();

  XFile? _newImage;
  Uint8List? _imageBytes;
  bool _loading = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.currentName;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = await _appService.getCurrentUser();
      if (currentUser != null) {
        _nameController.text = currentUser.displayName.isNotEmpty
            ? currentUser.displayName
            : widget.currentName;
      }
    } catch (e) {
      print('❌ Error loading user data: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final xFile = await _cloudinaryService.pickImage(
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 90,
      );

      if (xFile != null) {
        final bytes = await xFile.readAsBytes();
        if (mounted) {
          setState(() {
            _newImage = xFile;
            _imageBytes = bytes;
          });
        }
        print('✅ Image selected: ${xFile.name}');
      }
    } catch (e) {
      print('❌ Error picking image: $e');
      _showError('Failed to pick image: ${e.toString()}');
    }
  }

  Future<void> _updateProfile() async {
    if (_nameController.text.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    if (_nameController.text.length < 2) {
      _showError('Name should be at least 2 characters');
      return;
    }

    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final userId = _appService.currentUserId ?? 'user_id';
      await _appService.updateUserProfile(
        userId: userId,
        displayName: _nameController.text.trim(),
      );

      print('✅ Profile updated successfully');
      _showSuccess('Profile updated successfully!');

      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context, true);
        });
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      _showError('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _buildImagePreview() {
    if (_imageBytes != null) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.blue.shade50,
        backgroundImage: MemoryImage(_imageBytes!),
        child: _uploadingImage
            ? const CircularProgressIndicator(color: Colors.white)
            : null,
      );
    } else if (widget.currentImageUrl != null && widget.currentImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.blue.shade50,
        backgroundImage: NetworkImage(widget.currentImageUrl!),
      );
    } else {
      return CircleAvatar(
        radius: 60,
        backgroundColor: Colors.blue.shade100,
        child: Text(
          _nameController.text.isNotEmpty
              ? _nameController.text[0].toUpperCase()
              : 'U',
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 3,
        actions: [
          if (_loading || _uploadingImage)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _updateProfile,
              tooltip: 'Save Changes',
            ),
        ],
      ),
      backgroundColor: Colors.blue.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Stack(
                children: [
                  _buildImagePreview(),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _uploadingImage ? null : _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _uploadingImage
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                            : const Icon(
                          Icons.camera_alt,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Text(
              'Full Name',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Enter your full name',
                prefixIcon: const Icon(Icons.person, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Email',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: TextEditingController(text: widget.currentEmail),
              readOnly: true,
              decoration: InputDecoration(
                hintText: 'Email cannot be changed',
                prefixIcon: const Icon(Icons.email, color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.grey),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Phone Number (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'Enter your phone number',
                prefixIcon: const Icon(Icons.phone, color: Colors.blue),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Profile Information',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Your name will be visible on your reports\n'
                        '• Profile image is uploaded to Cloudinary\n'
                        '• Email cannot be changed for security',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 3,
                  shadowColor: Colors.blue.shade300,
                ),
                onPressed: (_loading || _uploadingImage) ? null : _updateProfile,
                icon: (_loading || _uploadingImage)
                    ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.save, size: 24),
                label: (_loading || _uploadingImage)
                    ? const Text('Updating...')
                    : const Text(
                  'Update Profile',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            if (_loading || _uploadingImage)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 10),
                      Text(
                        'Please wait, updating profile...',
                        style: TextStyle(color: Colors.blue),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}