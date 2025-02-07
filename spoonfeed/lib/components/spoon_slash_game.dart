import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import './dual_view_container.dart';
import 'package:provider/provider.dart';
import '../services/game_service.dart';
import 'food_component.dart';

enum GameState {
  initial,
  playing,
  gameOver
}

class SpoonSlashGame extends FlameGame with DragCallbacks, HasCollisionDetection {
  int score = 0;
  int lives = 3;
  final Function(int) onScoreChanged;
  final Random _random = Random();
  GameState _gameState = GameState.initial;
  double _spawnTimer = 0.0;
  final double _spawnInterval = 1.5; // Slower spawn rate
  TextComponent? _scoreText;
  bool _isPaused = false;
  bool _isUpdatingLives = false;
  
  // Add state listener
  VoidCallback? _stateListener;
  
  GameState get gameState => _gameState;
  set gameState(GameState newState) {
    if (_gameState != newState) {
      _gameState = newState;
      _stateListener?.call();
    }
  }
  
  void addStateListener(VoidCallback listener) {
    _stateListener = listener;
  }
  
  void removeStateListener() {
    _stateListener = null;
  }
  
  // Track swipe path
  final List<Vector2> _swipePath = [];
  double _swipeTimer = 0;
  static const _swipeDuration = 0.3; // Increased trail duration for better visibility
  
  @override
  Color backgroundColor() => Colors.transparent;  // Make background transparent to show gradient

  // List of food items that can appear in the game with their glow colors
  final List<Map<String, dynamic>> foodItems = [
    {'emoji': '🍎', 'color': Colors.red},
    {'emoji': '🍊', 'color': Colors.orange},
    {'emoji': '🍋', 'color': Colors.yellow},
    {'emoji': '🍐', 'color': Colors.lightGreen},
    {'emoji': '🍌', 'color': Colors.yellow},
    {'emoji': '🍉', 'color': Colors.pink},
    {'emoji': '🍇', 'color': Colors.purple},
    {'emoji': '🍓', 'color': Colors.red},
    {'emoji': '🍍', 'color': Colors.yellow},
    {'emoji': '🥝', 'color': Colors.green},
    {'emoji': '🥭', 'color': Colors.orange},
    {'emoji': '🍑', 'color': Colors.pink},
  ];

  SpoonSlashGame({required this.onScoreChanged});

  void startGame() {
    print('Starting game...');
    // Reset all game variables
    score = 0;
    lives = 3;
    _spawnTimer = 0.0;
    _swipeTimer = 0;
    _swipePath.clear();
    _isPaused = false;
    
    // Clear any existing food items
    removeAll(children.whereType<FoodComponent>());
    
    // Update game state and UI
    gameState = GameState.playing;
    onScoreChanged(score);
    _updateScoreDisplay();
    
    // Resume the game engine
    resumeEngine();
  }

  void _updateScoreDisplay() {
    _scoreText?.removeFromParent();
    _scoreText = TextComponent(
      text: 'Score: $score  Lives: $lives',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 32,
          shadows: [
            Shadow(
              blurRadius: 8,
              color: Colors.black,
              offset: Offset(2, 2),
            ),
          ],
        ),
      ),
    );
    // Position the score text at the top of the game area
    _scoreText!.position = Vector2(20, 5);
    add(_scoreText!);
  }

  void endGame() {
    print('[Game] Game Over! Final score: $score');
    gameState = GameState.gameOver;
    removeAll(children.whereType<FoodComponent>());
    _swipePath.clear(); // Clear any remaining swipe trails
    _spawnTimer = 0.0; // Reset spawn timer
    
    // Send final score
    onScoreChanged(score);
    _updateScoreDisplay();
    
    // Ensure the game is paused
    _isPaused = true;
    pauseEngine();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialize game state
    gameState = GameState.playing;
    
    // Set up camera to match container size
    camera.viewfinder.visibleGameSize = size;
    camera.viewfinder.position = Vector2(0, 0);
    camera.viewfinder.zoom = 1.0;
    
    // Add initial score display
    _updateScoreDisplay();
    
    // Start the game
    startGame();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Render swipe trail if exists with fade out effect
    if (_swipePath.isNotEmpty) {
      final fadeProgress = (_swipeTimer / _swipeDuration).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.8 * (1.0 - fadeProgress))
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      final path = Path();
      if (_swipePath.length >= 2) {
        path.moveTo(_swipePath.first.x, _swipePath.first.y);
        
        for (int i = 1; i < _swipePath.length; i++) {
          final point = _swipePath[i];
          path.lineTo(point.x, point.y);
        }
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  void update(double dt) {
    if (_isPaused || gameState != GameState.playing) return;
    
    super.update(dt);
    
    if (gameState == GameState.playing) {
      _spawnTimer += dt;
      if (_spawnTimer >= _spawnInterval) {
        _spawnTimer = 0.0;
        _spawnFoodItem();
      }
      
      // Update swipe trail with a fade out effect
      if (_swipePath.isNotEmpty) {
        _swipeTimer += dt;
        if (_swipeTimer >= _swipeDuration) {
          _swipePath.removeAt(0); // Remove oldest point instead of clearing all
          _swipeTimer = _swipeDuration - 0.1; // Keep removing points gradually
        }
      }

      // Check if any food items are too far above or below the screen
      final foodItems = children.whereType<FoodComponent>().toList();
      for (final food in foodItems) {
        // Allow food to go into the video section by checking against -size.y
        // This means food can go up to the very top of the screen
        if (food.position.y < -size.y) {
          food.velocity.y *= -0.8; // Bounce back down only at the very top of the screen
        }
        
        // Remove food if it goes too far up or down
        if ((food.position.y > size.y + 100 || food.position.y < -(size.y + 100)) && !food.isSliced) {
          food.removeFromParent();
          if (food.position.y > size.y) { // Only count as miss if it falls below
            onFoodMissed();
          }
        }
      }
    }
  }

  void _spawnFoodItem() {
    final startX = _random.nextDouble() * size.x;
    final startY = size.y; // Start at the very bottom
    
    // Create food with random initial velocity
    final foodItem = FoodComponent(
      position: Vector2(startX, startY),
      velocity: Vector2(
        _random.nextDouble() * 100 - 50,  // Reduced horizontal velocity for more controlled movement
        -500 - _random.nextDouble() * 100, // Reduced upward velocity to peak around middle of screen
      ),
    );
    
    add(foodItem);
    print('[Game] Spawned food item at ($startX, $startY) with velocity ${foodItem.velocity}');
  }

  @override
  void onFoodMissed() {
    if (gameState != GameState.playing) return;
    
    // Ensure we're not in the middle of another lives update
    if (_isUpdatingLives) return;
    _isUpdatingLives = true;
    
    print('[Game] Food missed! Lives remaining: ${lives - 1}');
    lives--;
    _updateScoreDisplay(); // Update display to show new lives count
    
    if (lives <= 0) {
      print('[Game] Game Over - Out of lives');
      endGame(); // Call endGame instead of just setting state
    }
    
    _isUpdatingLives = false;
  }

  void updateScore(int points) {
    if (gameState != GameState.playing) return;
    
    score += points;
    _updateScoreDisplay();
    print('[Game] Score updated: $score');
    
    // Notify GameService of the new total score
    onScoreChanged(score);
  }

  @override
  bool onDragStart(DragStartEvent event) {
    if (gameState != GameState.playing) return false;
    
    // Only handle drags that start in the bottom half of the screen
    if (event.canvasPosition.y < size.y / 2) return false;
    
    print('[Game] Swipe started at: ${event.canvasPosition}');
    // Don't clear existing path, just start a new segment
    _swipePath.add(event.canvasPosition);
    _swipeTimer = 0;
    return true;
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (gameState != GameState.playing) return false;
    
    // If there's no active swipe or it started in the top half, ignore
    if (_swipePath.isEmpty) return false;
    
    // Add the new point
    _swipePath.add(event.canvasPosition);
    
    // Keep the path at a reasonable length
    if (_swipePath.length > 20) {
      _swipePath.removeAt(0);
    }
    
    // Check for food items that intersect with the latest swipe segment
    final foodItems = children.whereType<FoodComponent>().toList();
    if (_swipePath.length >= 2) {
      final start = _swipePath[_swipePath.length - 2];
      final end = _swipePath[_swipePath.length - 1];
      
      for (final food in foodItems) {
        if (!food.isSliced && _checkSwipeIntersectFood(start, end, food)) {
          print('[Game] Food sliced by swipe!');
          food.slice();
          updateScore(1);
        }
      }
    }
    
    return true;
  }

  @override
  bool onDragEnd(DragEndEvent event) {
    if (gameState != GameState.playing) return false;
    
    print('[Game] Swipe ended');
    return true;
  }

  bool _checkSwipeIntersectFood(Vector2 swipeStart, Vector2 swipeEnd, FoodComponent food) {
    final foodCenter = food.position + food.size / 2;
    final hitRadius = 40.0; // Larger hit area for better detection
    
    // Check if the line segment (swipeStart to swipeEnd) intersects with the food's circle
    final closest = _closestPointOnLine(swipeStart, swipeEnd, foodCenter);
    final distance = (closest - foodCenter).length;
    
    return distance < hitRadius;
  }

  Vector2 _closestPointOnLine(Vector2 lineStart, Vector2 lineEnd, Vector2 point) {
    final lineVec = lineEnd - lineStart;
    final pointVec = point - lineStart;
    final lineLengthSq = lineVec.length2;
    
    if (lineLengthSq == 0) {
      return lineStart;
    }
    
    final t = (pointVec.dot(lineVec) / lineLengthSq).clamp(0.0, 1.0);
    return lineStart + (lineVec * t);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    
    // Update camera viewport to match the new size
    camera.viewfinder.visibleGameSize = size;
    camera.viewfinder.position = Vector2(0, 0);
    camera.viewfinder.zoom = 1.0;
    
    // Reposition score text if it exists
    if (_scoreText != null) {
      _scoreText!.position = Vector2(20, 5);
    }
  }

  @override
  void onRemove() {
    // Prevent resource cleanup on temporary removal
    // Only clean up when the game is actually ending
    if (gameState == GameState.gameOver) {
      super.onRemove();
    }
  }

  @override
  void onMount() {
    super.onMount();
    // Restore game state if it was temporarily unmounted
    if (gameState == GameState.playing) {
      resumeEngine();
    }
  }

  void pauseGame() {
    _isPaused = true;
    pauseEngine();
  }

  void resumeGame() {
    _isPaused = false;
    resumeEngine();
  }
} 