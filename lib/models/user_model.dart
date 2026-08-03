// models/user_model.dart

class UserModel {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String fcmToken;
  final DateTime createdAt;
  final DateTime lastLogin;
  final bool isEmailVerified;
  final String phoneNumber;
  final String profileImage;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.fcmToken,
    required this.createdAt,
    required this.lastLogin,
    this.isEmailVerified = true,
    this.phoneNumber = '',
    this.profileImage = '',
  });

  factory UserModel.fromFirestore(dynamic doc) {
    Map<String, dynamic> data;
    String docId = '';
    if (doc is Map<String, dynamic>) {
      data = doc;
      docId = doc['id']?.toString() ?? '';
    } else {
      try {
        data = doc.data() as Map<String, dynamic>;
        docId = doc.id;
      } catch (_) {
        data = {};
      }
    }

    DateTime safeDate(dynamic field) {
      if (field is DateTime) return field;
      if (field is String) return DateTime.tryParse(field) ?? DateTime.now();
      return DateTime.now();
    }

    return UserModel(
      id: docId.isNotEmpty ? docId : (data['id']?.toString() ?? ''),
      username: data['username']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      displayName: data['displayName']?.toString() ?? '',
      fcmToken: data['fcmToken']?.toString() ?? '',
      createdAt: safeDate(data['createdAt']),
      lastLogin: safeDate(data['lastLogin']),
      isEmailVerified: true,
      phoneNumber: data['phoneNumber']?.toString() ?? data['phone']?.toString() ?? '',
      profileImage: data['profileImage']?.toString() ?? data['imageUrl']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'displayName': displayName,
      'fcmToken': fcmToken,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin.toIso8601String(),
      'isEmailVerified': true,
      'phoneNumber': phoneNumber,
      'profileImage': profileImage,
    };
  }

  Map<String, dynamic> toMap() => toFirestore();
}