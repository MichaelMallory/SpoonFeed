import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame/collisions.dart';
import 'package:flutter/material.dart';
import '../components/spoon_slash_game.dart';

class FoodComponent extends PositionComponent with HasGameRef<SpoonSlashGame> {
  final Vector2 velocity;
  bool _isSliced = false;
  bool get isSliced => _isSliced;
  final Random _random = Random();
  late TextComponent _foodEmoji;
  late final String emoji;
  late final Color glowColor;
  
  SpoonSlashGame get gameRef => parent! as SpoonSlashGame;
  
  // List of food items that can appear in the game with their glow colors
  static const List<Map<String, dynamic>> foodItems = [
    {'emoji': '🍅', 'color': Colors.red},      // Tomato
    {'emoji': '🥕', 'color': Colors.orange},   // Carrot
    {'emoji': '🥬', 'color': Colors.green},    // Lettuce
    {'emoji': '🧄', 'color': Colors.white},    // Garlic
    {'emoji': '🥔', 'color': Colors.brown},    // Potato
    {'emoji': '🥒', 'color': Colors.green},    // Cucumber
    {'emoji': '🫑', 'color': Colors.red},      // Bell Pepper
    {'emoji': '🧅', 'color': Colors.purple},   // Onion
    {'emoji': '🥦', 'color': Colors.green},    // Broccoli
    {'emoji': '🌽', 'color': Colors.yellow},   // Corn
  ];

  FoodComponent({
    required Vector2 position,
    required this.velocity,
  }) : super(position: position, size: Vector2.all(40)) {
    // Randomly select a food item
    final foodItem = foodItems[_random.nextInt(foodItems.length)];
    emoji = foodItem['emoji'] as String;
    glowColor = foodItem['color'] as Color;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    _foodEmoji = TextComponent(
      text: emoji,
      textRenderer: TextPaint(
        style: TextStyle(
          fontSize: 40,
          shadows: [
            Shadow(
              blurRadius: 15,
              color: Colors.white,
              offset: const Offset(0, 0),
            ),
            Shadow(
              blurRadius: 8,
              color: glowColor,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      ),
    );
    _foodEmoji.position = Vector2(0, 0);
    add(_foodEmoji);

    // Add a larger hitbox for better touch detection
    add(RectangleHitbox(
      size: Vector2.all(60),  // Much larger hitbox
      position: Vector2(-10, -10),  // Center it around the food
      isSolid: false,
    ));
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    if (!_isSliced) {
      // Apply gravity
      velocity.y += 500 * dt;
      
      // Update position
      position += velocity * dt;
      
      // Add some rotation for fun
      angle += dt * (velocity.x * 0.01);
      
      // Check if off screen
      if (position.y > gameRef.size.y + 100) {
        if (!_isSliced) {
          gameRef.onFoodMissed();  // Notify game directly
        }
        removeFromParent();
      }
    } else {
      // Sliced food falls faster
      position.y += 800 * dt;
      angle += dt * 5;
      
      if (position.y > gameRef.size.y + 100) {
        removeFromParent();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    
    if (!_isSliced) {
      // Draw a more visible glow effect
      final paint = Paint()
        ..color = glowColor.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 15);
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        30.0,
        paint,
      );

      // Draw a solid background for better visibility
      final bgPaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        25.0,
        bgPaint,
      );
    } else {
      // Draw sliced effect
      final paint = Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 20);
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        20.0,
        paint,
      );
    }
  }

  void slice() {
    if (!_isSliced) {
      _isSliced = true;
      print('[Game] Food item sliced! Type: $emoji');
      
      _foodEmoji.textRenderer = TextPaint(
        style: TextStyle(
          fontSize: 50,
          shadows: [
            Shadow(
              blurRadius: 20,
              color: glowColor,
              offset: const Offset(0, 0),
            ),
            Shadow(
              blurRadius: 10,
              color: Colors.white,
              offset: const Offset(0, 0),
            ),
          ],
        ),
      );
      
      // Create particle effects for slicing
      final particleSystem = ParticleSystemComponent(
        particle: Particle.generate(
          count: 10,
          lifespan: 1,
          generator: (i) {
            final direction = Vector2(
              _random.nextDouble() * 2 - 1,
              _random.nextDouble() * 2 - 1,
            )..normalize()..scale(200);
            
            return AcceleratedParticle(
              acceleration: Vector2(0, 500),
              speed: direction,
              child: CircleParticle(
                radius: 3,
                paint: Paint()..color = glowColor.withOpacity(0.8),
              ),
            );
          },
        ),
      );
      
      particleSystem.position = position + size / 2;
      parent?.add(particleSystem);
      
      gameRef.updateScore(1);
    }
  }
} 