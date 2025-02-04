import 'package:cloud_firestore/cloud_firestore.dart';

class VideoModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final DateTime createdAt;
  final int likes;
  final int comments;
  final int shares;

  VideoModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.createdAt,
    required this.likes,
    required this.comments,
    required this.shares,
  });

  factory VideoModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      shares: data['shares'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'comments': comments,
      'shares': shares,
    };
  }

  VideoModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    DateTime? createdAt,
    int? likes,
    int? comments,
    int? shares,
  }) {
    return VideoModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
    );
  }
} 