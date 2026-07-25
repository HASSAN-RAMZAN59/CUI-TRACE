// lib/utils/web_fixes.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class WebFix {
  static void apply() {
    if (kIsWeb) {
      // Fix for web-specific issues
      WidgetsFlutterBinding.ensureInitialized();
    }
  }

  static Widget webImage(String path, {double? width, double? height}) {
    if (kIsWeb) {
      // For Web, use Image.network
      return Image.network(
        path,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    } else {
      // For mobile, use Image.file
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: width,
            height: height,
            color: Colors.grey[300],
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    }
  }
}