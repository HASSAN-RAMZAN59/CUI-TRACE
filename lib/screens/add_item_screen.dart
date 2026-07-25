// screens/add_item_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart' show Uint8List;

import '../services/app_service.dart';
import '../models/item_model.dart';

class AddItemScreen extends StatefulWidget {
  const AddItemScreen({super.key});

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // State variables
  String? _selectedCategory;
  bool _isLost = true;
  DateTime? _selectedDate;
  XFile? _selectedImage;
  bool _isLoading = false;
  bool _isUploading = false;

  // Security Questions Variables
  bool _enableSecurityQuestions = false;
  final List<TextEditingController> _questionControllers = [];
  final List<TextEditingController> _answerControllers = [];
  final List<Map<String, dynamic>> _securityQuestions = [];

  // Services
  final ImagePicker _imagePicker = ImagePicker();
  final AppService _appService = AppService();

  // Constants
  static const List<String> _categories = [
    'Electronics',
    'Documents',
    'Accessories',
    'Clothing',
    'Books',
    'Bags',
    'Keys',
    'Wallet/Purse',
    'Other'
  ];

  static const List<String> _suggestedQuestions = [
    'What color is the item?',
    'Any distinctive marks or scratches?',
    'Where exactly did you lose/find it?',
    'What time did you lose/find it?',
    'What brand is it?',
    'Any accessories included?',
    'Serial number/IMEI last 4 digits?',
    'What was inside? (for wallet/bag)',
    'When did you purchase it?',
    'Where did you buy it from?',
  ];

  @override
  void initState() {
    super.initState();
    _addEmptyQuestion();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();

    for (var controller in _questionControllers) {
      controller.dispose();
    }
    for (var controller in _answerControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addEmptyQuestion() {
    setState(() {
      _questionControllers.add(TextEditingController());
      _answerControllers.add(TextEditingController());
      _securityQuestions.add({'question': '', 'answer': ''});
    });
  }

  void _addSuggestedQuestion(String question) {
    if (_securityQuestions.length >= 3) {
      _showWarning('Maximum 3 questions allowed');
      return;
    }

    setState(() {
      _questionControllers.add(TextEditingController(text: question));
      _answerControllers.add(TextEditingController());
      _securityQuestions.add({'question': question, 'answer': ''});
    });
  }

  void _removeQuestion(int index) {
    if (_securityQuestions.length <= 1) {
      _showWarning('At least one question is required');
      return;
    }

    setState(() {
      _questionControllers[index].dispose();
      _answerControllers[index].dispose();
      _questionControllers.removeAt(index);
      _answerControllers.removeAt(index);
      _securityQuestions.removeAt(index);
    });
  }

  void _updateQuestion(int index) {
    if (index < _securityQuestions.length) {
      setState(() {
        _securityQuestions[index] = {
          'question': _questionControllers[index].text.trim(),
          'answer': _answerControllers[index].text.trim(),
        };
      });
    }
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null) {
      setState(() => _selectedDate = selectedDate);
    }
  }

  Future<void> _pickImage() async {
    try {
      if (_isLoading) return;

      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      setState(() => _isLoading = true);

      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null) {
        final fileSize = await image.length();
        if (fileSize > 10 * 1024 * 1024) {
          _showError('Image size should be less than 10MB');
          return;
        }

        setState(() => _selectedImage = image);
      }
    } catch (e) {
      _showError('Failed to pick image: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_validateForm()) return;

    if (_enableSecurityQuestions) {
      for (int i = 0; i < _securityQuestions.length; i++) {
        final question = _questionControllers[i].text.trim();
        final answer = _answerControllers[i].text.trim();

        if (question.isEmpty) {
          _showError('Please enter question ${i + 1}');
          return;
        }
        if (answer.isEmpty) {
          _showError('Please enter answer for question ${i + 1}');
          return;
        }

        _securityQuestions[i] = {
          'question': question,
          'answer': answer,
        };
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _isUploading = true;
      });
    }

    try {
      final preparedSecurityQuestions = _enableSecurityQuestions
          ? _securityQuestions
          .where((q) =>
      (q['question']?.toString().isNotEmpty ?? false) &&
          (q['answer']?.toString().isNotEmpty ?? false))
          .map((q) => {
        'question': q['question']?.toString() ?? '',
        'answer': q['answer']?.toString() ?? '',
      })
          .toList()
          : <Map<String, dynamic>>[];

      File? imageFile;
      if (_selectedImage != null) {
        imageFile = File(_selectedImage!.path);
      }

      if (imageFile != null) {
        await _appService.uploadItem(
          imageFile: imageFile,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          category: _selectedCategory!,
          isLost: _isLost,
          date: _selectedDate,
          securityQuestions: preparedSecurityQuestions,
          requiresVerification:
          _enableSecurityQuestions && preparedSecurityQuestions.isNotEmpty,
        );
      } else {
        final currentUser = await _appService.getCurrentUser();
        final item = ItemModel(
          id: const Uuid().v4(),
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          category: _selectedCategory!,
          isLost: _isLost,
          date: _selectedDate ?? DateTime.now(),
          reportDate: DateTime.now(),
          uploader: currentUser?.displayName ?? 'User',
          uploaderId: currentUser?.id ?? 'guest',
          imageUrl: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          securityQuestions: preparedSecurityQuestions,
          requiresVerification:
          _enableSecurityQuestions && preparedSecurityQuestions.isNotEmpty,
          isClaimed: false,
        );

        await _appService.addItem(item);
      }

      _showSuccess('Report submitted successfully!');

      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context, true);
        });
      }
    } catch (e) {
      _showError('Failed to submit report: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploading = false;
        });
      }
    }
  }

  bool _validateForm() {
    if (_titleController.text.trim().isEmpty) {
      _showError('Please enter item title');
      return false;
    }

    if (_locationController.text.trim().isEmpty) {
      _showError('Please enter location');
      return false;
    }

    if (_selectedCategory == null) {
      _showError('Please select category');
      return false;
    }

    return true;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
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
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildSecurityQuestionsSection() {
    if (!_enableSecurityQuestions) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Security Questions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.blue,
              ),
            ),
            Chip(
              label: const Text('Optional but recommended'),
              backgroundColor: Colors.blue.shade50,
              side: BorderSide(color: Colors.blue.shade200),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'These questions help verify the rightful owner. Add 1-3 questions.',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _securityQuestions.length,
          itemBuilder: (context, index) {
            return _buildQuestionCard(index);
          },
        ),
        const SizedBox(height: 12),
        if (_securityQuestions.length < 3)
          ElevatedButton.icon(
            onPressed: () => _addEmptyQuestion(),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add Another Question'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              foregroundColor: Colors.blue,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        const SizedBox(height: 16),
        _buildSuggestedQuestions(),
      ],
    );
  }

  Widget _buildQuestionCard(int index) {
    return Card(
      margin: EdgeInsets.only(bottom: 12, top: index == 0 ? 0 : 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Question ${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                if (_securityQuestions.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () => _removeQuestion(index),
                    color: Colors.red,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _questionControllers[index],
              onChanged: (_) => _updateQuestion(index),
              decoration: InputDecoration(
                labelText: 'Question',
                hintText: 'e.g., What color is the item?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _answerControllers[index],
              onChanged: (_) => _updateQuestion(index),
              decoration: InputDecoration(
                labelText: 'Correct Answer',
                hintText: 'Only the real owner knows this',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.blue.shade600),
                const SizedBox(width: 6),
                Text(
                  'Answer is hidden for security',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestedQuestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested Questions:',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestedQuestions
              .where((question) => !_securityQuestions.any((q) =>
              (q['question']?.toString() ?? '').contains(question)))
              .map((question) {
            return ActionChip(
              label: Text(question),
              onPressed: () => _addSuggestedQuestion(question),
              backgroundColor: Colors.blue.shade50,
              side: BorderSide(color: Colors.blue.shade200),
              labelStyle: TextStyle(color: Colors.blue.shade700),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Report'),
        centerTitle: true,
        elevation: 0,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReportTypeSelector(),
              const SizedBox(height: 24),
              _buildFormFields(),
              const SizedBox(height: 24),
              _buildImageUploadSection(),
              _buildSecurityToggle(),
              _buildSecurityQuestionsSection(),
              const SizedBox(height: 32),
              _buildSubmitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityToggle() {
    return Card(
      margin: const EdgeInsets.only(top: 20, bottom: 8),
      child: SwitchListTile(
        title: const Text(
          'Enable Security Verification',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: const Text(
          'Require questions to verify ownership before contact',
        ),
        value: _enableSecurityQuestions,
        onChanged: (value) {
          setState(() {
            _enableSecurityQuestions = value;
            if (value && _securityQuestions.isEmpty) {
              _addEmptyQuestion();
            }
          });
        },
        secondary: Icon(
          _enableSecurityQuestions ? Icons.security : Icons.security_outlined,
          color: _enableSecurityQuestions ? Colors.blue : Colors.grey,
        ),
        activeColor: Colors.blue,
      ),
    );
  }

  Widget _buildReportTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Type',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTypeButton(
                isSelected: _isLost,
                icon: Icons.search,
                label: 'Lost Item',
                color: Colors.blue,
                onTap: () => setState(() => _isLost = true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeButton(
                isSelected: !_isLost,
                icon: Icons.find_in_page,
                label: 'Found Item',
                color: Colors.green,
                onTap: () => setState(() => _isLost = false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeButton({
    required bool isSelected,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? color : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? color : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Item Title*',
            hintText: 'e.g., Black Leather Wallet',
            prefixIcon: const Icon(Icons.title),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Category*',
            prefixIcon: const Icon(Icons.category),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: _categories
              .map(
                (category) => DropdownMenuItem(
              value: category,
              child: Text(category),
            ),
          )
              .toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
          validator: (value) =>
          value == null ? 'Please select category' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: 'Location*',
            hintText: 'e.g., Library 2nd Floor',
            prefixIcon: const Icon(Icons.location_on),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'Date (Optional)',
              prefixIcon: const Icon(Icons.calendar_today),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDate == null
                      ? 'Select Date'
                      : DateFormat('MMM dd, yyyy').format(_selectedDate!),
                  style: TextStyle(
                    color: _selectedDate == null
                        ? Colors.grey.shade600
                        : Colors.black,
                  ),
                ),
                Icon(
                  Icons.calendar_month,
                  color: Colors.blue.shade400,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Description (Optional)',
            hintText:
            'Provide additional details like color, brand, identifying marks...',
            prefixIcon: const Icon(Icons.description),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
        ),
      ],
    );
  }

  Widget _buildImageUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Image (Optional)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Max size: 10MB • Supported: JPG, PNG, WebP',
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isLoading ? null : _pickImage,
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedImage == null
                    ? Colors.blue.shade300
                    : Colors.green.shade300,
                width: 2,
                style: BorderStyle.solid,
              ),
              color: Colors.grey.shade50,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildImagePreviewWithOverlay(),
            ),
          ),
        ),
        if (_selectedImage != null) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => setState(() => _selectedImage = null),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Remove Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildImagePreviewWithOverlay() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        _buildImagePreview(),
        if (_selectedImage != null)
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() => _selectedImage = null),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImagePreview() {
    if (_selectedImage == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 50,
            color: Colors.blue.shade300,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap to add image',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Max 10MB • JPG, PNG, WebP',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      );
    }

    return FutureBuilder<List<int>>(
      future: _selectedImage!.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Colors.blue.shade400,
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.broken_image,
                size: 40,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                'Failed to load image',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          );
        }

        return Image.memory(
          Uint8List.fromList(snapshot.data!),
          fit: BoxFit.cover,
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _submitReport,
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.cloud_upload_outlined),
            label: _isLoading
                ? const Text('Submitting...')
                : const Text(
              'Submit Report',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
              elevation: 2,
            ),
          ),
        ),
        if (_isUploading) ...[
          const SizedBox(height: 16),
          Column(
            children: [
              LinearProgressIndicator(
                backgroundColor: Colors.blue.shade100,
                color: Colors.blue,
                minHeight: 4,
              ),
              const SizedBox(height: 8),
              Text(
                'Uploading to Cloudinary...',
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}