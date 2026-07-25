// models/item_model.dart

class ItemModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final String category;
  final bool isLost;
  final DateTime date;
  final DateTime reportDate;
  final String uploader;
  final String uploaderId;
  final String imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  final List<Map<String, dynamic>> securityQuestions;
  final bool requiresVerification;
  final bool isClaimed;
  final String? verifiedClaimerId;
  final DateTime? verificationDate;

  ItemModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.category,
    required this.isLost,
    required this.date,
    required this.reportDate,
    required this.uploader,
    required this.uploaderId,
    required this.imageUrl,
    this.createdAt,
    this.updatedAt,
    this.securityQuestions = const [],
    this.requiresVerification = false,
    this.isClaimed = false,
    this.verifiedClaimerId,
    this.verificationDate,
  });

  factory ItemModel.fromFirestore(dynamic doc) {
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

    String safeString(dynamic value) => value?.toString() ?? '';
    bool safeBool(dynamic value) {
      if (value is bool) return value;
      if (value is String) return value.toLowerCase() == 'true';
      if (value is int) return value == 1;
      return false;
    }

    DateTime safeDate(dynamic field) {
      if (field is DateTime) return field;
      if (field is String) return DateTime.tryParse(field) ?? DateTime.now();
      return DateTime.now();
    }

    List<Map<String, dynamic>> safeList(dynamic field) {
      if (field is List) {
        return field.whereType<Map<String, dynamic>>().toList();
      }
      return [];
    }

    return ItemModel(
      id: safeString(data['id'] ?? docId),
      title: safeString(data['title']),
      description: safeString(data['description']),
      location: safeString(data['location']),
      category: safeString(data['category']),
      isLost: safeBool(data['isLost']),
      date: safeDate(data['date']),
      reportDate: safeDate(data['reportDate']),
      uploader: safeString(data['uploader'] ?? data['uploaderName']),
      uploaderId: safeString(data['uploaderId']),
      imageUrl: safeString(data['imageUrl']),
      createdAt: safeDate(data['createdAt']),
      updatedAt: safeDate(data['updatedAt']),
      securityQuestions: safeList(data['securityQuestions']),
      requiresVerification: safeBool(data['requiresVerification']),
      isClaimed: safeBool(data['isClaimed']),
      verifiedClaimerId: safeString(data['verifiedClaimerId']),
      verificationDate: safeDate(data['verificationDate']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'category': category,
      'isLost': isLost,
      'date': date.toIso8601String(),
      'reportDate': reportDate.toIso8601String(),
      'uploader': uploader,
      'uploaderId': uploaderId,
      'imageUrl': imageUrl,
      'createdAt': (createdAt ?? DateTime.now()).toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'securityQuestions': securityQuestions,
      'requiresVerification': requiresVerification,
      'isClaimed': isClaimed,
      if (verifiedClaimerId != null && verifiedClaimerId!.isNotEmpty)
        'verifiedClaimerId': verifiedClaimerId,
      if (verificationDate != null)
        'verificationDate': verificationDate!.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() => toFirestore();
}