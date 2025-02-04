import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeModel {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String videoUrl;
  final String thumbnailUrl;
  final List<String> ingredients;
  final List<String> steps;
  final List<String> tags;
  final Map<String, dynamic> metadata;
  final int duration; // in seconds
  final int likes;
  final int comments;
  final int shares;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecipeModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.ingredients,
    required this.steps,
    this.tags = const [],
    this.metadata = const {},
    required this.duration,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecipeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecipeModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      ingredients: List<String>.from(data['ingredients'] ?? []),
      steps: List<String>.from(data['steps'] ?? []),
      tags: List<String>.from(data['tags'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      duration: data['duration'] ?? 0,
      likes: data['likes'] ?? 0,
      comments: data['comments'] ?? 0,
      shares: data['shares'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'ingredients': ingredients,
      'steps': steps,
      'tags': tags,
      'metadata': metadata,
      'duration': duration,
      'likes': likes,
      'comments': comments,
      'shares': shares,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  RecipeModel copyWith({
    String? title,
    String? description,
    String? videoUrl,
    String? thumbnailUrl,
    List<String>? ingredients,
    List<String>? steps,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    int? duration,
    int? likes,
    int? comments,
    int? shares,
  }) {
    return RecipeModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      videoUrl: videoUrl ?? this.videoUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      duration: duration ?? this.duration,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      shares: shares ?? this.shares,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
} 