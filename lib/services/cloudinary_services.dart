// lib/services/cloudinary_services.dart -
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import '../config/cloudinary_config.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickImage({required int imageQuality, required int maxHeight, required int maxWidth}) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      return pickedFile;
    } catch (e) {
      print('❌ Error picking image: $e');
      return null;
    }
  }
  Future<String> uploadImage(dynamic imageSource, {String folder = 'cui_trace'}) async {
    try {
      print('📤 Uploading image to Cloudinary...');

      late File imageFile;
      late List<int> imageBytes;
      String? mimeType;
      String? fileName;

      if (imageSource is File) {
        imageFile = imageSource;
        imageBytes = await imageFile.readAsBytes();
        mimeType = lookupMimeType(imageFile.path);
        fileName = imageFile.path.split('/').last;
      } else if (imageSource is XFile) {
        imageBytes = await imageSource.readAsBytes();
        mimeType = lookupMimeType(imageSource.path);
        fileName = imageSource.name;
        imageFile = File(imageSource.path);
      } else {
        throw Exception('Invalid image source type');
      }

      if (!kIsWeb) {
        final fileSize = await imageFile.length();
        if (fileSize > 10 * 1024 * 1024) {
          throw Exception('Image size should be less than 10MB');
        }
      }
      mimeType ??= 'image/jpeg';
      if (!mimeType.startsWith('image/')) {
        throw Exception('Invalid image file type: $mimeType');
      }

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/image/upload');
      final request = http.MultipartRequest('POST', uri);

      // Add file
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName ?? 'image_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.fields['folder'] = folder;
      request.fields['public_id'] = 'item_${DateTime.now().millisecondsSinceEpoch}';

      print('🔄 Sending request to Cloudinary...');
      print('📤 Parameters: upload_preset=${CloudinaryConfig.uploadPreset}');

      final response = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Cloudinary upload timeout');
        },
      );

      final responseData = await http.Response.fromStream(response);
      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(responseData.body);
        final secureUrl = jsonResponse['secure_url'] as String;
        print('✅ Image uploaded successfully');
        return secureUrl;
      } else {
        final errorBody = responseData.body;
        print('❌ Upload failed: ${response.statusCode}');

        if (errorBody.contains('Transformation parameter is not allowed')) {
          throw Exception(
              'ERROR: Remove transformation parameters from upload request.'
          );
        }

        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Cloudinary upload error: $e');
      rethrow;
    }
  }
  Future<bool> deleteImage(String publicId) async {
    try {
      print('🗑️ Deleting image: $publicId');

      return true;
    } catch (e) {
      print('❌ Error deleting image: $e');
      return true;
    }
  }
  String getOptimizedImageUrl(String originalUrl, {
    int width = 500,
    int height = 500,
    String crop = 'fill',
    String quality = 'auto',
    String format = 'auto',
  }) {
    try {
      return addTransformation(
        originalUrl,
        width: width,
        height: height,
      );
    } catch (e) {
      print('⚠️ Error optimizing URL: $e');
      return originalUrl;
    }
  }
  String addTransformation(String originalUrl, {
    int width = 800,
    int height = 600,
    String crop = 'fill',
    String quality = 'auto',
  }) {
    try {

      if (originalUrl.contains('/upload/')) {
        final parts = originalUrl.split('/upload/');
        if (parts.length == 2) {
          return '${parts[0]}/upload/c_${crop},w_${width},h_${height},q_${quality}/${parts[1]}';
        }
      }
      return originalUrl;
    } catch (e) {
      print('⚠️ Error adding transformation: $e');
      return originalUrl;
    }
  }
  String getThumbnailUrl(String originalUrl) {
    return getOptimizedImageUrl(
      originalUrl,
      width: 200,
      height: 200,
      crop: 'thumb',
      quality: 'good',
    );
  }
  String? extractPublicId(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      for (int i = segments.length - 1; i >= 0; i--) {
        final segment = segments[i];
        if (segment.contains('.') && !segment.startsWith('v')) {
          return segment.split('.').first;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<String>> uploadMultipleImages(List<dynamic> images) async {
    final List<String> urls = [];

    for (int i = 0; i < images.length; i++) {
      try {
        print('📤 Uploading image ${i + 1}/${images.length}...');
        final url = await uploadImage(images[i]);
        urls.add(url);
      } catch (e) {
        print('⚠️ Failed to upload image ${i + 1}: $e');
      }
    }

    return urls;
  }


  bool isCloudinaryUrl(String url) {
    return url.contains('cloudinary.com') || url.contains('res.cloudinary.com');
  }
}