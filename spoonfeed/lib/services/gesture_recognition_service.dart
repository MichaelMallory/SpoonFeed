import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:math';
import '../utils/cook_mode_logger.dart';

/// Service that handles motion detection for cook mode using direct frame analysis.
/// Uses a grid-based approach to detect significant motion in the upper portion of the frame.
class GestureRecognitionService {
  bool _isProcessing = false;
  DateTime? _lastGestureTime;
  DateTime? _lastMotionTime; // Track when we last saw any motion
  DateTime? _sessionStartTime;
  int _totalFramesProcessed = 0;
  int _maxActiveCells = 0;
  int _maxLuminanceDiff = 0;
  int _gestureDebounceMs = 1500; // Default gesture timer duration
  static const _frameProcessingIntervalMs = 200; // 5fps
  static const _motionDisplayTimeMs = 2000; // Total lock time
  static const _motionResetThresholdMs = 500; // Time without motion to reset state
  bool _forceReset = false; // New flag to force reset after gesture
  bool _fieldsCleared = false; // Track if fields have been cleared
  
  // Motion detection parameters
  static const _gridRows = 4;
  static const _gridCols = 4;
  static const int _motionThreshold = 25;
  static const int _requiredActiveCells = 2;
  static const int _pixelSamplingInterval = 3;
  static const double _minMotionRatio = 0.15;
  static const double _maxMotionRatio = 0.8;
  static const int _motionMemoryFrames = 3;
  
  DateTime? _lastFrameProcessed;
  DateTime? _lastSignificantMotion; // Track when we last saw significant motion
  List<Uint8List> _previousFrames = [];
  List<int> _recentActiveCells = [];
  bool _isMotionActive = false;
  
  /// Returns whether motion was detected recently (within display time window)
  bool get hasRecentMotion {
    if (_lastMotionTime == null) return false;
    if (_forceReset) {
      final timeSinceGesture = DateTime.now().difference(_lastGestureTime!).inMilliseconds;
      // Only show motion for the first 1.5s of the cooldown
      if (timeSinceGesture >= _gestureDebounceMs) return false;
      return true;
    }
    return false; // Never show motion outside of the gesture sequence
  }

  /// Returns the remaining cooldown time in milliseconds
  int get remainingCooldownMs {
    if (_lastGestureTime == null) return 0;
    final timeSinceGesture = DateTime.now().difference(_lastGestureTime!).inMilliseconds;
    return max(0, _gestureDebounceMs - timeSinceGesture);
  }

  /// Update the gesture timer duration
  void updateGestureTimerDuration(int durationMs) {
    _gestureDebounceMs = durationMs;
  }

  /// Processes a camera image frame to detect motion
  Future<GestureResult> processFrame(CameraImage image) async {
    _sessionStartTime ??= DateTime.now();
    _totalFramesProcessed++;

    final now = DateTime.now();

    // Handle the timing sequence after a gesture
    if (_forceReset && _lastGestureTime != null) {
      final timeSinceGesture = now.difference(_lastGestureTime!).inMilliseconds;
      
      // At 1.5 seconds, clear all fields if not already cleared
      if (timeSinceGesture >= _gestureDebounceMs && !_fieldsCleared) {
        _fieldsCleared = true;
        _lastMotionTime = null;
        _lastSignificantMotion = null;
        _isMotionActive = false;
        _recentActiveCells.clear();
        _previousFrames.clear(); // Clear frame history too
        CookModeLogger.logGesture('Motion detection reset', data: {
          'timeSinceGesture': timeSinceGesture,
          'gestureDebounceMs': _gestureDebounceMs,
        });
      }
      
      // At 2.0 seconds, re-enable motion detection
      if (timeSinceGesture > _motionDisplayTimeMs) {
        _forceReset = false;
        _fieldsCleared = false;
        CookModeLogger.logGesture('Motion detection re-enabled');
      }
    }

    if (_lastFrameProcessed != null && 
        now.difference(_lastFrameProcessed!).inMilliseconds < _frameProcessingIntervalMs) {
      return GestureResult.noGesture();
    }
    _lastFrameProcessed = now;

    if (_isProcessing) {
      return GestureResult.noGesture();
    }

    final frameStartTime = now;
    try {
      _isProcessing = true;
      
      // Extract current frame luminance
      final luminancePlane = image.planes[0];
      final pixels = luminancePlane.bytes;
      final stride = luminancePlane.bytesPerRow;
      final width = image.width;
      final height = image.height;
      
      final luminance = Uint8List(width * height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final pixelIndex = y * stride + x;
          if (pixelIndex < pixels.length) {
            luminance[y * width + x] = pixels[pixelIndex];
          }
        }
      }
      
      // Initialize frame history if needed
      if (_previousFrames.isEmpty) {
        _previousFrames.add(Uint8List.fromList(luminance));
        return GestureResult.noGesture();
      }

      // Analyze motion in grid cells
      final cellWidth = width ~/ _gridCols;
      final cellHeight = height ~/ _gridRows;
      int activeCells = 0;
      double totalMotionRatio = 0.0;
      
      // Only analyze top half of the frame
      for (int row = 0; row < _gridRows ~/ 2; row++) {
        for (int col = 0; col < _gridCols; col++) {
          int motionCount = 0;
          int sampleCount = 0;
          
          for (int y = row * cellHeight; y < (row + 1) * cellHeight; y += _pixelSamplingInterval) {
            for (int x = col * cellWidth; x < (col + 1) * cellWidth; x += _pixelSamplingInterval) {
              final idx = y * width + x;
              if (idx >= luminance.length || idx >= _previousFrames.last.length) continue;
              
              final currentValue = luminance[idx];
              final previousValue = _previousFrames.last[idx];
              
              final diff = (currentValue - previousValue).abs();
              if (diff > _motionThreshold) {
                motionCount++;
              }
              sampleCount++;
            }
          }

          final motionRatio = sampleCount > 0 ? motionCount / sampleCount : 0.0;
          if (motionRatio >= _minMotionRatio && motionRatio <= _maxMotionRatio) {
            activeCells++;
            totalMotionRatio += motionRatio;
          }
        }
      }

      // Update frame history
      _previousFrames.add(Uint8List.fromList(luminance));
      if (_previousFrames.length > _motionMemoryFrames) {
        _previousFrames.removeAt(0);
      }
      
      // Update active cells history
      _recentActiveCells.add(activeCells);
      if (_recentActiveCells.length > _motionMemoryFrames) {
        _recentActiveCells.removeAt(0);
      }

      // Detect motion patterns
      bool hasSignificantMotion = activeCells >= _requiredActiveCells;
      bool hasMotionChange = _recentActiveCells.length >= 2 && 
          (_recentActiveCells.last - _recentActiveCells[_recentActiveCells.length - 2]).abs() >= 1;
      
      // Update last significant motion time
      if (hasSignificantMotion) {
        _lastSignificantMotion = now;
        _lastMotionTime = now; // For UI display
      }

      // Reset motion state if no significant motion for a while
      bool shouldReset = _lastSignificantMotion != null && 
          now.difference(_lastSignificantMotion!).inMilliseconds > _motionResetThresholdMs;

      if (shouldReset || (!hasSignificantMotion && _isMotionActive)) {
        _isMotionActive = false;
        _recentActiveCells.clear();
        activeCells = 0;
        _lastMotionTime = null;
        _lastSignificantMotion = null;
        return GestureResult(
          gestureDetected: false,
          activeCells: 0,
          requiredCells: _requiredActiveCells,
          hasRecentMotion: false,
          cooldownMs: remainingCooldownMs,
          averageMotionRatio: 0.0,
        );
      }
      
      // Detect new motion sequence
      bool isNewMotion = hasSignificantMotion && hasMotionChange && !_isMotionActive;
      if (isNewMotion) {
        _isMotionActive = true;
        CookModeLogger.logGesture('New motion sequence started', data: {
          'activeCells': activeCells,
          'requiredCells': _requiredActiveCells,
          'motionRatio': totalMotionRatio / (_gridRows * _gridCols / 2),
        });
      }

      // Only trigger gesture on new motion if not in cooldown
      final shouldTriggerGesture = isNewMotion && (_lastGestureTime == null || 
          now.difference(_lastGestureTime!).inMilliseconds >= _gestureDebounceMs);

      if (shouldTriggerGesture) {
        _lastGestureTime = now;
        _lastMotionTime = now;
        _forceReset = true;
        _fieldsCleared = false;
        _previousFrames.clear(); // Clear frame history when gesture triggers
        
        CookModeLogger.logGesture('Gesture triggered', data: {
          'activeCells': activeCells,
          'requiredCells': _requiredActiveCells,
          'motionRatio': totalMotionRatio / (_gridRows * _gridCols / 2),
          'cooldownMs': _motionDisplayTimeMs,
        });
        
        return GestureResult(
          gestureDetected: true,
          confidence: activeCells / (_gridRows * _gridCols / 2),
          gestureType: GestureType.pausePlay,
          handedness: 'unknown',
          activeCells: activeCells,
          requiredCells: _requiredActiveCells,
          maxLuminanceDiff: _maxLuminanceDiff,
          averageMotionRatio: totalMotionRatio / (_gridRows * _gridCols / 2),
          hasRecentMotion: true,
          cooldownMs: _motionDisplayTimeMs,
        );
      }

      // Return current state
      return GestureResult(
        gestureDetected: false,
        activeCells: _isMotionActive ? activeCells : 0,
        requiredCells: _requiredActiveCells,
        hasRecentMotion: _isMotionActive,
        cooldownMs: remainingCooldownMs,
        averageMotionRatio: _isMotionActive ? totalMotionRatio / (_gridRows * _gridCols / 2) : 0.0,
      );

    } catch (e, stackTrace) {
      CookModeLogger.error('Gesture', 'Error processing frame',
        data: {'error': e.toString()},
        stackTrace: stackTrace,
      );
      return GestureResult.noGesture();
    } finally {
      _isProcessing = false;
    }
  }

  /// Disposes of resources and logs session summary
  void dispose() {
    _previousFrames.clear();
    _recentActiveCells.clear();
    _isMotionActive = false;
    _lastMotionTime = null;
    _lastSignificantMotion = null;
    
    if (_sessionStartTime != null) {
      final sessionDuration = DateTime.now().difference(_sessionStartTime!);
      CookModeLogger.logGesture('Session summary', data: {
        'totalFrames': _totalFramesProcessed,
        'sessionDurationSeconds': sessionDuration.inSeconds,
        'maxActiveCells': _maxActiveCells,
        'framesPerSecond': _totalFramesProcessed / sessionDuration.inSeconds,
        'lastGestureTime': _lastGestureTime?.toIso8601String(),
      });
    }
    
    _sessionStartTime = null;
    _totalFramesProcessed = 0;
    _maxActiveCells = 0;
    _lastGestureTime = null;
  }
}

/// Represents the result of gesture recognition
class GestureResult {
  final bool gestureDetected;
  final double confidence;
  final GestureType gestureType;
  final String handedness;
  final int activeCells;
  final int requiredCells;
  final int maxLuminanceDiff;
  final double averageMotionRatio;
  final bool hasRecentMotion; // Whether motion was detected recently
  final int cooldownMs; // Remaining cooldown time in milliseconds

  const GestureResult({
    required this.gestureDetected,
    this.confidence = 0.0,
    this.gestureType = GestureType.none,
    this.handedness = '',
    this.activeCells = 0,
    this.requiredCells = 1,
    this.maxLuminanceDiff = 0,
    this.averageMotionRatio = 0.0,
    this.hasRecentMotion = false,
    this.cooldownMs = 0,
  });

  /// Creates a result indicating no gesture was detected
  factory GestureResult.noGesture() => const GestureResult(
    gestureDetected: false,
  );
}

/// Types of gestures that can be recognized
enum GestureType {
  none,
  pausePlay,
}
