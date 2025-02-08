import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String id;
  final String videoId;
  final String userId;
  final String userDisplayName;
  final String userPhotoUrl;
  final String text;
  final DateTime createdAt;
  final int likes;
  final List<String> likedBy;
  final List<CommentModel> replies;
  final int? gameScore;
  final bool wasPinned;
  final bool isPinned;

  const CommentModel({
    required this.id,
    required this.videoId,
    required this.userId,
    required this.userDisplayName,
    required this.userPhotoUrl,
    required this.text,
    required this.createdAt,
    this.likes = 0,
    this.likedBy = const [],
    this.replies = const [],
    this.gameScore,
    this.wasPinned = false,
    this.isPinned = false,
  });

  factory CommentModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CommentModel(
      id: doc.id,
      videoId: data['videoId'] ?? '',
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      replies: (data['replies'] as List<dynamic>? ?? [])
          .map((reply) => CommentModel.fromMap(reply as Map<String, dynamic>))
          .toList(),
      gameScore: data['gameScore'],
      wasPinned: data['wasPinned'] ?? false,
      isPinned: data['isPinned'] ?? false,
    );
  }

  factory CommentModel.fromMap(Map<String, dynamic> data) {
    return CommentModel(
      id: data['id'] ?? '',
      videoId: data['videoId'] ?? '',
      userId: data['userId'] ?? '',
      userDisplayName: data['userDisplayName'] ?? '',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      text: data['text'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      likes: data['likes'] ?? 0,
      likedBy: List<String>.from(data['likedBy'] ?? []),
      replies: (data['replies'] as List<dynamic>? ?? [])
          .map((reply) => CommentModel.fromMap(reply as Map<String, dynamic>))
          .toList(),
      gameScore: data['gameScore'],
      wasPinned: data['wasPinned'] ?? false,
      isPinned: data['isPinned'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'videoId': videoId,
      'userId': userId,
      'userDisplayName': userDisplayName,
      'userPhotoUrl': userPhotoUrl,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'likes': likes,
      'likedBy': likedBy,
      'replies': replies.map((reply) => reply.toMap()).toList(),
      'gameScore': gameScore,
      'wasPinned': wasPinned,
      'isPinned': isPinned,
    };
  }

  CommentModel copyWith({
    String? id,
    String? videoId,
    String? userId,
    String? userDisplayName,
    String? userPhotoUrl,
    String? text,
    DateTime? createdAt,
    int? likes,
    List<String>? likedBy,
    List<CommentModel>? replies,
    int? gameScore,
    bool? wasPinned,
    bool? isPinned,
  }) {
    return CommentModel(
      id: id ?? this.id,
      videoId: videoId ?? this.videoId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      likedBy: likedBy ?? this.likedBy,
      replies: replies ?? this.replies,
      gameScore: gameScore ?? this.gameScore,
      wasPinned: wasPinned ?? this.wasPinned,
      isPinned: isPinned ?? this.isPinned,
    );
  }
} 