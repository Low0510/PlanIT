import 'package:cloud_firestore/cloud_firestore.dart';

class TaskFile {
  final String id;
  final String name;
  final String url;
  final String type;
  final DateTime uploadedAt;

  TaskFile({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.uploadedAt,
  });

  // Convert TaskFile to a Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'type': type,
      'uploadedAt': Timestamp.fromDate(uploadedAt), 
    };
  }

  factory TaskFile.fromMap(Map<String, dynamic> map) {
    final uploadedAtRaw = map['uploadedAt'];

    return TaskFile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      url: map['url'] ?? '',
      type: map['type'] ?? '',
      uploadedAt: uploadedAtRaw is Timestamp
          ? uploadedAtRaw.toDate()
          : DateTime.parse(uploadedAtRaw), 
    );
  }
}
