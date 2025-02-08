import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/game_score_model.dart';
import '../models/video_model.dart';
import '../models/comment_model.dart';
import 'package:flutter/material.dart';

class GameService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _scores => _firestore.collection('game_scores');
  CollectionReference get _videos => _firestore.collection('videos');
  CollectionReference _commentsRef(String videoId) => _videos.doc(videoId).collection('comments');

  bool _isGameModeActive = false;
  int _currentScore = 0;
  int _highScore = 0;
  int _lives = 3;
  bool _isGameInProgress = false;
  
  // Video context tracking
  String? _currentVideoId;
  int? _currentVideoHighScore;
  VideoModel? _currentVideo;

  bool get isGameModeActive => _isGameModeActive;
  int get currentScore => _currentScore;
  int get highScore => _highScore;
  int get lives => _lives;
  String? get currentVideoId => _currentVideoId;
  int? get currentVideoHighScore => _currentVideoHighScore;
  VideoModel? get currentVideo => _currentVideo;

  // Update current video context
  Future<void> setCurrentVideo(VideoModel video) async {
    _currentVideoId = video.id;
    _currentVideo = video;
    _currentVideoHighScore = video.highestGameScore;
    notifyListeners();
  }

  // Create a new pinned comment
  Future<CommentModel?> createPinnedComment(String text) async {
    final user = _auth.currentUser;
    final videoId = _currentVideoId;
    if (user == null || videoId == null) {
      throw Exception('User must be logged in and video must be selected');
    }

    try {
      // Start a transaction to ensure data consistency
      CommentModel? newComment;
      await _firestore.runTransaction((transaction) async {
        // Get the video document
        final videoRef = _videos.doc(videoId);
        final videoDoc = await transaction.get(videoRef);
        
        if (!videoDoc.exists) {
          throw Exception('Video document not found');
        }
        
        final data = videoDoc.data() as Map<String, dynamic>;
        
        // Verify the score is still higher than the current high score
        final currentHighScore = data['highestGameScore'] ?? 0;
        if (_currentScore <= currentHighScore) {
          throw Exception('Score is no longer higher than current high score');
        }
        
        // Get the current pinned comment if it exists
        final currentPinnedCommentId = data['pinnedCommentId'];
        if (currentPinnedCommentId != null) {
          // Unpin the previous comment
          final previousCommentRef = _commentsRef(videoId).doc(currentPinnedCommentId);
          final previousCommentDoc = await transaction.get(previousCommentRef);
          
          if (previousCommentDoc.exists) {
            transaction.update(previousCommentRef, {
              'isPinned': false,
              'wasPinned': true,
            });
          }
        }

        // Create the new comment
        final commentRef = _commentsRef(videoId).doc();
        final now = DateTime.now();
        final comment = CommentModel(
          id: commentRef.id,
          videoId: videoId,
          userId: user.uid,
          userDisplayName: user.displayName ?? 'User',
          userPhotoUrl: user.photoURL ?? '',
          text: text,
          createdAt: now,
          gameScore: _currentScore,
          wasPinned: false,
          isPinned: true,
        );

        // Set the new comment
        transaction.set(commentRef, comment.toMap());

        // Update the video with the new pinned comment ID and ensure high score is set
        transaction.update(videoRef, {
          'pinnedCommentId': commentRef.id,
          'highestGameScore': _currentScore,
          'comments': FieldValue.increment(1), // Increment comment count
        });

        newComment = comment;
      });

      // Update local state if successful
      if (newComment != null) {
        _currentVideoHighScore = _currentScore;
        if (_currentVideo != null) {
          _currentVideo = _currentVideo!.copyWith(
            highestGameScore: _currentScore,
            pinnedCommentId: newComment?.id,
          );
        }
        notifyListeners();
        return newComment;
      } else {
        throw Exception('Failed to create comment in transaction');
      }
    } catch (e) {
      print('[GameService] Error creating pinned comment: $e');
      if (e.toString().contains('permission-denied')) {
        print('[GameService] Permission denied error - user may need to authenticate');
        rethrow;
      }
      throw Exception('Failed to create comment: ${e.toString()}');
    }
  }

  // Unpin a comment
  Future<bool> unpinComment(String videoId, CommentModel comment) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final commentRef = _commentsRef(videoId).doc(comment.id);
        final videoRef = _videos.doc(videoId);
        
        final commentDoc = await transaction.get(commentRef);
        final videoDoc = await transaction.get(videoRef);
        
        if (!commentDoc.exists || !videoDoc.exists) return;
        
        final data = videoDoc.data() as Map<String, dynamic>;
        
        // Only unpin if this is still the pinned comment
        if (data['pinnedCommentId'] == comment.id) {
          transaction.update(videoRef, {
            'pinnedCommentId': null,
          });
        }
        
        transaction.update(commentRef, {
          'isPinned': false,
          'wasPinned': true,
        });
      });
      
      return true;
    } catch (e) {
      print('[GameService] Error unpinning comment: $e');
      return false;
    }
  }

  // Delete a comment
  Future<bool> deleteComment(String videoId, CommentModel comment) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final commentRef = _commentsRef(videoId).doc(comment.id);
        final videoRef = _videos.doc(videoId);
        
        // Delete the comment
        transaction.delete(commentRef);
        
        // If this was the pinned comment, clear the video's pinnedCommentId
        if (comment.isPinned) {
          transaction.update(videoRef, {
            'pinnedCommentId': null,
          });
        }
        
        // Decrement the video's comment count
        transaction.update(videoRef, {
          'comments': FieldValue.increment(-1),
        });
      });
      
      return true;
    } catch (e) {
      print('[GameService] Error deleting comment: $e');
      return false;
    }
  }

  // Handle high score comment creation
  Future<CommentModel?> handleHighScoreComment(String text) async {
    if (_currentVideoId == null) {
      throw Exception('No video selected');
    }
    
    if (_currentScore <= (_currentVideoHighScore ?? 0)) {
      throw Exception('Score is not higher than current high score');
    }

    try {
      final comment = await createPinnedComment(text);
      if (comment != null) {
        // Update local state
        _currentVideoHighScore = _currentScore;
        if (_currentVideo != null) {
          _currentVideo = _currentVideo!.copyWith(
            highestGameScore: _currentScore,
            pinnedCommentId: comment.id,
          );
        }
        notifyListeners();
        return comment;
      } else {
        throw Exception('Failed to create pinned comment');
      }
    } catch (e) {
      print('[GameService] Error handling high score comment: $e');
      rethrow; // Propagate the error to the UI
    }
  }

  // Stream pinned comment for real-time updates
  Stream<CommentModel?> streamPinnedComment(String videoId) {
    return _videos.doc(videoId).snapshots().asyncMap((videoDoc) async {
      if (!videoDoc.exists) {
        print('[GameService] Video document not found');
        return null;
      }
      
      final data = videoDoc.data() as Map<String, dynamic>;
      final pinnedCommentId = data['pinnedCommentId'];
      if (pinnedCommentId == null) {
        print('[GameService] No pinned comment ID found');
        return null;
      }
      
      try {
        final commentDoc = await _commentsRef(videoId).doc(pinnedCommentId).get();
        if (!commentDoc.exists) {
          print('[GameService] Pinned comment document not found');
          return null;
        }
        
        print('[GameService] Found pinned comment: ${commentDoc.id}');
        return CommentModel.fromFirestore(commentDoc);
      } catch (e) {
        print('[GameService] Error getting pinned comment: $e');
        return null;
      }
    });
  }

  // Get pinned comment for a video
  Future<CommentModel?> getPinnedComment(String videoId) async {
    try {
      final videoDoc = await _videos.doc(videoId).get();
      if (!videoDoc.exists) {
        print('[GameService] Video document not found');
        return null;
      }
      
      final data = videoDoc.data() as Map<String, dynamic>;
      final pinnedCommentId = data['pinnedCommentId'];
      if (pinnedCommentId == null) {
        print('[GameService] No pinned comment ID found');
        return null;
      }
      
      final commentDoc = await _commentsRef(videoId).doc(pinnedCommentId).get();
      if (!commentDoc.exists) {
        print('[GameService] Pinned comment document not found');
        return null;
      }
      
      print('[GameService] Found pinned comment: ${commentDoc.id}');
      return CommentModel.fromFirestore(commentDoc);
    } catch (e) {
      print('[GameService] Error getting pinned comment: $e');
      return null;
    }
  }

  // Get comments for a video, optionally excluding pinned comment
  Future<List<CommentModel>> getCommentsForVideo(String videoId, {
    bool excludePinned = false,
    int? limit,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _commentsRef(videoId)
          .orderBy('createdAt', descending: true);
      
      if (excludePinned) {
        query = query.where('isPinned', isEqualTo: false);
      }
      
      if (limit != null) {
        query = query.limit(limit);
      }
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('[GameService] Error getting comments: $e');
      return [];
    }
  }

  // Validate comment text
  String? validateComment(String? text) {
    if (text == null || text.trim().isEmpty) {
      return 'Comment cannot be empty';
    }
    
    if (text.trim().length > 500) {
      return 'Comment must be less than 500 characters';
    }
    
    // Add any additional validation rules here
    
    return null; // Return null if validation passes
  }

  // Sanitize comment text
  String sanitizeComment(String text) {
    // Remove excessive whitespace
    String sanitized = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Add any additional sanitization rules here
    
    return sanitized;
  }

  // Get comments with pagination
  Future<QuerySnapshot> getCommentPage(String videoId, {
    DocumentSnapshot? startAfter,
    int pageSize = 20,
    bool excludePinned = true,
  }) async {
    try {
      Query query = _commentsRef(videoId)
          .orderBy('createdAt', descending: true);
      
      if (excludePinned) {
        query = query.where('isPinned', isEqualTo: false);
      }
      
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      
      return await query.limit(pageSize).get();
    } catch (e) {
      print('[GameService] Error getting comment page: $e');
      rethrow;
    }
  }

  // Handle comment transitions
  Future<void> handleCommentTransition(String videoId, String oldPinnedId, String newPinnedId) async {
    try {
      await _firestore.runTransaction((transaction) async {
        final oldCommentRef = _commentsRef(videoId).doc(oldPinnedId);
        final newCommentRef = _commentsRef(videoId).doc(newPinnedId);
        final videoRef = _videos.doc(videoId);
        
        // Get current states
        final oldCommentDoc = await transaction.get(oldCommentRef);
        final newCommentDoc = await transaction.get(newCommentRef);
        final videoDoc = await transaction.get(videoRef);
        
        if (!oldCommentDoc.exists || !newCommentDoc.exists || !videoDoc.exists) {
          throw Exception('Required documents not found');
        }
        
        // Update old pinned comment
        transaction.update(oldCommentRef, {
          'isPinned': false,
          'wasPinned': true,
        });
        
        // Update new pinned comment
        transaction.update(newCommentRef, {
          'isPinned': true,
          'wasPinned': false,
        });
        
        // Update video reference
        transaction.update(videoRef, {
          'pinnedCommentId': newPinnedId,
        });
      });
      
      notifyListeners();
    } catch (e) {
      print('[GameService] Error handling comment transition: $e');
      rethrow;
    }
  }

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

      // Check if this is a new high score for the current video
      if (_currentVideoId != null && _currentScore > (_currentVideoHighScore ?? 0)) {
        await _updateVideoHighScore(_currentVideoId!, _currentScore);
      }

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

  // Update video's high score and handle pinned comment
  Future<void> _updateVideoHighScore(String videoId, int newScore) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Start a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        final videoRef = _videos.doc(videoId);
        final videoDoc = await transaction.get(videoRef);
        
        if (!videoDoc.exists) return;
        
        final data = videoDoc.data() as Map<String, dynamic>;
        final currentHighScore = data['highestGameScore'] ?? 0;
        
        // Only update if the new score is higher
        if (newScore > currentHighScore) {
          transaction.update(videoRef, {
            'highestGameScore': newScore,
          });
          
          // Update local tracking
          _currentVideoHighScore = newScore;
          if (_currentVideo != null) {
            _currentVideo = _currentVideo!.copyWith(highestGameScore: newScore);
          }
        }
      });
      
      notifyListeners();
    } catch (e) {
      print('[GameService] Error updating video high score: $e');
    }
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

  // Get video's high score
  Future<int> getVideoHighScore(String videoId) async {
    try {
      final doc = await _videos.doc(videoId).get();
      final data = doc.data() as Map<String, dynamic>;
      return data['highestGameScore'] ?? 0;
    } catch (e) {
      print('[GameService] Error getting video high score: $e');
      return 0;
    }
  }
} 