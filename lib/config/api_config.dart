// config/api_config.dart
import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  /// Optional custom override URL (e.g., Render cloud URL or custom IP like 'http://192.168.1.50:8000')
  /// Set this to point the app to a hosted server or physical device IP.
  static String? customBaseUrl;

  // Automatically select host according to platform
  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.isNotEmpty) {
      return customBaseUrl!;
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000';
    } else if (Platform.isAndroid) {
      // 192.168.18.35 is your PC local Wi-Fi IP address so physical mobile phone can reach backend
      return 'http://192.168.18.35:8000';
    } else {
      return 'http://127.0.0.1:8000';
    }
  }

  // Auth endpoints
  static String get signupUrl => '$baseUrl/api/signup';
  static String get loginUrl => '$baseUrl/api/login';
  static String get meUrl => '$baseUrl/api/me';
  static String get updateProfileUrl => '$baseUrl/api/users/profile';

  // Item endpoints
  static String get itemsUrl => '$baseUrl/api/items';
  static String itemByIdUrl(String id) => '$baseUrl/api/items/$id';
  static String userItemsUrl(String userId) => '$baseUrl/api/users/$userId/items';
  static String itemVerifyUrl(String itemId) => '$baseUrl/api/items/$itemId/verify';
  static String checkVerifyUrl(String itemId, String userId) => '$baseUrl/api/items/$itemId/verify/check/$userId';

  // Notification endpoints
  static String get notificationsUrl => '$baseUrl/api/notifications';
  static String markNotificationReadUrl(String id) => '$baseUrl/api/notifications/$id/read';
  static String get markAllNotificationsReadUrl => '$baseUrl/api/notifications/read-all';

  // Chat endpoints
  static String get chatsUrl => '$baseUrl/api/chats';
  static String chatMessagesUrl(String chatId) => '$baseUrl/api/chats/$chatId/messages';

  // Common JSON headers
  static Map<String, String> headers({String? token}) {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      map['Authorization'] = 'Bearer $token';
    }
    return map;
  }
}
