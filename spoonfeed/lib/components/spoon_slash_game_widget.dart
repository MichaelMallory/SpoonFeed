import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'spoon_slash_game.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import '../models/video_model.dart';
import '../models/comment_model.dart';

class SpoonSlashGameWidget extends StatefulWidget {
  final Function(int) onScoreChanged;

  const SpoonSlashGameWidget({
    Key? key,
    required this.onScoreChanged,
  }) : super(key: key);

  @override
  _SpoonSlashGameWidgetState createState() => _SpoonSlashGameWidgetState();
}

class _SpoonSlashGameWidgetState extends State<SpoonSlashGameWidget> {
  late SpoonSlashGame game;
  bool _showingDialog = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  static const int _maxCommentLength = 500;

  @override
  void initState() {
    super.initState();
    game = SpoonSlashGame(onScoreChanged: _handleScoreChanged);
    
    // Add a game state listener
    game.addStateListener(() {
      if (mounted) {
        setState(() {});  // Rebuild when game state changes
      }
    });
  }

  @override
  void dispose() {
    game.removeStateListener();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _handleCommentSubmission(BuildContext context, int score) async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a comment to claim your high score!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final gameService = Provider.of<GameService>(context, listen: false);
      final comment = await gameService.handleHighScoreComment(_commentController.text.trim());
      
      if (comment != null) {
        if (mounted) {
          Navigator.of(context).pop(); // Close the dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🎉 Your comment has been pinned!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to create comment');
      }
    } catch (e) {
      if (!mounted) return;
      
      String errorMessage = 'An error occurred. Please try again.';
      
      if (e.toString().contains('permission-denied')) {
        errorMessage = 'Please sign in to post your comment.';
      } else if (e.toString().contains('Failed to create comment')) {
        errorMessage = 'Failed to create comment. Please try again.';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          action: e.toString().contains('permission-denied')
              ? SnackBarAction(
                  label: 'Sign In',
                  textColor: Colors.white,
                  onPressed: () {
                    // TODO: Trigger sign in flow
                    Navigator.of(context).pop(); // Close the dialog
                  },
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          if (!_showingDialog) {
            _showingDialog = false;
          }
        });
      }
    }
  }

  void _handleScoreChanged(int score) async {
    // Call the widget's onScoreChanged callback
    widget.onScoreChanged(score);
  }

  Future<void> _handleGameOver(int finalScore) async {
    // Get the current video context from GameService
    final gameService = Provider.of<GameService>(context, listen: false);
    final currentVideo = gameService.currentVideo;
    
    // Check if this is a new high score for the video
    if (currentVideo != null && 
        finalScore > (currentVideo.highestGameScore) && 
        !_showingDialog) {
      _showingDialog = true;
      _commentController.clear(); // Clear any previous text
      
      // Show achievement dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.purple.shade900,
          title: const Text(
            '🎮 New High Score!',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Score: $finalScore',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Add a comment to claim your spot at the top!',
                style: TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                maxLength: _maxCommentLength,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter your winning comment...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  counterStyle: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _isSubmitting 
                ? null 
                : () {
                    Navigator.of(context).pop();
                    _showingDialog = false;
                  },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: _isSubmitting 
                    ? Colors.white.withOpacity(0.5) 
                    : Colors.white,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: _isSubmitting 
                ? null 
                : () => _handleCommentSubmission(context, finalScore),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.green.withOpacity(0.3),
              ),
              child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Submit',
                    style: TextStyle(color: Colors.white),
                  ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Game layer with gesture detector - moved to front of stack
        Positioned.fill(
          child: GameWidget(
            game: game,
            backgroundBuilder: (context) => Container(
              color: Colors.transparent,
            ),
          ),
        ),
        
        // Game state overlays
        if (game.gameState == GameState.initial)
          Positioned.fill(
            child: Center(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    game.startGame();
                  });
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  backgroundColor: Colors.green,
                  elevation: 8,
                  shadowColor: Colors.black.withOpacity(0.5),
                ),
                child: const Text(
                  'Start Spoon Slash',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                        offset: Offset(1, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        
        // Game over overlay
        if (game.gameState == GameState.gameOver)
          Container(
            color: Colors.black.withOpacity(0.85),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🔪 Game Over! 🍴',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.red,
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Score: ${game.score}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            // Handle high score before starting new game
                            await _handleGameOver(game.score);
                            if (mounted) {
                              setState(() {
                                game.startGame();
                              });
                            }
                          },
                          icon: const Icon(Icons.replay, size: 28),
                          label: const Text(
                            'Play Again',
                            style: TextStyle(fontSize: 20),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            backgroundColor: Colors.green,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            // Handle high score before closing game
                            await _handleGameOver(game.score);
                            if (mounted) {
                              final gameService = Provider.of<GameService>(context, listen: false);
                              gameService.toggleGameMode();
                            }
                          },
                          icon: const Icon(Icons.close, size: 28),
                          label: const Text(
                            'Close Game',
                            style: TextStyle(fontSize: 20),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
} 