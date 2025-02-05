import 'package:cloud_firestore/cloud_firestore.dart';

class GameScoreModel {
  final String userId;
  final int highScore;
  final DateTime lastPlayed;
  final int gamesPlayed;

  GameScoreModel({
    required this.userId,
    required this.highScore,
    required this.lastPlayed,
    required this.gamesPlayed,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'highScore': highScore,
      'lastPlayed': lastPlayed,
      'gamesPlayed': gamesPlayed,
    };
  }

  factory GameScoreModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GameScoreModel(
      userId: data['userId'] as String,
      highScore: data['highScore'] as int,
      lastPlayed: (data['lastPlayed'] as Timestamp).toDate(),
      gamesPlayed: data['gamesPlayed'] as int,
    );
  }

  GameScoreModel copyWith({
    String? userId,
    int? highScore,
    DateTime? lastPlayed,
    int? gamesPlayed,
  }) {
    return GameScoreModel(
      userId: userId ?? this.userId,
      highScore: highScore ?? this.highScore,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    );
  }
} 