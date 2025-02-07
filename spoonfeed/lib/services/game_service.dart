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
  int _lives = 3;
  bool _isGameInProgress = false;

  bool get isGameModeActive => _isGameModeActive;
  int get currentScore => _currentScore;
  int get highScore => _highScore;
  int get lives => _lives;

  // Reset lives
  void resetLives() {
    _lives = 3;
    notifyListeners();
  }

  // Decrease lives
  void decreaseLives() {
    if (_lives > 0) {
      _lives--;
      notifyListeners();

      // If no lives left, end the game
      if (_lives <= 0) {
        _endGame();
      }
    }
  }

  // Start a new game
  void startGame() {
    print('[GameService] Starting new game');
    _isGameInProgress = true;
    _currentScore = 0;
    _lives = 3;
    notifyListeners();
  }

  // End the current game and update stats
  Future<void> _endGame() async {
    print('[GameService] Ending game with score: $_currentScore');
    if (!_isGameInProgress) return; // Don't end if no game in progress
    
    _isGameInProgress = false;
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Update game statistics in Firestore
      await _scores.doc(user.uid).set({
        'userId': user.uid,
        'highScore': _currentScore > _highScore ? _currentScore : _highScore,
        'lastScore': _currentScore,
        'lastPlayed': FieldValue.serverTimestamp(),
        'gamesPlayed': FieldValue.increment(1),
        'totalScore': FieldValue.increment(_currentScore),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_currentScore > _highScore) {
        _highScore = _currentScore;
      }
      
      notifyListeners();
    } catch (e) {
      print('[GameService] Error updating game stats: $e');
    }
  }

  // Update current game score
  Future<void> updateScore(int score) async {
    if (!_isGameModeActive || !_isGameInProgress) return;
    
    print('[GameService] Updating score: $score');
    _currentScore = score;
    
    // Check if this is a new high score
    if (_currentScore > _highScore) {
      _highScore = _currentScore;
      
      // Update high score in Firestore
      final user = _auth.currentUser;
      if (user != null) {
        try {
          await _scores.doc(user.uid).set({
            'userId': user.uid,
            'highScore': _highScore,
            'lastScore': _currentScore,
            'lastPlayed': FieldValue.serverTimestamp(),
            'lastUpdated': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          print('[GameService] Error updating high score: $e');
        }
      }
    }
    
    notifyListeners();
  }

  // Get current user's game score
  Future<GameScoreModel?> getUserScore() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _scores.doc(user.uid).get();
      if (!doc.exists) {
        // Initialize user's game stats if they don't exist
        await _scores.doc(user.uid).set({
          'userId': user.uid,
          'highScore': 0,
          'lastScore': 0,
          'gamesPlayed': 0,
          'totalScore': 0,
          'lastPlayed': FieldValue.serverTimestamp(),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        return GameScoreModel(
          userId: user.uid,
          highScore: 0,
          gamesPlayed: 0,
          lastPlayed: DateTime.now(),
        );
      }
      return GameScoreModel.fromFirestore(doc);
    } catch (e) {
      print('[GameService] Error getting user score: $e');
      return null;
    }
  }

  void toggleGameMode() {
    _isGameModeActive = !_isGameModeActive;
    if (!_isGameModeActive && _isGameInProgress) {
      // End current game if game mode is disabled during gameplay
      _endGame();
    } else if (_isGameModeActive) {
      // Start new game when game mode is enabled
      startGame();
    }
    print('[GameService] Game mode toggled: $_isGameModeActive');
    notifyListeners();
  }

  // Get top scores
  Future<List<GameScoreModel>> getTopScores({int limit = 10}) async {
    try {
      final snapshot = await _scores
          .orderBy('highScore', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => GameScoreModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('[GameService] Error getting top scores: $e');
      return [];
    }
  }
} 