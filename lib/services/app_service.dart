// services/app_service.dart
import 'dart:async';
import 'dart:io';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloudinary_services.dart';
import '../models/item_model.dart';
import '../models/user_model.dart';

class AppService {
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  static UserModel? _currentUser;
  static final List<ItemModel> _itemsStore = [];
  static final List<Map<String, dynamic>> _notificationsStore = [];
  static final List<Map<String, dynamic>> _chatsStore = [];
  static final Map<String, List<Map<String, dynamic>>> _messagesStore = {};
  static final List<Map<String, dynamic>> _verificationAttemptsStore = [];

  final _itemsStreamController = StreamController<List<ItemModel>>.broadcast();
  final _notificationsStreamController = StreamController<List<Map<String, dynamic>>>.broadcast();

  // ===================== REGISTRATION FUNCTIONS =====================
  Future<UserModel?> registerUser({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      print('🚀 ======== REGISTRATION START ========');
      print('📧 Email: $email');
      print('👤 Username: $username');

      final userId = DateTime.now().millisecondsSinceEpoch.toString();
      final userModel = UserModel(
        id: userId,
        username: username,
        email: email,
        displayName: displayName.isNotEmpty ? displayName : username,
        fcmToken: '',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        isEmailVerified: true,
      );

      _currentUser = userModel;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', userId);
      await prefs.setString('current_user_email', email);
      await prefs.setString('current_user_name', userModel.displayName);

      print('✅ User registered successfully: ${userModel.id}');
      return userModel;
    } catch (e) {
      print('❌ General registration error: $e');
      throw Exception('Registration failed. Please try again.');
    }
  }

  // ===================== LOGIN FUNCTIONS =====================
  Future<UserModel?> loginUser(String email, String password) async {
    try {
      print('🔐 ======== LOGIN ATTEMPT ========');
      print('📧 Email: $email');

      final userId = _currentUser?.id ?? DateTime.now().millisecondsSinceEpoch.toString();
      final userModel = UserModel(
        id: userId,
        email: email,
        username: email.split('@').first,
        displayName: _currentUser?.displayName ?? email.split('@').first,
        fcmToken: '',
        createdAt: _currentUser?.createdAt ?? DateTime.now(),
        lastLogin: DateTime.now(),
        isEmailVerified: true,
      );

      _currentUser = userModel;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', userId);
      await prefs.setString('current_user_email', email);
      await prefs.setString('current_user_name', userModel.displayName);

      print('✅ Login successful for user: ${userModel.id}');
      return userModel;
    } catch (e) {
      print('❌ General login error: $e');
      rethrow;
    }
  }

  // ===================== GOOGLE SIGN-IN =====================
  Future<UserModel?> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-In...');
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print('❌ Google Sign-In cancelled');
        return null;
      }

      final userId = googleUser.id;
      final userModel = UserModel(
        id: userId,
        email: googleUser.email,
        username: googleUser.email.split('@').first,
        displayName: googleUser.displayName ?? googleUser.email.split('@').first,
        fcmToken: '',
        createdAt: DateTime.now(),
        lastLogin: DateTime.now(),
        isEmailVerified: true,
      );

      _currentUser = userModel;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_user_id', userId);
      await prefs.setString('current_user_email', googleUser.email);
      await prefs.setString('current_user_name', userModel.displayName);

      print('✅ Google Sign-In successful: ${userModel.id}');
      return userModel;
    } catch (e) {
      print("❌ Google Sign-In Error: $e");
      return null;
    }
  }

  // ===================== NOTIFICATION FUNCTIONS =====================
  Future<void> initializeFCM() async {
    print('📱 Local notification service initialized');
  }

  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      final notif = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'read': false,
        'createdAt': DateTime.now(),
      };
      _notificationsStore.insert(0, notif);
      _notificationsStreamController.add(List.from(_notificationsStore));
      print('✅ Notification sent');
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
    return _notificationsStore
        .where((n) => (n['recipientId'] == userId || n['recipientId'] == 'all') && n['read'] == false)
        .length;
  }

  Future<int> getUnreadMessagesCount(String userId) async {
    return _chatsStore.where((c) => (c['participants'] as List).contains(userId) && c['unread'] == true).length;
  }

  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    final list = _notificationsStore
        .where((n) => n['recipientId'] == userId || n['recipientId'] == 'all')
        .toList();
    return Stream.value(list);
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final idx = _notificationsStore.indexWhere((n) => n['id'] == notificationId);
    if (idx != -1) {
      _notificationsStore[idx]['read'] = true;
    }
  }

  Future<void> markAllNotificationsAsRead(String userId) async {
    for (var n in _notificationsStore) {
      if (n['recipientId'] == userId || n['recipientId'] == 'all') {
        n['read'] = true;
      }
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    _notificationsStore.removeWhere((n) => n['id'] == notificationId);
  }

  Future<void> deleteAllNotifications(String userId) async {
    _notificationsStore.removeWhere((n) => n['recipientId'] == userId || n['recipientId'] == 'all');
  }

  // ===================== ITEM FUNCTIONS =====================

  Future<Map<String, String>> _getCurrentUserInfo() async {
    return {
      'uploader': _currentUser?.displayName ?? _currentUser?.username ?? 'Anonymous',
      'uploaderId': _currentUser?.id ?? 'guest_id',
    };
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
    try {
      print('🚀 Starting item upload...');
      final userInfo = await _getCurrentUserInfo();
      String imageUrl = '';
      try {
        imageUrl = await _cloudinaryService.uploadImage(imageFile);
      } catch (e) {
        print('⚠️ Cloudinary upload warning: $e');
        imageUrl = '';
      }

      final item = ItemModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        location: location,
        category: category,
        isLost: isLost,
        date: date ?? DateTime.now(),
        reportDate: DateTime.now(),
        uploader: userInfo['uploader']!,
        uploaderId: userInfo['uploaderId']!,
        imageUrl: imageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        securityQuestions: securityQuestions,
        requiresVerification: requiresVerification,
        isClaimed: false,
      );

      _itemsStore.insert(0, item);
      _itemsStreamController.add(List.from(_itemsStore));
      print('✅ Item saved: ${item.id}');

      await sendNewItemNotification(
        itemId: item.id,
        itemTitle: item.title,
        uploaderName: item.uploader,
        uploaderId: item.uploaderId,
        isLost: isLost,
      );

      return item;
    } catch (e) {
      print('❌ Error uploading item: $e');
      rethrow;
    }
  }

  Future<void> addItem(ItemModel item) async {
    _itemsStore.insert(0, item);
    _itemsStreamController.add(List.from(_itemsStore));
  }

  Future<ItemModel?> getItemById(String id) async {
    try {
      return _itemsStore.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  Stream<List<ItemModel>> getAllItemsStream() {
    return Stream.value(List.from(_itemsStore));
  }

  Future<List<ItemModel>> getAllItems({int limit = 50}) async {
    return List.from(_itemsStore.take(limit));
  }

  Future<List<ItemModel>> getUserItems(String userId) async {
    return _itemsStore.where((i) => i.uploaderId == userId).toList();
  }

  Future<void> updateItem(ItemModel item) async {
    final idx = _itemsStore.indexWhere((i) => i.id == item.id);
    if (idx != -1) {
      _itemsStore[idx] = item;
      _itemsStreamController.add(List.from(_itemsStore));
    }
  }

  Future<void> deleteItem(String id) async {
    _itemsStore.removeWhere((i) => i.id == id);
    _itemsStreamController.add(List.from(_itemsStore));
  }

  Future<void> saveVerificationAttempt({
    required String itemId,
    required String userId,
    required double score,
    required String status,
    required Map<String, dynamic> answers,
  }) async {
    _verificationAttemptsStore.add({
      'itemId': itemId,
      'userId': userId,
      'score': score,
      'status': status,
      'answers': answers,
      'createdAt': DateTime.now(),
    });
  }

  Future<bool> canUserAttemptVerification(String itemId, String userId) async {
    return !_verificationAttemptsStore.any(
      (v) => v['itemId'] == itemId && v['userId'] == userId,
    );
  }

  // ===================== USER FUNCTIONS =====================
  Future<UserModel?> getCurrentUser() async {
    if (_currentUser != null) return _currentUser;
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

  Future<void> reloadUser() async {}

  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? username,
  }) async {
    if (_currentUser != null) {
      _currentUser = UserModel(
        id: _currentUser!.id,
        email: _currentUser!.email,
        username: username ?? _currentUser!.username,
        displayName: displayName ?? _currentUser!.displayName,
        fcmToken: _currentUser!.fcmToken,
        createdAt: _currentUser!.createdAt,
        lastLogin: DateTime.now(),
        isEmailVerified: true,
      );
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
    await prefs.remove('current_user_email');
    await prefs.remove('current_user_name');
  }

  Future<void> resetPassword(String email) async {
    print('✅ Password reset email simulated for $email');
  }

  // ===================== CHAT FUNCTIONS =====================
  Future<Map<String, dynamic>> createOrGetChat({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    String? itemId,
    String? itemTitle,
  }) async {
    for (final chat in _chatsStore) {
      final participants = List<String>.from(chat['participants'] ?? []);
      if (participants.contains(currentUserId) && participants.contains(otherUserId)) {
        return {'chatId': chat['id'], 'exists': true, 'data': chat};
      }
    }

    final chatId = DateTime.now().millisecondsSinceEpoch.toString();
    final chatData = {
      'id': chatId,
      'participants': [currentUserId, otherUserId],
      'participantNames': {
        currentUserId: _currentUser?.displayName ?? 'Me',
        otherUserId: otherUserName,
      },
      'itemId': itemId,
      'itemTitle': itemTitle,
      'lastMessage': '',
      'lastMessageTime': DateTime.now(),
      'unread': false,
    };
    _chatsStore.add(chatData);
    _messagesStore[chatId] = [];
    return {'chatId': chatId, 'exists': false, 'data': chatData};
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String message,
  }) async {
    final msg = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'senderId': senderId,
      'message': message,
      'timestamp': DateTime.now(),
      'read': false,
    };
    _messagesStore.putIfAbsent(chatId, () => []).insert(0, msg);
    final idx = _chatsStore.indexWhere((c) => c['id'] == chatId);
    if (idx != -1) {
      _chatsStore[idx]['lastMessage'] = message;
      _chatsStore[idx]['lastMessageTime'] = DateTime.now();
    }
  }

  Stream<List<Map<String, dynamic>>> getChatMessagesStream(String chatId) {
    return Stream.value(_messagesStore[chatId] ?? []);
  }

  Stream<List<Map<String, dynamic>>> getUserChatsStream(String userId) {
    final list = _chatsStore
        .where((c) => (c['participants'] as List).contains(userId))
        .map((c) {
      final participants = List<String>.from(c['participants'] ?? []);
      final otherUserId = participants.firstWhere((id) => id != userId, orElse: () => '');
      return {
        'id': c['id'],
        'otherUserId': otherUserId,
        'otherUserName': c['participantNames']?[otherUserId] ?? 'User',
        'lastMessage': c['lastMessage'] ?? '',
        'lastMessageTime': c['lastMessageTime'] ?? DateTime.now(),
        'itemId': c['itemId'],
        'itemTitle': c['itemTitle'],
        'unread': c['unread'] ?? false,
      };
    }).toList();
    return Stream.value(list);
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
