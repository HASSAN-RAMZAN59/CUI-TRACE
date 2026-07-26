// utils/constants.dart - UPDATED
class AppConstants {
  static const String appName = 'CUI Trace';
  static const String appVersion = '1.0.0';

  // App Collections
  static const String usersCollection = 'users';
  static const String itemsCollection = 'items';
  static const String chatsCollection = 'chats';
  static const String notificationsCollection = 'notifications';

  // App Storage Keys
  static const String isLoggedInKey = 'isLoggedIn';
  static const String userIdKey = 'userId';
  static const String emailKey = 'email';
  static const String usernameKey = 'username';
  static const String displayNameKey = 'displayName';
  static const String savedEmailKey = 'savedEmail';

  // Item Categories
  static const List<String> itemCategories = [
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

  // Location Categories (optional)
  static const List<String> locationCategories = [
    'Library',
    'Classroom',
    'Cafeteria',
    'Sports Complex',
    'Hostel',
    'Parking',
    'Admin Block',
    'Other'
  ];

  // Cloudinary Configuration
  static const String cloudinaryCloudName = 'djwzc1hrq';
  static const String cloudinaryUploadPreset = 'image_present';
}