// models/chat_model.dart

class ChatModel {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final String lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCount;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ChatModel({
    required this.id,
    required this.participants,
    required this.participantNames,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'participants': participants,
      'participantNames': participantNames,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime.toIso8601String(),
      'unreadCount': unreadCount,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory ChatModel.fromFirestore(dynamic doc) {
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

    return ChatModel(
      id: docId.isNotEmpty ? docId : (data['id']?.toString() ?? ''),
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(data['participantNames'] ?? {}),
      lastMessage: data['lastMessage']?.toString() ?? '',
      lastMessageTime: safeDate(data['lastMessageTime']),
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      createdAt: safeDate(data['createdAt']),
      updatedAt: safeDate(data['updatedAt']),
    );
  }
}