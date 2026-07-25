import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import './app_service.dart';

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final AppService _appService = AppService();

  Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _handleTap(response.payload);
      },
    );
  }

  void _handleTap(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      if (data['type'] == 'chat') {
        print('➡️ Open chat ${data['chatId']}');
      } else if (data['type'] == 'item') {
        print('➡️ Open item ${data['itemId']}');
      }
    } catch (_) {}
  }

  Stream<List<Map<String, dynamic>>> getUserNotificationsStream() {
    final userId = _appService.currentUserId ?? 'guest';
    return _appService.getNotificationsStream(userId);
  }

  Stream<int> getUnreadCount() {
    final userId = _appService.currentUserId ?? 'guest';
    return Stream.fromFuture(_appService.getNotificationCount(userId));
  }

  Future<void> markAsRead(String id) async {
    await _appService.markNotificationAsRead(id);
  }

  Future<void> markAllAsRead() async {
    final userId = _appService.currentUserId ?? 'guest';
    await _appService.markAllNotificationsAsRead(userId);
  }

  Future<void> deleteNotification(String id) async {
    await _appService.deleteNotification(id);
  }

  Future<void> deleteAll() async {
    final userId = _appService.currentUserId ?? 'guest';
    await _appService.deleteAllNotifications(userId);
  }
}
