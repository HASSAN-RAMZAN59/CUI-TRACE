// models/notification_model.dart

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String recipientId;
  final String recipientToken;
  final String? type;
  final Map<String, dynamic> data;
  final bool read;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.recipientId,
    required this.recipientToken,
    this.type,
    required this.data,
    required this.read,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'recipientId': recipientId,
      'recipientToken': recipientToken,
      'type': type,
      'data': data,
      'read': read,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NotificationModel.fromFirestore(dynamic doc) {
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

    return NotificationModel(
      id: docId.isNotEmpty ? docId : (data['id']?.toString() ?? ''),
      title: data['title']?.toString() ?? '',
      body: data['body']?.toString() ?? '',
      recipientId: data['recipientId']?.toString() ?? '',
      recipientToken: data['recipientToken']?.toString() ?? '',
      type: data['type']?.toString(),
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      read: data['read'] ?? false,
      createdAt: safeDate(data['createdAt']),
    );
  }
}