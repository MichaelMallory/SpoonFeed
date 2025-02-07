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
  GameState gameState = GameState.initial;
  double _spawnTimer = 0.0;
  final double _spawnInterval = 1.5; // Slower spawn rate
  TextComponent? _scoreText;
  
  // Track swipe path
  final List<Vector2> _swipePath = [];
  double _swipeTimer = 0;
  static const _swipeDuration = 0.2; // How long the swipe trail stays visible
  
  @override
  Color backgroundColor() => Colors.black54;  // Semi-transparent background

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
    score = 0;
    lives = 3;
    gameState = GameState.playing;
    onScoreChanged(score);
    _updateScoreDisplay();
    removeAll(children.whereType<FoodComponent>());  // Clear any existing food items
  }

  void _updateScoreDisplay() {
    _scoreText?.removeFromParent();
    _scoreText = TextComponent(
      text: 'Score: $score  Lives: $lives',  // Added lives display
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
    _scoreText!.position = Vector2(20, 20);
    add(_scoreText!);
  }

  void endGame() {
    print('[Game] Game Over! Final score: $score');
    gameState = GameState.gameOver;
    removeAll(children.whereType<FoodComponent>());
    _swipePath.clear(); // Clear any remaining swipe trails
    _spawnTimer = 0.0; // Reset spawn timer
    onScoreChanged(score); // Final score update
    _updateScoreDisplay(); // Update the display one last time
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Set up camera
    camera.viewfinder.visibleGameSize = Vector2(800, 600);
    
    // Add initial score display
    _updateScoreDisplay();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    // Render swipe trail if exists
    if (_swipePath.isNotEmpty) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.8)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      
      final path = Path();
      path.moveTo(_swipePath.first.x, _swipePath.first.y);
      
      for (int i = 1; i < _swipePath.length; i++) {
        path.lineTo(_swipePath[i].x, _swipePath[i].y);
      }
      
      canvas.drawPath(path, paint);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (gameState == GameState.playing) {
      _spawnTimer += dt;
      if (_spawnTimer >= _spawnInterval) {
        _spawnTimer = 0.0;
        _spawnFoodItem();
      }
      
      // Update swipe trail
      if (_swipePath.isNotEmpty) {
        _swipeTimer += dt;
        if (_swipeTimer >= _swipeDuration) {
          _swipePath.clear();
          _swipeTimer = 0;
        }
      }

      // Check if any food items are too far below the screen
      final foodItems = children.whereType<FoodComponent>().toList();
      for (final food in foodItems) {
        if (food.position.y > size.y + 100 && !food.isSliced) { // Add buffer for off-screen items
          food.removeFromParent();
          onFoodMissed();
        }
      }
    }
  }

  void _spawnFoodItem() {
    final startX = _random.nextDouble() * size.x;
    final startY = size.y + 50.0; // Start below the visible area
    
    // Create food with random initial velocity
    final foodItem = FoodComponent(
      position: Vector2(startX, startY),
      velocity: Vector2(
        _random.nextDouble() * 150 - 75,  // Reduced X velocity
        -600 - _random.nextDouble() * 200, // Reduced height for better playability
      ),
    );
    
    add(foodItem);
    print('[Game] Spawned food item at ($startX, $startY) with velocity ${foodItem.velocity}');
  }

  void onFoodMissed() {
    if (gameState != GameState.playing) return;
    
    print('[Game] Food missed! Lives remaining: ${lives - 1}');
    lives--;
    _updateScoreDisplay(); // Update display to show new lives count
    
    if (lives <= 0) {
      print('[Game] Game Over - Out of lives');
      endGame(); // Call endGame instead of just setting state
    }
  }

  void updateScore(int points) {
    score += points;
    onScoreChanged(score);
    _updateScoreDisplay();
    print('[Game] Score updated: $score');
  }

  @override
  bool onDragStart(DragStartEvent event) {
    if (gameState != GameState.playing) return false;
    
    print('[Game] Swipe started at: ${event.canvasPosition}');
    _swipePath.clear();
    _swipePath.add(event.canvasPosition);
    _swipeTimer = 0;
    return true;
  }

  @override
  bool onDragUpdate(DragUpdateEvent event) {
    if (gameState != GameState.playing) return false;
    
    print('[Game] Swipe updated at: ${event.canvasPosition}');
    _swipePath.add(event.canvasPosition);
    
    // Check for food items that intersect with the latest swipe segment
    final foodItems = children.whereType<FoodComponent>().toList();
    if (_swipePath.length >= 2) {
      final start = _swipePath[_swipePath.length - 2];
      final end = _swipePath[_swipePath.length - 1];
      
      for (final food in foodItems) {
        if (!food.isSliced && _checkSwipeIntersectFood(start, end, food)) {
          print('[Game] Food sliced by swipe!');
          food.slice();
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
    // Update camera viewport to match the game area
    camera.viewfinder.visibleGameSize = Vector2(size.x, size.y);
    camera.viewfinder.position = Vector2(0, 0);
    camera.viewfinder.zoom = 1.0;
  }
} 