import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../../providers/cook_mode_provider.dart';

/// A widget that handles the camera preview for cook mode gesture detection.
/// The preview is invisible but the camera remains functional for gesture detection.
class CameraPreviewOverlay extends StatelessWidget {
  // Add a flag to control visibility, defaulting to false (hidden)
  final bool showDebugOverlay;
  
  const CameraPreviewOverlay({
    super.key,
    this.showDebugOverlay = false,  // Default to hidden
  });

  @override
  Widget build(BuildContext context) {
    // If debug overlay is not enabled, return an empty widget
    if (!showDebugOverlay) {
      return const SizedBox.shrink();
    }

    return Consumer<CookModeProvider>(
      builder: (context, provider, child) {
        if (!provider.isActive || provider.cameraController == null) {
          return const SizedBox.shrink();
        }

        final metrics = provider.motionMetrics;
        final hasRecentMotion = metrics.hasRecentMotion;
        final cooldownMs = metrics.cooldownMs;
        final isCoolingDown = cooldownMs > 0;

        // Return a small visible camera preview with debug info
        return Positioned(
          right: 16,
          top: 16,
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              border: Border.all(
                color: hasRecentMotion ? Colors.green : Colors.grey,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 200,
                      height: 150,
                      child: CameraPreview(
                        provider.cameraController!,
                      ),
                    ),
                    if (hasRecentMotion)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Motion Detected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                // Debug metrics
                Container(
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Motion: ${metrics.activeCells}/${metrics.requiredCells}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          if (isCoolingDown)
                            Text(
                              'Cooldown: ${(cooldownMs / 1000).toStringAsFixed(1)}s',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Motion Ratio: ${(metrics.averageMotionRatio * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: metrics.averageMotionRatio,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isCoolingDown ? Colors.orange : 
                                    hasRecentMotion ? Colors.green : 
                                    Colors.blue,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 