import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_score_model.dart';
import 'package:flutter/material.dart';

class GameService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection reference
  CollectionReference get _scores => _firestore.collection('game_scores');

  bool _isGameModeActive = false;
  int _currentScore = 0;
  int _highScore = 0;

  bool get isGameModeActive {
    print('[GameService] Game mode active: $_isGameModeActive');
    return _isGameModeActive;
  }
  int get currentScore => _currentScore;
  int get highScore => _highScore;

  // Get current user's game score
  Future<GameScoreModel?> getUserScore() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final doc = await _scores.doc(user.uid).get();
    if (!doc.exists) return null;

    return GameScoreModel.fromFirestore(doc);
  }

  // Update user's game score
  Future<void> updateScore(int score) async {
    if (!_isGameModeActive) return; // Don't update score if game mode is not active
    
    _currentScore = score;
    if (score > _highScore) {
      _highScore = score;
    }
    notifyListeners();

    final user = _auth.currentUser;
    if (user == null) return;

    final currentScore = await getUserScore();
    
    if (currentScore == null) {
      // First time playing
      await _scores.doc(user.uid).set(GameScoreModel(
        userId: user.uid,
        highScore: score,
        lastPlayed: DateTime.now(),
        gamesPlayed: 1,
      ).toMap());
    } else {
      // Update existing score
      await _scores.doc(user.uid).update({
        'highScore': score > currentScore.highScore ? score : currentScore.highScore,
        'lastPlayed': DateTime.now(),
        'gamesPlayed': currentScore.gamesPlayed + 1,
      });
    }
  }

  // Get user's high score
  Future<int> getHighScore() async {
    return _highScore;
  }

  // Get top scores
  Future<List<GameScoreModel>> getTopScores({int limit = 10}) async {
    final snapshot = await _scores
        .orderBy('highScore', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => GameScoreModel.fromFirestore(doc))
        .toList();
  }

  void toggleGameMode() {
    _isGameModeActive = !_isGameModeActive;
    if (!_isGameModeActive) {
      // Reset score when game mode is disabled
      _currentScore = 0;
    }
    print('Game mode toggled: $_isGameModeActive'); // Debug log
    notifyListeners();
  }
} 