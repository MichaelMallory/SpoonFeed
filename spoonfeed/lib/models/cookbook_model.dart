import 'package:cloud_firestore/cloud_firestore.dart';

class CookbookModel {
  final String id;
  final String userId;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int videoCount;

  CookbookModel({
    required this.id,
    required this.userId,
    required this.name,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
    this.videoCount = 0,
  });

  factory CookbookModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CookbookModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      videoCount: data['videoCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'videoCount': videoCount,
    };
  }

  CookbookModel copyWith({
    String? id,
    String? userId,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? videoCount,
  }) {
    return CookbookModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      videoCount: videoCount ?? this.videoCount,
    );
  }
} 