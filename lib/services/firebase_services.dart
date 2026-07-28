// services/firebase_services.dart -
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/cloudinary_services.dart';
import '../models/item_model.dart';
import '../models/user_model.dart';

class FirebaseService {
  // Firebase instances
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ===================== REGISTRATION FUNCTIONS =====================
  // Register user WITHOUT email verification
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

      // Step 1: Create user in Firebase Auth
      print('1️⃣ Creating Firebase Auth user...');
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      print('✅ User created: ${user.uid}');
      print('📧 User email: ${user.email}');

      // Step 2: Update display name if provided
      if (displayName.isNotEmpty) {
        await user.updateDisplayName(displayName);
        print('✅ Display name updated: $displayName');
      }

      // Step 3: Wait for user to be fully initialized
      print('2️⃣ Initializing user...');
      await Future.delayed(Duration(seconds: 1));
      await user.reload();

      // Step 4: Get FCM token
      print('3️⃣ Getting FCM token...');
      String? fcmToken = '';
      try {
        fcmToken = await _messaging.getToken();
        print('✅ FCM Token: ${fcmToken.substring(0, 20)}...');
      } catch (e) {
        print('⚠️ FCM token error: $e');
        fcmToken = '';
      }

      // Step 5: Create UserModel
      print('4️⃣ Creating UserModel...');
      final userModel = UserModel(
        id: user.uid,
        username: username,
        email: email,
        displayName: displayName,
        fcmToken: fcmToken ?? '',
        createdAt: Timestamp.now(),
        lastLogin: Timestamp.now(),
        isEmailVerified: true, // Set to true since no verification needed
      );

      // Step 6: Save to Firestore
      print('5️⃣ Saving to Firestore...');
      await _db.collection('users').doc(userModel.id).set({
        'id': userModel.id,
        'username': userModel.username,
        'email': userModel.email,
        'displayName': userModel.displayName,
        'fcmToken': userModel.fcmToken,
        'isEmailVerified': true, // Set to true
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      print('✅ User saved to Firestore: ${userModel.id}');
      print('🎉 ======== REGISTRATION COMPLETE ========');

      return userModel;

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');

      String errorMsg;
      switch (e.code) {
        case 'email-already-in-use':
          errorMsg = 'This email is already registered. Please login.';
          break;
        case 'invalid-email':
          errorMsg = 'Invalid email address format.';
          break;
        case 'weak-password':
          errorMsg = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'operation-not-allowed':
          errorMsg = 'Email/password sign-up is not enabled.';
          break;
        case 'too-many-requests':
          errorMsg = 'Too many attempts. Please try again later.';
          break;
        default:
          errorMsg = 'Registration failed: ${e.message}';
      }

      throw Exception(errorMsg);
    } catch (e) {
      print('❌ General registration error: $e');
      throw Exception('Registration failed. Please try again.');
    }
  }

  // ===================== LOGIN FUNCTIONS =====================
  // Login WITHOUT email verification check
  Future<UserModel?> loginUser(String email, String password) async {
    try {
      print('🔐 ======== LOGIN ATTEMPT ========');
      print('📧 Email: $email');

      // Step 1: Sign in with email/password
      print('1️⃣ Signing in...');
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user!;
      print('✅ Firebase Auth login successful');
      print('👤 User UID: ${user.uid}');

      // Step 2: Reload to get latest data
      print('2️⃣ Reloading user data...');
      await user.reload();
      await Future.delayed(Duration(milliseconds: 500));

      // Step 3: Get FCM token
      print('3️⃣ Getting FCM token...');
      String? fcmToken;
      try {
        fcmToken = await _messaging.getToken();
        print('📱 FCM Token obtained');
      } catch (e) {
        print('⚠️ FCM token error: $e');
        fcmToken = '';
      }

      final userId = user.uid;
      final userRef = _db.collection('users').doc(userId);
      final userDoc = await userRef.get();

      UserModel userModel;

      if (!userDoc.exists) {
        print('📝 Creating new user document in Firestore');

        userModel = UserModel(
          id: userId,
          email: email,
          username: email.split('@').first,
          displayName: user.displayName ?? email.split('@').first,
          fcmToken: fcmToken ?? '',
          createdAt: Timestamp.now(),
          lastLogin: Timestamp.now(),
          isEmailVerified: true, // Set to true
        );

        await userRef.set(userModel.toFirestore());
      } else {
        print('📝 Updating existing user document');

        final updates = <String, dynamic>{
          'lastLogin': FieldValue.serverTimestamp(),
          'isEmailVerified': true, // Set to true
        };

        if (fcmToken != null && fcmToken.isNotEmpty) {
          updates['fcmToken'] = fcmToken;
        }

        await userRef.update(updates);
        userModel = UserModel.fromFirestore(await userRef.get());
      }

      print('✅ Login successful for user: ${userModel.id}');
      print('🎉 ======== LOGIN COMPLETE ========');

      return userModel;

    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth Error: ${e.code} - ${e.message}');

      String errorMsg;
      switch (e.code) {
        case 'user-not-found':
          errorMsg = 'No account found with this email.';
          break;
        case 'wrong-password':
          errorMsg = 'Incorrect password. Please try again.';
          break;
        case 'user-disabled':
          errorMsg = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          errorMsg = 'Too many attempts. Please try again later.';
          break;
        case 'invalid-credential':
          errorMsg = 'Invalid email or password.';
          break;
        default:
          errorMsg = 'Login failed: ${e.message}';
      }

      throw Exception(errorMsg);
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

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        print('✅ Google Sign-In successful: ${user.uid}');

        String? fcmToken;
        try {
          fcmToken = await _messaging.getToken();
        } catch (e) {
          fcmToken = '';
        }

        final userRef = _db.collection('users').doc(user.uid);
        final userDoc = await userRef.get();

        UserModel userModel;

        if (!userDoc.exists) {
          userModel = UserModel(
            id: user.uid,
            email: user.email ?? '',
            username: user.email?.split('@').first ?? 'user_${user.uid.substring(0, 8)}',
            displayName: user.displayName ?? user.email?.split('@').first ?? 'Google User',
            fcmToken: fcmToken ?? '',
            createdAt: Timestamp.now(),
            lastLogin: Timestamp.now(),
            isEmailVerified: true,
          );

          await userRef.set(userModel.toFirestore());
        } else {
          final updates = <String, dynamic>{
            'lastLogin': FieldValue.serverTimestamp(),
            'isEmailVerified': true,
          };

          if (fcmToken != null && fcmToken.isNotEmpty) {
            updates['fcmToken'] = fcmToken;
          }

          await userRef.update(updates);
          userModel = UserModel.fromFirestore(await userRef.get());
        }

        return userModel;
      }

      return null;
    } catch (e) {
      print("❌ Google Sign-In Error: $e");
      return null;
    }
  }

  // ===================== NOTIFICATION FUNCTIONS =====================
  // Initialize FCM
  Future<void> initializeFCM() async {
    try {
      // Request permission
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      print('📱 Notification permission: ${settings.authorizationStatus}');

      // Get token
      String? token = await _messaging.getToken();
      print('📱 FCM Token obtained');

      // Save token for current user
      if (_auth.currentUser != null && token != null) {
        await _db.collection('users').doc(_auth.currentUser!.uid).update({
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📨 Foreground message: ${message.notification?.title}');
        _saveNotificationToFirestore(message);
      });

      // Handle notification tap when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('👆 Notification tapped: ${message.data}');
      });

    } catch (e) {
      print('❌ FCM initialization error: $e');
    }
  }

  // Save notification to Firestore
  Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final data = message.data;
      final notification = message.notification;

      String? recipientId = data['recipientId']?.toString();
      if (recipientId == null || recipientId.isEmpty) {
        print('⚠️ No recipient ID found in notification');
        return;
      }

      await _db.collection('notifications').add({
        'recipientId': recipientId,
        'title': notification?.title ?? data['title'] ?? 'New Notification',
        'body': notification?.body ?? data['body'] ?? 'You have a new notification',
        'type': data['type'] ?? 'general',
        'data': data,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Notification saved for user: $recipientId');
    } catch (e) {
      print('❌ Error saving notification: $e');
    }
  }

  // Send notification
  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      print('📨 Sending notification to: $recipientId');

      await _db.collection('notifications').add({
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'type': type,
        'data': data ?? {},
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Notification sent');
    } catch (e) {
      print('❌ Error sending notification: $e');
    }
  }

  // Send new item notification to all users except uploader
  Future<void> sendNewItemNotification({
    required String itemId,
    required String itemTitle,
    required String uploaderName,
    required String uploaderId,
    required bool isLost,
  }) async {
    try {
      print('📨 Sending new item notification for: $itemId');

      // Get all users except the uploader
      final usersSnapshot = await _db.collection('users').get();

      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        if (userId != uploaderId) {
          await sendNotification(
            recipientId: userId,
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
      }

      print('✅ New item notifications sent');
    } catch (e) {
      print('❌ Error sending new item notification: $e');
    }
  }

  // Send chat message notification
  Future<void> sendNewMessageNotification({
    required String chatId,
    required String senderId,
    required String senderName,
    required String recipientId,
    required String message,
    String? itemId,
    String? itemTitle,
  }) async {
    try {
      print('💬 Sending message to: $recipientId');

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

      print('✅ Message notification sent');
    } catch (e) {
      print('❌ Error sending message notification: $e');
    }
  }

  // Send verification notification
  Future<void> sendVerificationNotification({
    required String itemId,
    required String itemTitle,
    required String verifierName,
    required String verifierId,
    required String uploaderId,
    required double score,
  }) async {
    try {
      print('✅ Sending verification for: $itemId');

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

      print('✅ Verification notification sent');
    } catch (e) {
      print('❌ Error sending verification notification: $e');
    }
  }

  // Get notification count for current user
  Future<int> getNotificationCount(String userId) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting notification count: $e');
      return 0;
    }
  }

  // Get unread messages count
  Future<int> getUnreadMessagesCount(String userId) async {
    try {
      final snapshot = await _db
          .collection('chats')
          .where('participants', arrayContains: userId)
          .where('unreadFor.$userId', isEqualTo: true)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting unread messages count: $e');
      return 0;
    }
  }

  // Get notifications stream for current user - FIXED QUERY
  Stream<List<Map<String, dynamic>>> getNotificationsStream(String userId) {
    try {
      // Temporary fix without orderBy
      return _db
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final notifications = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'title': data['title']?.toString() ?? '',
            'body': data['body']?.toString() ?? '',
            'type': data['type']?.toString() ?? 'general',
            'read': data['read'] ?? false,
            'data': data['data'] is Map ? Map<String, dynamic>.from(data['data']) : {},
            'createdAt': data['createdAt'] is Timestamp
                ? (data['createdAt'] as Timestamp).toDate()
                : DateTime.now(),
          };
        }).toList();

        // Sort manually
        notifications.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
        return notifications;
      });
    } catch (e) {
      print('❌ Error in notifications stream: $e');
      return const Stream.empty();
    }
  }

  // Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'read': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      final batch = _db.batch();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
        print('✅ Marked ${snapshot.docs.length} notifications as read');
      }
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
    }
  }

  // Delete notification
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).delete();
    } catch (e) {
      print('❌ Error deleting notification: $e');
    }
  }

  // Delete all notifications for user
  Future<void> deleteAllNotifications(String userId) async {
    try {
      final snapshot = await _db
          .collection('notifications')
          .where('recipientId', isEqualTo: userId)
          .get();

      final batch = _db.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      if (snapshot.docs.isNotEmpty) {
        await batch.commit();
        print('✅ Deleted ${snapshot.docs.length} notifications');
      }
    } catch (e) {
      print('❌ Error deleting all notifications: $e');
    }
  }

  // ===================== ITEM FUNCTIONS =====================

  // Get current user's info for item upload
  Future<Map<String, String>> _getCurrentUserInfo() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }

      final userDoc = await _db.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        return {
          'uploader': data['displayName']?.toString() ?? data['username']?.toString() ?? 'Anonymous',
          'uploaderId': user.uid,
        };
      }

      return {
        'uploader': user.displayName ?? user.email?.split('@').first ?? 'Anonymous',
        'uploaderId': user.uid,
      };
    } catch (e) {
      print('❌ Error getting current user info: $e');
      return {
        'uploader': 'Anonymous',
        'uploaderId': 'unknown',
      };
    }
  }

  // Upload item with image to Cloudinary and save to Firebase
  Future<ItemModel> uploadToCloudinaryAndSaveToFirebase({
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
    try {
      print('🚀 Starting item upload...');

      final userInfo = await _getCurrentUserInfo();
      final finalUploader = uploader ?? userInfo['uploader']!;
      final finalUploaderId = uploaderId ?? userInfo['uploaderId']!;

      print('👤 Uploader: $finalUploader');

      // 1. Upload image to Cloudinary
      print('📤 Uploading image...');
      final imageUrl = await _cloudinaryService.uploadImage(imageFile);
      print('✅ Image uploaded');

      // 2. Create ItemModel
      final item = ItemModel(
        id: _db.collection('items').doc().id,
        title: title,
        description: description,
        location: location,
        category: category,
        isLost: isLost,
        date: date ?? DateTime.now(),
        reportDate: DateTime.now(),
        uploader: finalUploader,
        uploaderId: finalUploaderId,
        imageUrl: imageUrl,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        securityQuestions: securityQuestions,
        requiresVerification: requiresVerification,
        isClaimed: false,
      );

      // 3. Save to Firestore
      print('💾 Saving to Firestore...');
      await _addItemToFirestore(item);
      print('✅ Item saved: ${item.id}');

      // 4. Send notification
      await sendNewItemNotification(
        itemId: item.id,
        itemTitle: item.title,
        uploaderName: finalUploader,
        uploaderId: finalUploaderId,
        isLost: isLost,
      );

      return item;
    } catch (e) {
      print('❌ Error uploading item: $e');
      rethrow;
    }
  }

  // Simplified upload item function
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
    return await uploadToCloudinaryAndSaveToFirebase(
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

  // Add item to Firestore
  Future<void> _addItemToFirestore(ItemModel item) async {
    try {
      await _db.collection('items').doc(item.id).set(item.toFirestore());
    } catch (e) {
      print('❌ Error adding item to Firestore: $e');
      rethrow;
    }
  }

  // Add item (public method)
  Future<void> addItem(ItemModel item) async {
    await _addItemToFirestore(item);
  }

  // Get item by ID
  Future<ItemModel?> getItemById(String id) async {
    try {
      final doc = await _db.collection('items').doc(id).get();
      if (doc.exists) {
        return ItemModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error getting item by ID: $e');
      return null;
    }
  }

  // Get all items stream
  Stream<List<ItemModel>> getAllItemsStream() {
    return _db
        .collection('items')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .toList();
    });
  }

  // Get all items (one-time)
  Future<List<ItemModel>> getAllItems({int limit = 50}) async {
    try {
      final snapshot = await _db
          .collection('items')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting all items: $e');
      return [];
    }
  }

  // Get user's items
  Future<List<ItemModel>> getUserItems(String userId) async {
    try {
      final snapshot = await _db
          .collection('items')
          .where('uploaderId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ItemModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error getting user items: $e');
      return [];
    }
  }

  // Update item
  Future<void> updateItem(ItemModel item) async {
    try {
      await _db.collection('items').doc(item.id).update({
        ...item.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Item updated: ${item.id}');
    } catch (e) {
      print('❌ Error updating item: $e');
      rethrow;
    }
  }

  // Delete item
  Future<void> deleteItem(String id) async {
    try {
      await _db.collection('items').doc(id).delete();
      print('✅ Item deleted: $id');
    } catch (e) {
      print('❌ Error deleting item: $e');
      rethrow;
    }
  }

  // Save verification attempt
  Future<void> saveVerificationAttempt({
    required String itemId,
    required String userId,
    required double score,
    required String status,
    required Map<String, dynamic> answers,
  }) async {
    try {
      await _db.collection('verificationAttempts').add({
        'itemId': itemId,
        'userId': userId,
        'score': score,
        'status': status,
        'answers': answers,
        'createdAt': FieldValue.serverTimestamp(),
      });
      print('✅ Verification attempt saved');
    } catch (e) {
      print('❌ Error saving verification attempt: $e');
      rethrow;
    }
  }

  // Check if user can attempt verification
  Future<bool> canUserAttemptVerification(String itemId, String userId) async {
    try {
      final snapshot = await _db
          .collection('verificationAttempts')
          .where('itemId', isEqualTo: itemId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      print('❌ Error checking verification attempt: $e');
      return true;
    }
  }

  // ===================== USER FUNCTIONS =====================

  // Get current user
  Future<UserModel?> getCurrentUser() async {
    try {
      await reloadUser();
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (doc.exists) {
          return UserModel.fromFirestore(doc);
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting current user: $e');
      return null;
    }
  }

  // Reload user
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? username,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (displayName != null) updates['displayName'] = displayName;
      if (username != null) updates['username'] = username;

      await _db.collection('users').doc(userId).update(updates);

      if (displayName != null) {
        await _auth.currentUser?.updateDisplayName(displayName);
      }

      print('✅ User profile updated: $userId');
    } catch (e) {
      print('❌ Error updating user profile: $e');
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
      print('✅ User logged out');
    } catch (e) {
      print('❌ Logout error: $e');
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ Password reset email sent to $email');
    } catch (e) {
      print('❌ Password reset error: $e');
      rethrow;
    }
  }

  // ===================== CHAT FUNCTIONS =====================

  // Create or get chat
  Future<Map<String, dynamic>> createOrGetChat({
    required String currentUserId,
    required String otherUserId,
    required String otherUserName,
    String? itemId,
    String? itemTitle,
  }) async {
    try {
      final query = await _db
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      for (final doc in query.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        if (participants.contains(otherUserId)) {
          print('✅ Existing chat found: ${doc.id}');
          return {
            'chatId': doc.id,
            'exists': true,
            'data': data,
          };
        }
      }

      final chatId = _db.collection('chats').doc().id;
      final currentUserName = await _getUserName(currentUserId);

      final chatData = {
        'id': chatId,
        'participants': [currentUserId, otherUserId],
        'participantNames': {
          currentUserId: currentUserName,
          otherUserId: otherUserName,
        },
        'itemId': itemId,
        'itemTitle': itemTitle,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadFor': {
          currentUserId: false,
          otherUserId: true,
        },
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('chats').doc(chatId).set(chatData);
      print('✅ New chat created: $chatId');

      return {
        'chatId': chatId,
        'exists': false,
        'data': chatData,
      };
    } catch (e) {
      print('❌ Error creating/getting chat: $e');
      rethrow;
    }
  }

  Future<String> _getUserName(String userId) async {
    try {
      final doc = await _db.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['displayName']?.toString() ?? data['username']?.toString() ?? 'User';
      }
      return 'User';
    } catch (e) {
      return 'User';
    }
  }

  // Send message
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String message,
  }) async {
    try {
      final messageId = _db.collection('chats').doc(chatId).collection('messages').doc().id;

      await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).set({
        'id': messageId,
        'senderId': senderId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      await _db.collection('chats').doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ Message sent: $messageId');
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  // Get chat messages stream
  Stream<List<Map<String, dynamic>>> getChatMessagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'senderId': data['senderId']?.toString() ?? '',
          'message': data['message']?.toString() ?? '',
          'timestamp': data['timestamp'] is Timestamp
              ? (data['timestamp'] as Timestamp).toDate()
              : DateTime.now(),
          'read': data['read'] ?? false,
        };
      }).toList();
    });
  }

  // Get user chats stream
  Stream<List<Map<String, dynamic>>> getUserChatsStream(String userId) {
    return _db
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere((id) => id != userId, orElse: () => '');

        return {
          'id': doc.id,
          'otherUserId': otherUserId,
          'otherUserName': data['participantNames']?[otherUserId]?.toString() ?? 'User',
          'lastMessage': data['lastMessage']?.toString() ?? '',
          'lastMessageTime': data['lastMessageTime'] is Timestamp
              ? (data['lastMessageTime'] as Timestamp).toDate()
              : DateTime.now(),
          'itemId': data['itemId'],
          'itemTitle': data['itemTitle'],
          'unread': data['unreadFor']?[userId] ?? false,
        };
      }).toList();
    });
  }

  // ===================== HELPERS =====================
  bool get isLoggedIn => _auth.currentUser != null;
  String? get currentUserId => _auth.currentUser?.uid;
  String? get currentUserEmail => _auth.currentUser?.email;
  User? get currentFirebaseUser => _auth.currentUser;

  // Test function
  Future<void> sendTestNotification(String userId) async {
    await sendNotification(
      recipientId: userId,
      title: 'Test Notification',
      body: 'This is a test notification!',
      type: 'system',
      data: {
        'test': true,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'message': 'System is working correctly!',
      },
    );
  }
}