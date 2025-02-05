import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'spoon_slash_game.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';

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

  @override
  void initState() {
    super.initState();
    game = SpoonSlashGame(onScoreChanged: (score) {
      widget.onScoreChanged(score);
      // Update the GameService with the new score
      Provider.of<GameService>(context, listen: false).updateScore(score);
    });
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
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.indigo.shade900.withOpacity(0.7),
                    Colors.purple.shade900.withOpacity(0.7),
                  ],
                ),
              ),
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
                          onPressed: () {
                            setState(() {
                              game.startGame();
                            });
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
                          onPressed: () {
                            final gameService = Provider.of<GameService>(context, listen: false);
                            gameService.toggleGameMode();
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