// screens/edit_item_screen.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/item_model.dart';
import '../services/app_service.dart';
import '../services/cloudinary_services.dart';
import '../utils/constants.dart';

class EditItemScreen extends StatefulWidget {
  final String itemId;
  final ItemModel? item;

  const EditItemScreen({
    super.key,
    required this.itemId,
    this.item,
  });

  @override
  State<EditItemScreen> createState() => _EditItemScreenState();
}

class _EditItemScreenState extends State<EditItemScreen> {
  // Form controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  // State variables
  String? _selectedCategory;
  bool _isLost = true;
  DateTime? _selectedDate;
  XFile? _newImage;
  Uint8List? _imageBytes;

  // Loading states
  bool _isLoading = false;
  bool _isInitialLoading = true;
  final bool _isImageLoading = false;

  // Current item data
  String _currentImageUrl = '';
  String _originalUploader = '';
  String _originalUploaderId = '';
  DateTime _originalReportDate = DateTime.now();
  DateTime _originalCreatedAt = DateTime.now();

  // Services
  final AppService _appService = AppService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _imagePicker = ImagePicker();

  String _actualDocumentId = '';

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      if (widget.item != null) {
        _loadFromItemModel();
      } else {
        if (widget.itemId.isEmpty) {
          _showError('Cannot edit item: Item ID is missing');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
          return;
        }
        await _loadFromAppService();
      }
    } catch (e) {
      _showError('Failed to initialize: $e');
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  void _loadFromItemModel() {
    try {
      final item = widget.item!;
      _actualDocumentId = item.id;

      _titleController.text = item.title;
      _descriptionController.text = item.description;
      _locationController.text = item.location;
      _selectedCategory = item.category;
      _isLost = item.isLost;
      _selectedDate = item.date;
      _currentImageUrl = item.imageUrl;
      _originalUploader = item.uploader;
      _originalUploaderId = item.uploaderId;
      _originalReportDate = item.reportDate;
      _originalCreatedAt = item.createdAt ?? DateTime.now();

      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    } catch (e) {
      _showError('Failed to load item data: $e');
    }
  }

  Future<void> _loadFromAppService() async {
    try {
      final item = await _appService.getItemById(widget.itemId);

      if (item != null && mounted) {
        _actualDocumentId = item.id;

        _titleController.text = item.title;
        _descriptionController.text = item.description;
        _locationController.text = item.location;
        _selectedCategory = item.category;
        _isLost = item.isLost;
        _selectedDate = item.date;
        _currentImageUrl = item.imageUrl;
        _originalUploader = item.uploader;
        _originalUploaderId = item.uploaderId;
        _originalReportDate = item.reportDate;
        _originalCreatedAt = item.createdAt ?? DateTime.now();
      } else {
        _showError('Item not found');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      debugPrint('Error loading item: $e');
      _showError('Failed to load item details: $e');
    } finally {
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _newImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _updateItem() async {
    if (!_validateForm()) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      String imageUrl = _currentImageUrl;
      if (_newImage != null) {
        try {
          imageUrl = await _cloudinaryService.uploadImage(_newImage!);
        } catch (e) {
          _showWarning('Image upload failed. Keeping old image.');
        }
      }

      final updatedItem = ItemModel(
        id: _actualDocumentId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        location: _locationController.text.trim(),
        category: _selectedCategory!,
        isLost: _isLost,
        date: _selectedDate ?? DateTime.now(),
        reportDate: _originalReportDate,
        uploader: _originalUploader,
        uploaderId: _originalUploaderId,
        imageUrl: imageUrl,
        createdAt: _originalCreatedAt,
        updatedAt: DateTime.now(),
      );

      await _appService.updateItem(updatedItem);

      _showSuccess('Item updated successfully!');

      if (mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          Navigator.pop(context, true);
        });
      }
    } catch (e) {
      _showError('Failed to update item: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      _showError('Please select category');
      return false;
    }
    if (_selectedDate == null) {
      _showError('Please select date');
      return false;
    }
    if (_actualDocumentId.isEmpty) {
      _showError('Cannot update: Item ID is missing');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
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
        content: Text(message),
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
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_isImageLoading) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_imageBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          _imageBytes!,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    if (_currentImageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: _cloudinaryService.getOptimizedImageUrl(_currentImageUrl),
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.grey.shade200,
            child: Center(
              child: CircularProgressIndicator(
                color: _isLost ? Colors.blue : Colors.green,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: Colors.grey.shade200,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text('Failed to load image', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_camera, size: 50, color: Colors.grey),
          SizedBox(height: 8),
          Text('No image', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Edit Item'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Item'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(),
              const SizedBox(height: 24),
              _buildFormFields(),
              const SizedBox(height: 32),
              _buildUpdateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Item Image',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _buildImagePreview(),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Change Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade50,
              foregroundColor: Colors.blue,
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildReportTypeSelector(),
        const SizedBox(height: 20),
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
          initialValue: _selectedCategory,
          decoration: InputDecoration(
            labelText: 'Category*',
            prefixIcon: const Icon(Icons.category),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
          ),
          items: AppConstants.itemCategories
              .map(
                (category) => DropdownMenuItem(
              value: category,
              child: Text(category),
            ),
          )
              .toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
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
              labelText: 'Date*',
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
            hintText: 'Provide additional details...',
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
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
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

  Widget _buildUpdateButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: (_isLoading || _actualDocumentId.isEmpty) ? null : _updateItem,
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.check),
            label: _isLoading
                ? const Text('Updating...')
                : const Text(
              'Update Item',
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
      ],
    );
  }
}