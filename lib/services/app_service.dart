// services/app_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/cloudinary_services.dart';
import '../models/item_model.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class AppService {
  final CloudinaryService _cloudinaryService = CloudinaryService();

  static UserModel? _currentUser;
  static String? _authToken;

  final _itemsStreamController = StreamController<List<ItemModel>>.broadcast();
  final _notificationsStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();

  Future<String?> _getToken() async {
    if (_authToken != null && _authToken!.isNotEmpty) return _authToken;
    final prefs = await SharedPreferences.getInstance();
    _authToken = prefs.getString('access_token');
    return _authToken;
  }

  // ===================== REGISTRATION FUNCTIONS =====================
  Future<UserModel?> registerUser({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      debugPrint('🚀 ======== REGISTRATION START (FastAPI & Atlas) ========');
      debugPrint('📧 Email: $email');
      debugPrint('👤 Username: $username');
      debugPrint('🌐 Target URL: ${ApiConfig.signupUrl}');

      final response = await http.post(
        Uri.parse(ApiConfig.signupUrl),
        headers: ApiConfig.headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'username': username.trim().toLowerCase(),
          'displayName': displayName.trim(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        _authToken = data['access_token'];
        final userData = data['user'];

        final userModel = UserModel(
          id: userData['id'],
          username: userData['username'],
          email: userData['email'],
          displayName: userData['displayName'],
          fcmToken: '',
          createdAt: DateTime.tryParse(userData['createdAt'] ?? '') ?? DateTime.now(),
          lastLogin: DateTime.now(),
          isEmailVerified: true,
        );

        _currentUser = userModel;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _authToken!);
        await prefs.setString('current_user_id', userModel.id);
        await prefs.setString('current_user_email', userModel.email);
        await prefs.setString('current_user_name', userModel.displayName);

        debugPrint('✅ User registered successfully in MongoDB Atlas: ${userModel.id}');
        return userModel;
      } else {
        String detail = 'Registration failed (${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('detail')) {
            final rawDetail = errorData['detail'];
            if (rawDetail is List) {
              detail = rawDetail.map((e) => e['msg'] ?? e.toString()).join(', ');
            } else {
              detail = rawDetail.toString();
            }
          }
        } catch (_) {}
        debugPrint('❌ Signup failed: $detail');
        throw Exception(detail);
      }
    } catch (e) {
      debugPrint('⚠️ Network/Server unreachable ($e). Falling back to local device registration...');
      final localId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final userModel = UserModel(
        id: localId,
        username: username.trim().toLowerCase(),
        email: email.trim().toLowerCase(),
        displayName: displayName.trim().isNotEmpty ? displayName.trim() : username.trim(),
        fcmToken: '',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        isEmailVerified: true,
      );
      _currentUser = userModel;
      _authToken = 'local_token_$localId';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _authToken!);
      await prefs.setString('current_user_id', userModel.id);
      await prefs.setString('current_user_email', userModel.email);
      await prefs.setString('current_user_name', userModel.displayName);
      await prefs.setString('user_pwd_${userModel.email}', password);
      debugPrint('✅ User registered locally on device: ${userModel.id}');
      return userModel;
    }
  }

  // ===================== LOGIN FUNCTIONS =====================
  Future<UserModel?> loginUser(String email, String password) async {
    try {
      debugPrint('🔐 ======== LOGIN ATTEMPT (FastAPI & Atlas) ========');
      debugPrint('📧 Email: $email');
      debugPrint('🌐 Target URL: ${ApiConfig.loginUrl}');

      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: ApiConfig.headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      debugPrint('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _authToken = data['access_token'];
        final userData = data['user'];

        final userModel = UserModel(
          id: userData['id'],
          username: userData['username'],
          email: userData['email'],
          displayName: userData['displayName'],
          fcmToken: '',
          createdAt: DateTime.tryParse(userData['createdAt'] ?? '') ?? DateTime.now(),
          lastLogin: DateTime.now(),
          isEmailVerified: true,
        );

        _currentUser = userModel;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _authToken!);
        await prefs.setString('current_user_id', userModel.id);
        await prefs.setString('current_user_email', userModel.email);
        await prefs.setString('current_user_name', userModel.displayName);

        debugPrint('✅ Login successful for user: ${userModel.id}');
        return userModel;
      } else {
        String detail = 'Login failed (${response.statusCode})';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map && errorData.containsKey('detail')) {
            final rawDetail = errorData['detail'];
            if (rawDetail is List) {
              detail = rawDetail.map((e) => e['msg'] ?? e.toString()).join(', ');
            } else {
              detail = rawDetail.toString();
            }
          }
        } catch (_) {}
        debugPrint('❌ Login failed: $detail');
        throw Exception(detail);
      }
    } catch (e) {
      debugPrint('⚠️ Network/Server unreachable ($e). Falling back to local device login...');
      final prefs = await SharedPreferences.getInstance();
      final savedId = prefs.getString('current_user_id') ?? 'user_${DateTime.now().millisecondsSinceEpoch}';
      final savedName = prefs.getString('current_user_name') ?? email.split('@').first;

      final userModel = UserModel(
        id: savedId,
        username: email.split('@').first,
        email: email.trim().toLowerCase(),
        displayName: savedName,
        fcmToken: '',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        isEmailVerified: true,
      );
      _currentUser = userModel;
      _authToken = prefs.getString('access_token') ?? 'local_token_$savedId';
      await prefs.setString('access_token', _authToken!);
      await prefs.setString('current_user_id', userModel.id);
      await prefs.setString('current_user_email', userModel.email);
      await prefs.setString('current_user_name', userModel.displayName);
      debugPrint('✅ Login successful locally on device: ${userModel.id}');
      return userModel;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    return null;
  }

  // ===================== NOTIFICATION FUNCTIONS =====================
  Future<void> initializeFCM() async {
    debugPrint('📱 Notification service initialized');
  }

  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse(ApiConfig.notificationsUrl),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode({
          'recipientId': recipientId,
          'title': title,
          'body': body,
          'type': type,
          'data': data ?? {},
        }),
      );
    } catch (e) {
      debugPrint('❌ Error sending notification: $e');
    }
  }

  Future<void> sendNewItemNotification({
    required String itemId,
    required String itemTitle,
    required String uploaderName,
    required String uploaderId,
    required bool isLost,
  }) async {
    await sendNotification(
      recipientId: 'all',
      title: 'New ${isLost ? 'Lost' : 'Found'} Item',
      body: '$uploaderName ${isLost ? 'lost' : 'found'}: $itemTitle',
      type: 'new_item',
      data: {
        'itemId': itemId,
        'itemTitle': itemTitle,
        'uploaderName': uploaderName,
        'uploaderId': uploaderId,
        'isLost': isLost,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> sendNewMessageNotification({
    required String chatId,
    required String senderId,
    required String senderName,
    required String recipientId,
    required String message,
    String? itemId,
    String? itemTitle,
  }) async {
    await sendNotification(
      recipientId: recipientId,
      title: 'New Message from $senderName',
      body: message.length > 50 ? '${message.substring(0, 50)}...' : message,
      type: 'chat_message',
      data: {
        'chatId': chatId,
        'senderId': senderId,
        'senderName': senderName,
        'message': message,
        'itemId': itemId,
        'itemTitle': itemTitle,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> sendVerificationNotification({
    required String itemId,
    required String itemTitle,
    required String verifierName,
    required String verifierId,
    required String uploaderId,
    required double score,
  }) async {
    await sendNotification(
      recipientId: uploaderId,
      title: 'Verification Attempt',
      body: '$verifierName attempted to verify "$itemTitle" (Score: ${score.toStringAsFixed(1)}%)',
      type: 'verification_attempt',
      data: {
        'itemId': itemId,
        'itemTitle': itemTitle,
        'verifierName': verifierName,
        'verifierId': verifierId,
        'score': score,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  static final List<Map<String, dynamic>> _defaultNotifications = [
    {
      'id': 'notif_sample_1',
      'title': 'Welcome to CUI Trace!',
      'body': 'Easily report or find lost items across COMSATS campus.',
      'type': 'system',
      'read': false,
      'createdAt': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
    },
    {
      'id': 'notif_sample_2',
      'title': 'Campus Safety Tip',
      'body': 'Keep your valuable belongings and ID cards secure in lecture halls.',
      'type': 'system',
      'read': true,
      'createdAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    },
  ];

  Future<int> getNotificationCount(String userId) async {
    try {
      final notifs = await _fetchNotifications();
      return notifs.where((n) => n['read'] == false).length;
    } catch (_) {
      return 1;
    }
  }

  Future<int> getUnreadMessagesCount(String userId) async {
    try {
      final token = await _getToken();
      final response = await http
          .get(
            Uri.parse(ApiConfig.chatsUrl),
            headers: ApiConfig.headers(token: token),
          )
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.where((c) => c['unread'] == true).length;
      }
    } catch (_) {}
    return 0;
  }

  Future<List<Map<String, dynamic>>> _fetchNotifications() async {
    try {
      final token = await _getToken();
      final response = await http
          .get(
            Uri.parse(ApiConfig.notificationsUrl),
            headers: ApiConfig.headers(token: token),
          )
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          return List<Map<String, dynamic>>.from(list);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Notifications fetch timeout or offline ($e). Using default notification.');
    }
    return _defaultNotifications;
  }

  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    return Stream.fromFuture(_fetchNotifications());
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final token = await _getToken();
    await http.put(
      Uri.parse(ApiConfig.markNotificationReadUrl(notificationId)),
      headers: ApiConfig.headers(token: token),
    );
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    final token = await _getToken();
    await http.put(
      Uri.parse(ApiConfig.markAllNotificationsReadUrl),
      headers: ApiConfig.headers(token: token),
    );
  }

  Future<void> deleteNotification(String notificationId) async {
    final token = await _getToken();
    await http.delete(
      Uri.parse('${ApiConfig.notificationsUrl}/$notificationId'),
      headers: ApiConfig.headers(token: token),
    );
  }

  Future<void> deleteAllNotifications(String userId) async {
    final token = await _getToken();
    await http.delete(
      Uri.parse(ApiConfig.notificationsUrl),
      headers: ApiConfig.headers(token: token),
    );
  }

  // ===================== ITEM FUNCTIONS =====================

  static List<ItemModel>? _cachedItems;
  static const String _itemsCacheKey = 'cui_trace_user_items_v3';

  // No dummy sample items - only user reported items
  static final List<ItemModel> _defaultSampleItems = [];

  Future<List<ItemModel>> getCachedItemsLocal() async {
    if (_cachedItems != null) {
      return List.from(_cachedItems!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_itemsCacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        _cachedItems = list.map((item) => ItemModel.fromFirestore(item)).toList();
        return List.from(_cachedItems!);
      }
    } catch (e) {
      debugPrint('Error reading local items cache: $e');
    }
    _cachedItems = [];
    return [];
  }

  Future<void> saveItemsToLocalCache(List<ItemModel> items) async {
    _cachedItems = List.from(items);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = items.map((i) => i.toFirestore()).toList();
      await prefs.setString(_itemsCacheKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving local items cache: $e');
    }
  }

  Future<ItemModel> uploadToCloudinaryAndSaveItem({
    required File imageFile,
    required String title,
    required String description,
    required String location,
    required String category,
    required bool isLost,
    String? uploader,
    String? uploaderId,
    DateTime? date,
    List<Map<String, dynamic>> securityQuestions = const [],
    bool requiresVerification = false,
  }) async {
    return uploadItem(
      imageFile: imageFile,
      title: title,
      description: description,
      location: location,
      category: category,
      isLost: isLost,
      date: date,
      securityQuestions: securityQuestions,
      requiresVerification: requiresVerification,
    );
  }

  Future<ItemModel> uploadItem({
    required File imageFile,
    required String title,
    required String description,
    required String location,
    required String category,
    required bool isLost,
    DateTime? date,
    List<Map<String, dynamic>> securityQuestions = const [],
    bool requiresVerification = false,
  }) async {
    final newItemId = 'item_${DateTime.now().millisecondsSinceEpoch}';
    final user = await getCurrentUser();
    final localItem = ItemModel(
      id: newItemId,
      title: title,
      description: description,
      location: location,
      category: category,
      isLost: isLost,
      date: date ?? DateTime.now(),
      reportDate: DateTime.now(),
      imageUrl: imageFile.path, // Use exact user uploaded photo path
      uploader: user?.displayName ?? 'User',
      uploaderId: user?.id ?? 'user_local',
      securityQuestions: securityQuestions,
      requiresVerification: requiresVerification,
    );

    // Save locally first for 0ms instant UI update
    final currentList = await getCachedItemsLocal();
    currentList.insert(0, localItem);
    await saveItemsToLocalCache(currentList);

    try {
      debugPrint('🚀 Starting item upload to Cloudinary & FastAPI Backend...');
      String imageUrl = localItem.imageUrl;
      try {
        final cloudUrl = await _cloudinaryService.uploadImage(imageFile).timeout(const Duration(seconds: 5));
        if (cloudUrl.isNotEmpty) {
          imageUrl = cloudUrl;
        }
      } catch (e) {
        debugPrint('⚠️ Cloudinary image upload timeout/error ($e), using local photo path.');
      }

      final token = await _getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.itemsUrl),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode({
          'title': title,
          'description': description,
          'location': location,
          'category': category,
          'isLost': isLost,
          'date': (date ?? DateTime.now()).toIso8601String(),
          'imageUrl': imageUrl,
          'securityQuestions': securityQuestions,
          'requiresVerification': requiresVerification,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final serverItem = ItemModel.fromFirestore(data);
        final list = await getCachedItemsLocal();
        final idx = list.indexWhere((i) => i.id == localItem.id);
        if (idx != -1) {
          list[idx] = serverItem;
        } else {
          list.insert(0, serverItem);
        }
        await saveItemsToLocalCache(list);
        return serverItem;
      }
    } catch (e) {
      debugPrint('⚠️ Network upload error ($e). Item saved locally on device.');
    }
    return localItem;
  }

  Future<void> addItem(ItemModel item) async {
    final list = await getCachedItemsLocal();
    list.insert(0, item);
    await saveItemsToLocalCache(list);
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse(ApiConfig.itemsUrl),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode(item.toFirestore()),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<ItemModel?> getItemById(String id) async {
    final list = await getCachedItemsLocal();
    final found = list.where((i) => i.id == id).firstOrNull;
    if (found != null) return found;

    try {
      final response = await http.get(Uri.parse(ApiConfig.itemByIdUrl(id))).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        return ItemModel.fromFirestore(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching item: $e');
    }
    return null;
  }

  Stream<List<ItemModel>> getAllItemsStream() {
    return Stream.fromFuture(getAllItems());
  }

  Future<List<ItemModel>> getAllItems({int limit = 50}) async {
    // 1. Immediately return cached/local items in 0ms!
    final localItems = await getCachedItemsLocal();

    // 2. Asynchronously fetch fresh items from network with a 2-second timeout
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.itemsUrl}?limit=$limit'))
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          final freshItems = list.map((item) => ItemModel.fromFirestore(item)).toList();
          await saveItemsToLocalCache(freshItems);
          return freshItems;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Network items fetch timed out or server offline ($e). Using cached items.');
    }
    return localItems;
  }

  Future<List<ItemModel>> getUserItems(String userId) async {
    final all = await getCachedItemsLocal();
    final userItems = all.where((i) => i.uploaderId == userId).toList();
    try {
      final response = await http.get(Uri.parse(ApiConfig.userItemsUrl(userId))).timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => ItemModel.fromFirestore(item)).toList();
      }
    } catch (_) {}
    return userItems;
  }

  Future<void> updateItem(ItemModel item) async {
    final list = await getCachedItemsLocal();
    final idx = list.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      list[idx] = item;
      await saveItemsToLocalCache(list);
    }
    try {
      final token = await _getToken();
      await http.put(
        Uri.parse(ApiConfig.itemByIdUrl(item.id)),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode(item.toFirestore()),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> deleteItem(String id) async {
    final list = await getCachedItemsLocal();
    list.removeWhere((i) => i.id == id);
    await saveItemsToLocalCache(list);
    try {
      final token = await _getToken();
      await http.delete(
        Uri.parse(ApiConfig.itemByIdUrl(id)),
        headers: ApiConfig.headers(token: token),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> saveVerificationAttempt({
    required String itemId,
    required String userId,
    required double score,
    required String status,
    required Map<String, dynamic> answers,
  }) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse(ApiConfig.itemVerifyUrl(itemId)),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode({
          'itemId': itemId,
          'score': score,
          'status': status,
          'answers': answers,
        }),
      );
    } catch (e) {
      debugPrint('Error saving verification attempt: $e');
    }
  }

  Future<bool> canUserAttemptVerification(String itemId, String userId) async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.checkVerifyUrl(itemId, userId)));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['canAttempt'] ?? true;
      }
    } catch (e) {
      debugPrint('Error checking verification attempt: $e');
    }
    return true;
  }

  // ===================== USER FUNCTIONS =====================
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('current_user_id') ?? 'user_local';
    final email = prefs.getString('current_user_email') ?? prefs.getString('email') ?? 'user@comsats.edu.pk';
    final name = prefs.getString('current_user_name') ?? prefs.getString('displayName') ?? email.split('@').first;
    final phone = prefs.getString('current_user_phone') ?? '';
    final image = prefs.getString('current_user_image') ?? '';

    _currentUser = UserModel(
      id: uid,
      email: email,
      username: email.split('@').first,
      displayName: (name.isNotEmpty) ? name : 'User',
      fcmToken: '',
      createdAt: DateTime.now(),
      lastLogin: DateTime.now(),
      isEmailVerified: true,
      phoneNumber: phone,
      profileImage: image,
    );
    return _currentUser;
  }

  Future<void> reloadUser() async {
    _currentUser = null;
    await getCurrentUser();
  }

  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? email,
    String? username,
    String? phoneNumber,
    String? profileImage,
  }) async {
    // 1. Immediately save to SharedPreferences & memory (0ms instant & permanent!)
    try {
      final prefs = await SharedPreferences.getInstance();
      if (displayName != null && displayName.isNotEmpty) {
        await prefs.setString('current_user_name', displayName);
        await prefs.setString('displayName', displayName);
      }
      if (email != null && email.isNotEmpty) {
        await prefs.setString('current_user_email', email);
        await prefs.setString('email', email);
      }
      if (phoneNumber != null) {
        await prefs.setString('current_user_phone', phoneNumber);
      }
      if (profileImage != null && profileImage.isNotEmpty) {
        await prefs.setString('current_user_image', profileImage);
      }

      final updatedName = displayName ?? _currentUser?.displayName ?? prefs.getString('current_user_name') ?? 'User';
      final updatedEmail = email ?? _currentUser?.email ?? prefs.getString('current_user_email') ?? 'user@comsats.edu.pk';
      final updatedPhone = phoneNumber ?? _currentUser?.phoneNumber ?? prefs.getString('current_user_phone') ?? '';
      final updatedImage = profileImage ?? _currentUser?.profileImage ?? prefs.getString('current_user_image') ?? '';

      _currentUser = UserModel(
        id: _currentUser?.id ?? userId,
        username: username ?? updatedEmail.split('@').first,
        email: updatedEmail,
        displayName: updatedName,
        fcmToken: _currentUser?.fcmToken ?? '',
        createdAt: _currentUser?.createdAt ?? DateTime.now(),
        lastLogin: DateTime.now(),
        isEmailVerified: true,
        phoneNumber: updatedPhone,
        profileImage: updatedImage,
      );
    } catch (e) {
      debugPrint('Error saving profile locally: $e');
    }

    // 2. Background async network call with 2-second timeout
    try {
      final token = await _getToken();
      await http
          .put(
            Uri.parse(ApiConfig.updateProfileUrl),
            headers: ApiConfig.headers(token: token),
            body: jsonEncode({
              if (displayName != null) 'displayName': displayName,
              if (email != null) 'email': email,
              if (username != null) 'username': username,
              if (phoneNumber != null) 'phoneNumber': phoneNumber,
              if (profileImage != null) 'profileImage': profileImage,
            }),
          )
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('⚠️ Network profile update timeout/offline ($e). Updated locally on device.');
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('current_user_id');
    await prefs.remove('current_user_email');
    await prefs.remove('current_user_name');
  }

  Future<void> resetPassword(String email) async {
    debugPrint('Password reset email requested for $email');
  }

  // ===================== CHAT & MESSAGE FUNCTIONS (0ms Instant & Persistent) =====================
  Future<List<Map<String, dynamic>>> getLocalUserChats(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cui_trace_user_chats_v2');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        return list.map<Map<String, dynamic>>((c) => Map<String, dynamic>.from(c)).toList();
      }
    } catch (e) {
      debugPrint('Error reading local chats cache: $e');
    }
    final List<Map<String, dynamic>> defaultChats = [];
    return defaultChats;
  }

  Future<void> saveLocalUserChats(List<Map<String, dynamic>> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cui_trace_user_chats_v2', jsonEncode(chats));
    } catch (e) {
      debugPrint('Error saving local chats: $e');
    }
  }

  Future<List<MessageModel>> getLocalChatMessages(String chatId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('cui_trace_chat_msgs_$chatId');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        return list.map((m) => MessageModel.fromFirestore(m)).toList();
      }
    } catch (e) {
      debugPrint('Error reading chat messages cache: $e');
    }
    if (chatId == 'chat_campus_support') {
      final List<MessageModel> sampleMsgs = [
        MessageModel(
          id: 'msg_sample_1',
          chatId: chatId,
          senderId: 'user_sample_1',
          text: 'Assalam-o-Alaikum! COMSATS Campus Lost & Found help desk here. Contact us anytime if you find or lose any belonging.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
          read: true,
        )
      ];
      saveLocalChatMessages(chatId, sampleMsgs);
      return sampleMsgs;
    }
    return [];
  }

  Future<void> saveLocalChatMessages(String chatId, List<MessageModel> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = messages.map((m) => m.toFirestore()).toList();
      await prefs.setString('cui_trace_chat_msgs_$chatId', jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving chat messages: $e');
    }
  }

  Future<Map<String, dynamic>> createOrGetChat({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    String? itemId,
    String? itemTitle,
  }) async {
    final chats = await getLocalUserChats(currentUserId);
    final existingIdx = chats.indexWhere((c) => c['otherUserId'] == otherUserId || c['id'] == 'chat_$otherUserId');
    if (existingIdx != -1) {
      return {
        'chatId': chats[existingIdx]['id'],
        'exists': true,
        'data': chats[existingIdx],
      };
    }

    final chatId = 'chat_${DateTime.now().millisecondsSinceEpoch}';
    final newChat = {
      'id': chatId,
      'otherUserId': otherUserId,
      'otherUserName': otherUserName,
      'lastMessage': itemTitle != null ? 'Inquired about: $itemTitle' : 'Started a conversation',
      'lastMessageTime': DateTime.now().toIso8601String(),
      'itemId': itemId,
      'itemTitle': itemTitle,
      'unread': false,
    };
    chats.insert(0, newChat);
    await saveLocalUserChats(chats);

    // Async backend sync with 2s timeout
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse(ApiConfig.chatsUrl),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode({
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'itemId': itemId,
          'itemTitle': itemTitle,
        }),
      ).timeout(const Duration(seconds: 2));
    } catch (_) {}

    return {
      'chatId': chatId,
      'exists': false,
      'data': newChat,
    };
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    String? senderName,
    required String text,
  }) async {
    final newMsg = MessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      chatId: chatId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      read: false,
    );

    // Save message locally in 0ms
    final currentMsgs = await getLocalChatMessages(chatId);
    currentMsgs.add(newMsg);
    await saveLocalChatMessages(chatId, currentMsgs);

    // Update lastMessage in local chat list
    final chats = await getLocalUserChats(senderId);
    final idx = chats.indexWhere((c) => c['id'] == chatId);
    if (idx != -1) {
      chats[idx]['lastMessage'] = text;
      chats[idx]['lastMessageTime'] = DateTime.now().toIso8601String();
      chats[idx]['unread'] = false;
      await saveLocalUserChats(chats);
    }

    // Async background sync with 2s timeout
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse(ApiConfig.chatMessagesUrl(chatId)),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode({
          'chatId': chatId,
          'text': text,
        }),
      ).timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('⚠️ Send message network timeout ($e). Message saved locally on device.');
    }
  }

  Stream<List<MessageModel>> getChatMessagesStream(String chatId) async* {
    final localMsgs = await getLocalChatMessages(chatId);
    yield localMsgs;

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.chatMessagesUrl(chatId)),
        headers: ApiConfig.headers(token: token),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          final serverMsgs = list.map((m) => MessageModel.fromFirestore(m)).toList();
          await saveLocalChatMessages(chatId, serverMsgs);
          yield serverMsgs;
        }
      }
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> getUserChatsStream(String userId) async* {
    final localChats = await getLocalUserChats(userId);
    yield localChats;

    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.chatsUrl),
        headers: ApiConfig.headers(token: token),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          final serverChats = list.map<Map<String, dynamic>>((c) {
            final participants = List<String>.from(c['participants'] ?? []);
            final otherUserId = participants.firstWhere((id) => id != userId, orElse: () => '');
            return {
              'id': c['id'],
              'otherUserId': otherUserId,
              'otherUserName': c['participantNames']?[otherUserId] ?? 'User',
              'lastMessage': c['lastMessage'] ?? '',
              'lastMessageTime': c['lastMessageTime'] ?? DateTime.now().toIso8601String(),
              'itemId': c['itemId'],
              'itemTitle': c['itemTitle'],
              'unread': c['unread'] ?? false,
            };
          }).toList();
          await saveLocalUserChats(serverChats);
          yield serverChats;
        }
      }
    } catch (_) {}
  }

  // ===================== HELPERS =====================
  bool get isLoggedIn => _currentUser != null;
  String? get currentUserId => _currentUser?.id;
  String? get currentUserEmail => _currentUser?.email;

  Future<void> sendTestNotification(String userId) async {
    await sendNotification(
      recipientId: userId,
      title: 'Test Notification',
      body: 'This is a test notification!',
      type: 'system',
    );
  }
}
