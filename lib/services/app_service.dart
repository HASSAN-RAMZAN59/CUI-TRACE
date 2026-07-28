// services/app_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
      print('🚀 ======== REGISTRATION START (FastAPI & Atlas) ========');
      print('📧 Email: $email');
      print('👤 Username: $username');
      print('🌐 Target URL: ${ApiConfig.signupUrl}');

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

      print('📥 Response status: ${response.statusCode}');

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

        print('✅ User registered successfully in MongoDB Atlas: ${userModel.id}');
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
        print('❌ Signup failed: $detail');
        throw Exception(detail);
      }
    } on SocketException catch (e) {
      print('❌ Network error during signup: $e');
      throw Exception('Cannot connect to FastAPI server at ${ApiConfig.baseUrl}. Please check if the backend server is running.');
    } on TimeoutException catch (e) {
      print('❌ Timeout error during signup: $e');
      throw Exception('Server connection timed out. Please check your network or backend server.');
    } catch (e) {
      print('❌ General registration error: $e');
      rethrow;
    }
  }

  // ===================== LOGIN FUNCTIONS =====================
  Future<UserModel?> loginUser(String email, String password) async {
    try {
      print('🔐 ======== LOGIN ATTEMPT (FastAPI & Atlas) ========');
      print('📧 Email: $email');
      print('🌐 Target URL: ${ApiConfig.loginUrl}');

      final response = await http.post(
        Uri.parse(ApiConfig.loginUrl),
        headers: ApiConfig.headers(),
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📥 Response status: ${response.statusCode}');

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

        print('✅ Login successful for user: ${userModel.id}');
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
        print('❌ Login failed: $detail');
        throw Exception(detail);
      }
    } on SocketException catch (e) {
      print('❌ Network error during login: $e');
      throw Exception('Cannot connect to FastAPI server at ${ApiConfig.baseUrl}. Please check if the backend server is running.');
    } on TimeoutException catch (e) {
      print('❌ Timeout error during login: $e');
      throw Exception('Server connection timed out. Please check your network or backend server.');
    } catch (e) {
      print('❌ General login error: $e');
      rethrow;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    return null;
  }

  // ===================== NOTIFICATION FUNCTIONS =====================
  Future<void> initializeFCM() async {
    print('📱 Notification service initialized');
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
      print('❌ Error sending notification: $e');
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

  Future<int> getNotificationCount(String userId) async {
    try {
      final notifs = await _fetchNotifications();
      return notifs.where((n) => n['read'] == false).length;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getUnreadMessagesCount(String userId) async {
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.chatsUrl),
        headers: ApiConfig.headers(token: token),
      );
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.where((c) => c['unread'] == true).length;
      }
    } catch (_) {}
    return 0;
  }

  Future<List<Map<String, dynamic>>> _fetchNotifications() async {
    final token = await _getToken();
    final response = await http.get(
      Uri.parse(ApiConfig.notificationsUrl),
      headers: ApiConfig.headers(token: token),
    );
    if (response.statusCode == 200) {
      final List list = jsonDecode(response.body);
      return List<Map<String, dynamic>>.from(list);
    }
    return [];
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
    try {
      print('🚀 Starting item upload to Cloudinary & FastAPI Backend...');
      String imageUrl = '';
      try {
        imageUrl = await _cloudinaryService.uploadImage(imageFile);
      } catch (e) {
        print('❌ Cloudinary image upload failed: $e');
        rethrow;
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
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final item = ItemModel.fromFirestore(data);
        print('✅ Item saved in MongoDB Atlas: ${item.id}');

        await sendNewItemNotification(
          itemId: item.id,
          itemTitle: item.title,
          uploaderName: item.uploader,
          uploaderId: item.uploaderId,
          isLost: isLost,
        );

        return item;
      } else {
        throw Exception('Failed to save item: ${response.body}');
      }
    } catch (e) {
      print('❌ Error uploading item: $e');
      rethrow;
    }
  }

  Future<void> addItem(ItemModel item) async {
    final token = await _getToken();
    await http.post(
      Uri.parse(ApiConfig.itemsUrl),
      headers: ApiConfig.headers(token: token),
      body: jsonEncode(item.toFirestore()),
    );
  }

  Future<ItemModel?> getItemById(String id) async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.itemByIdUrl(id)));
      if (response.statusCode == 200) {
        return ItemModel.fromFirestore(jsonDecode(response.body));
      }
    } catch (e) {
      print('Error fetching item: $e');
    }
    return null;
  }

  Stream<List<ItemModel>> getAllItemsStream() {
    return Stream.fromFuture(getAllItems());
  }

  Future<List<ItemModel>> getAllItems({int limit = 50}) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.itemsUrl}?limit=$limit'));
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => ItemModel.fromFirestore(item)).toList();
      }
    } catch (e) {
      print('Error fetching all items: $e');
    }
    return [];
  }

  Future<List<ItemModel>> getUserItems(String userId) async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.userItemsUrl(userId)));
      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        return list.map((item) => ItemModel.fromFirestore(item)).toList();
      }
    } catch (e) {
      print('Error fetching user items: $e');
    }
    return [];
  }

  Future<void> updateItem(ItemModel item) async {
    try {
      final token = await _getToken();
      await http.put(
        Uri.parse(ApiConfig.itemByIdUrl(item.id)),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode(item.toFirestore()),
      );
    } catch (e) {
      print('Error updating item: $e');
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      final token = await _getToken();
      await http.delete(
        Uri.parse(ApiConfig.itemByIdUrl(id)),
        headers: ApiConfig.headers(token: token),
      );
    } catch (e) {
      print('Error deleting item: $e');
    }
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
      print('Error saving verification attempt: $e');
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
      print('Error checking verification attempt: $e');
    }
    return true;
  }

  // ===================== USER FUNCTIONS =====================
  Future<UserModel?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
    final token = await _getToken();
    if (token == null || token.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.meUrl),
        headers: ApiConfig.headers(token: token),
      );
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        _currentUser = UserModel(
          id: userData['id'],
          username: userData['username'],
          email: userData['email'],
          displayName: userData['displayName'],
          fcmToken: '',
          createdAt: DateTime.tryParse(userData['createdAt'] ?? '') ?? DateTime.now(),
          lastLogin: DateTime.now(),
          isEmailVerified: true,
        );
        return _currentUser;
      }
    } catch (e) {
      print('Error fetching current user: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString('current_user_id');
    final email = prefs.getString('current_user_email');
    final name = prefs.getString('current_user_name');
    if (uid != null && email != null) {
      _currentUser = UserModel(
        id: uid,
        email: email,
        username: email.split('@').first,
        displayName: name ?? email.split('@').first,
        fcmToken: '',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        isEmailVerified: true,
      );
    }
    return _currentUser;
  }

  Future<void> reloadUser() async {
    _currentUser = null;
    await getCurrentUser();
  }

  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? username,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.put(
        Uri.parse(ApiConfig.updateProfileUrl),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode({
          if (displayName != null) 'displayName': displayName,
          if (username != null) 'username': username,
        }),
      );
      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body);
        _currentUser = UserModel(
          id: userData['id'],
          username: userData['username'],
          email: userData['email'],
          displayName: userData['displayName'],
          fcmToken: '',
          createdAt: DateTime.tryParse(userData['createdAt'] ?? '') ?? DateTime.now(),
          lastLogin: DateTime.now(),
          isEmailVerified: true,
        );
      }
    } catch (e) {
      print('Error updating user profile: $e');
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
    print('Password reset email requested for $email');
  }

  // ===================== CHAT FUNCTIONS =====================
  Future<Map<String, dynamic>> createOrGetChat({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    String? itemId,
    String? itemTitle,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse(ApiConfig.chatsUrl),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode({
          'otherUserId': otherUserId,
          'otherUserName': otherUserName,
          'itemId': itemId,
          'itemTitle': itemTitle,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final chatData = jsonDecode(response.body);
        return {
          'chatId': chatData['id'],
          'exists': true,
          'data': chatData,
        };
      }
    } catch (e) {
      print('Error in createOrGetChat: $e');
    }

    final chatId = DateTime.now().millisecondsSinceEpoch.toString();
    return {
      'chatId': chatId,
      'exists': false,
      'data': {
        'id': chatId,
        'participants': [currentUserId, otherUserId],
        'participantNames': {currentUserId: _currentUser?.displayName ?? 'Me', otherUserId: otherUserName},
        'itemId': itemId,
        'itemTitle': itemTitle,
        'lastMessage': '',
        'lastMessageTime': DateTime.now(),
        'unread': false,
      }
    };
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    String? senderName,
    required String text,
  }) async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse(ApiConfig.chatMessagesUrl(chatId)),
        headers: ApiConfig.headers(token: token),
        body: jsonEncode({
          'chatId': chatId,
          'text': text,
        }),
      );
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Stream<List<MessageModel>> getChatMessagesStream(String chatId) {
    Future<List<MessageModel>> fetchMessages() async {
      try {
        final token = await _getToken();
        final response = await http.get(
          Uri.parse(ApiConfig.chatMessagesUrl(chatId)),
          headers: ApiConfig.headers(token: token),
        );
        if (response.statusCode == 200) {
          final List list = jsonDecode(response.body);
          return list.map((m) => MessageModel.fromFirestore(m)).toList();
        }
      } catch (e) {
        print('Error fetching chat messages: $e');
      }
      return [];
    }

    return Stream.fromFuture(fetchMessages());
  }

  Stream<List<Map<String, dynamic>>> getUserChatsStream(String userId) {
    Future<List<Map<String, dynamic>>> fetchUserChats() async {
      try {
        final token = await _getToken();
        final response = await http.get(
          Uri.parse(ApiConfig.chatsUrl),
          headers: ApiConfig.headers(token: token),
        );
        if (response.statusCode == 200) {
          final List list = jsonDecode(response.body);
          return list.map<Map<String, dynamic>>((c) {
            final participants = List<String>.from(c['participants'] ?? []);
            final otherUserId = participants.firstWhere((id) => id != userId, orElse: () => '');
            return {
              'id': c['id'],
              'otherUserId': otherUserId,
              'otherUserName': c['participantNames']?[otherUserId] ?? 'User',
              'lastMessage': c['lastMessage'] ?? '',
              'lastMessageTime': DateTime.tryParse(c['lastMessageTime'] ?? '') ?? DateTime.now(),
              'itemId': c['itemId'],
              'itemTitle': c['itemTitle'],
              'unread': c['unread'] ?? false,
            };
          }).toList();
        }
      } catch (e) {
        print('Error fetching user chats: $e');
      }
      return [];
    }

    return Stream.fromFuture(fetchUserChats());
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
