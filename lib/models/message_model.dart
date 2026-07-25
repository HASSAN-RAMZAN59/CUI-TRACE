// models/message_model.dart

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final String? imageUrl;
  final String? itemId;
  final DateTime timestamp;
  final bool read;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.itemId,
    required this.timestamp,
    required this.read,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'itemId': itemId,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
    };
  }

  factory MessageModel.fromFirestore(dynamic doc) {
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

    return MessageModel(
      id: docId.isNotEmpty ? docId : (data['id']?.toString() ?? ''),
      chatId: data['chatId']?.toString() ?? '',
      senderId: data['senderId']?.toString() ?? '',
      text: data['text']?.toString() ?? '',
      imageUrl: data['imageUrl']?.toString(),
      itemId: data['itemId']?.toString(),
      timestamp: safeDate(data['timestamp']),
      read: data['read'] ?? false,
    );
  }
}