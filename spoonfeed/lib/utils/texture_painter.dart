import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;

class WoodTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base wood color - warm, light brown
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFFD4B595),  // Light, warm wood base
    );

    final random = math.Random(42);  // Fixed seed for consistent pattern

    // Draw horizontal wood planks
    final plankHeight = size.height / 6;  // 6 planks
    for (int i = 0; i < 6; i++) {
      final y = i * plankHeight;
      
      // Plank separation line
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFF8B7355).withOpacity(0.3)
          ..strokeWidth = 1.0,
      );

      // Wood grain for each plank
      for (double grainY = y; grainY < y + plankHeight; grainY += 3) {
        final path = Path();
        path.moveTo(0, grainY);

        // Create natural-looking wood grain
        double currentX = 0;
        while (currentX < size.width) {
          final controlPoint1 = currentX + random.nextDouble() * 30;
          final controlPoint2 = currentX + 30 + random.nextDouble() * 30;
          final endPoint = currentX + 60;

          path.cubicTo(
            controlPoint1, grainY + random.nextDouble() * 2 - 1,
            controlPoint2, grainY + random.nextDouble() * 2 - 1,
            endPoint, grainY,
          );

          currentX = endPoint;
        }

        // Draw grain line with varying opacity
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF8B7355).withOpacity(0.1 + random.nextDouble() * 0.1)
            ..strokeWidth = 0.5
            ..style = PaintingStyle.stroke,
        );
      }

      // Add some darker spots and variations
      for (int j = 0; j < 5; j++) {
        final spotX = random.nextDouble() * size.width;
        final spotY = y + random.nextDouble() * plankHeight;
        final spotSize = 2 + random.nextDouble() * 4;

        canvas.drawCircle(
          Offset(spotX, spotY),
          spotSize,
          Paint()
            ..color = const Color(0xFF8B7355).withOpacity(0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
        );
      }
    }

    // Add some knots with natural variation
    for (int i = 0; i < 4; i++) {
      final knotX = size.width * (0.2 + random.nextDouble() * 0.6);
      final knotY = size.height * (0.2 + random.nextDouble() * 0.6);
      final knotSize = 4 + random.nextDouble() * 6;

      // Draw knot base
      canvas.drawCircle(
        Offset(knotX, knotY),
        knotSize,
        Paint()
          ..color = const Color(0xFF6B4423)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );

      // Draw knot center
      canvas.drawCircle(
        Offset(knotX, knotY),
        knotSize * 0.6,
        Paint()
          ..color = const Color(0xFF8B7355)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1),
      );
    }

    // Add subtle overlay texture
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.02),
            Colors.black.withOpacity(0.02),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

Future<ui.Image> generateWoodTexture() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = Size(300, 300);
  
  WoodTexturePainter().paint(canvas, size);
  
  final picture = recorder.endRecording();
  return picture.toImage(size.width.toInt(), size.height.toInt());
} 