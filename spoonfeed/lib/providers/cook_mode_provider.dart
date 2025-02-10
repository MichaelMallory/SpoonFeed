import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';
import '../utils/cook_mode_logger.dart';
import '../services/cook_mode_permission_service.dart';
import '../services/cook_mode_camera_service.dart';
import '../components/cook_mode/permission_request_dialog.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:math' show max;
import '../services/gesture_recognition_service.dart';

/// Holds the current motion detection metrics for debugging
class MotionMetrics {
  final int activeCells;
  final int requiredCells;
  final int maxLuminanceDiff;
  final double averageMotionRatio;
  final bool hasMotion;
  final bool hasRecentMotion; // Whether motion was detected in the last few seconds
  final int cooldownMs; // Remaining cooldown time in milliseconds

  const MotionMetrics({
    this.activeCells = 0,
    this.requiredCells = 1,
    this.maxLuminanceDiff = 0,
    this.averageMotionRatio = 0.0,
    this.hasMotion = false,
    this.hasRecentMotion = false,
    this.cooldownMs = 0,
  });
}

/// Provider class that manages the state for the hands-free cooking mode feature.
/// This includes camera permissions, gesture detection state, and mode activation.
class CookModeProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final CookModeCameraService _cameraService;
  final CookModePermissionService _permissionService;
  final GestureRecognitionService _gestureService;

  VideoPlayerController? _videoController;
  bool _isActive = false;
  bool _isProcessing = false;
  bool _hasPermission = false;
  bool _isPhoneFlat = false;
  String? _error;
  bool _isCameraReady = false;
  DateTime? _lastGestureTime;
  static const _gestureDebounceMs = 1000; // 1 second debounce

  // Rewind settings
  int _rewindDurationMs = 10000; // Default 10 seconds
  final int _rewindAnimationMs = 300;
  Timer? _rewindAnimationTimer;

  MotionMetrics _motionMetrics = const MotionMetrics();

  CookModeProvider(
    this._prefs,
    this._cameraService,
    this._permissionService,
    this._gestureService,
  ) {
    _init();
  }

  Future<void> _init() async {
    // Always start with cook mode off
    _isActive = false;
    await _prefs.setBool('cook_mode_active', false);
    _rewindDurationMs = _prefs.getInt('cook_mode_rewind_duration_ms') ?? 10000;
    
    CookModeLogger.logCookMode('Initialized', data: {
      'isActive': _isActive,
      'rewindDurationMs': _rewindDurationMs,
    });

    // Set up camera service callback
    _cameraService.setGestureCallback(_handleGesture);
    
    // Check initial permission status
    _hasPermission = await _permissionService.checkPermission();
    notifyListeners();
  }

  // Getters
  bool get isActive => _isActive;
  bool get isProcessing => _isProcessing;
  bool get hasPermission => _hasPermission;
  bool get isPhoneFlat => _isPhoneFlat;
  String? get error => _error;
  bool get isCameraReady => _isCameraReady;
  bool get isReady => _hasPermission && !_isProcessing && (_error == null);
  CameraController? get cameraController => _cameraService.controller;

  // Getters for rewind settings
  int get rewindDurationMs => _rewindDurationMs;
  int get rewindAnimationMs => _rewindAnimationMs;

  // Add getter for motion metrics
  MotionMetrics get motionMetrics => _motionMetrics;

  /// Sets the video controller to control
  void setVideoController(VideoPlayerController? controller) {
    final hadController = _videoController != null;
    _videoController = controller;
    CookModeLogger.logVideo('Video controller set', data: {
      'hasController': controller != null,
      'previouslyHadController': hadController,
      'isActive': _isActive,
      'isCameraReady': _isCameraReady,
    });
  }

  /// Handles gesture detection from camera with smooth rewind animation
  void _handleGesture(GestureResult gesture) {
    // Update motion metrics
    _motionMetrics = MotionMetrics(
      activeCells: gesture.activeCells,
      requiredCells: gesture.requiredCells,
      maxLuminanceDiff: gesture.maxLuminanceDiff,
      averageMotionRatio: gesture.averageMotionRatio,
      hasMotion: gesture.gestureDetected,
      hasRecentMotion: gesture.hasRecentMotion,
      cooldownMs: gesture.cooldownMs,
    );
    notifyListeners(); // Notify UI to update with new metrics

    CookModeLogger.logCookMode('Gesture received', data: {
      'gestureDetected': gesture.gestureDetected,
      'confidence': gesture.confidence,
      'gestureType': gesture.gestureType.toString(),
      'activeCells': gesture.activeCells,
      'maxLuminanceDiff': gesture.maxLuminanceDiff,
      'averageMotionRatio': gesture.averageMotionRatio,
      'hasVideoController': _videoController != null,
      'videoControllerInitialized': _videoController?.value.isInitialized ?? false,
      'isVideoPlaying': _videoController?.value.isPlaying ?? false,
    });

    if (gesture.gestureDetected) {
      CookModeLogger.logCookMode('Processing detected gesture', data: {
        'isActive': _isActive,
        'hasVideoController': _videoController != null,
        'videoControllerInitialized': _videoController?.value.isInitialized ?? false,
        'isVideoPlaying': _videoController?.value.isPlaying ?? false,
        'currentPosition': _videoController?.value.position.toString() ?? 'unknown',
      });

      if (_videoController != null && _videoController!.value.isInitialized) {
        final wasPlaying = _videoController!.value.isPlaying;
        if (wasPlaying) {
          CookModeLogger.logVideo('Pausing video from gesture');
          _videoController!.pause().then((_) {
            CookModeLogger.logVideo('Video paused successfully', data: {
              'position': _videoController!.value.position.toString(),
              'isPlaying': _videoController!.value.isPlaying,
            });
          }).catchError((error) {
            CookModeLogger.error('Video', 'Failed to pause video', data: {'error': error.toString()});
          });
        } else {
          CookModeLogger.logVideo('Playing video from gesture with rewind');
          // Perform rewind before playing
          _performRewind();
        }
      } else {
        CookModeLogger.error('CookMode', 'Video controller unavailable', data: {
          'hasController': _videoController != null,
          'isInitialized': _videoController?.value.isInitialized ?? false,
        });
      }
    }
  }

  /// Performs a smooth rewind animation
  void _performRewind() async {
    if (_videoController == null) {
      CookModeLogger.logVideo('Rewind cancelled - no video controller', data: {
        'isActive': _isActive,
        'isCameraReady': _isCameraReady,
      });
      return;
    }

    final startPosition = _videoController!.value.position;
    final targetPosition = Duration(
      milliseconds: max(0, startPosition.inMilliseconds - _rewindDurationMs),
    );

    CookModeLogger.logVideo('Starting rewind animation', data: {
      'startPosition': startPosition.toString(),
      'targetPosition': targetPosition.toString(),
      'rewindDuration': '${_rewindDurationMs}ms',
      'animationDuration': '${_rewindAnimationMs}ms',
      'isAtStart': startPosition.inMilliseconds == 0,
      'videoDuration': _videoController!.value.duration.toString(),
    });

    // Cancel any existing rewind animation
    if (_rewindAnimationTimer?.isActive ?? false) {
      CookModeLogger.logVideo('Cancelling existing rewind animation');
      _rewindAnimationTimer?.cancel();
    }

    // Calculate number of steps for smooth animation
    const stepsPerSecond = 30; // 30fps animation
    final totalSteps = (_rewindAnimationMs / (1000 / stepsPerSecond)).round();
    final stepDuration = Duration(milliseconds: (1000 / stepsPerSecond).round());
    
    int currentStep = 0;
    final startTime = DateTime.now();
    
    _rewindAnimationTimer = Timer.periodic(stepDuration, (timer) async {
      currentStep++;
      
      // Safety check - cancel if controller is no longer available
      if (_videoController == null || !_videoController!.value.isInitialized) {
        timer.cancel();
        CookModeLogger.logVideo('Rewind cancelled - controller became unavailable');
        return;
      }
      
      if (currentStep >= totalSteps) {
        timer.cancel();
        await _videoController!.seekTo(targetPosition);
        await _videoController!.play();
        final endTime = DateTime.now();
        CookModeLogger.logVideo('Rewind animation completed', data: {
          'startPosition': startPosition.toString(),
          'endPosition': targetPosition.toString(),
          'actualDuration': endTime.difference(startTime).inMilliseconds,
          'targetDuration': _rewindAnimationMs,
          'steps': currentStep,
          'finalVolume': _videoController!.value.volume,
          'isPlaying': _videoController!.value.isPlaying,
        });
        return;
      }

      // Calculate intermediate position using ease-out curve
      final progress = Curves.easeOut.transform(currentStep / totalSteps);
      final intermediateMs = startPosition.inMilliseconds -
          (_rewindDurationMs * progress).round();
      
      if (currentStep % 5 == 0) { // Log every 5th step to avoid spam
        CookModeLogger.logVideo('Rewind progress', data: {
          'step': currentStep,
          'totalSteps': totalSteps,
          'progress': progress.toStringAsFixed(2),
          'position': '${intermediateMs}ms',
          'elapsedTime': DateTime.now().difference(startTime).inMilliseconds,
          'isPlaying': _videoController!.value.isPlaying,
        });
      }
      
      await _videoController!.seekTo(Duration(milliseconds: max(0, intermediateMs)));
    });
  }

  /// Checks current camera permission status
  Future<void> _checkPermission() async {
    final hasPermission = await _permissionService.checkPermission();
    updatePermissionStatus(hasPermission);
  }

  /// Requests camera permission with user dialog
  Future<bool> requestPermission(BuildContext context) async {
    if (_hasPermission) return true;
    
    CookModeLogger.logCookMode('Showing permission request dialog');
    
    // Check if permission is permanently denied
    if (await _permissionService.isPermanentlyDenied()) {
      if (!context.mounted) return false;
      
      // Show settings dialog
      final openedSettings = await showDialog<bool>(
        context: context,
        builder: (_) => PermissionDeniedDialog(permissionService: _permissionService),
      ) ?? false;
      
      if (openedSettings) {
        // Wait a bit for user to potentially grant permission in settings
        await Future.delayed(const Duration(seconds: 1));
        await _checkPermission();
        return _hasPermission;
      }
      return false;
    }
    
    // Show initial permission request dialog
    if (!context.mounted) return false;
    final granted = await showDialog<bool>(
      context: context,
      builder: (_) => PermissionRequestDialog(permissionService: _permissionService),
    ) ?? false;
    
    if (granted) {
      await _checkPermission();
    }
    
    return granted;
  }

  /// Initializes the camera if needed
  Future<void> _initializeCamera() async {
    if (_isCameraReady) return;
    
    try {
      await _cameraService.initialize();
      _isCameraReady = true;
      notifyListeners();
    } catch (e, stackTrace) {
      _error = 'Failed to initialize camera: ${e.toString()}';
      CookModeLogger.error('CookMode', 'Camera initialization failed',
        data: {'error': e.toString()},
        stackTrace: stackTrace,
      );
      _isCameraReady = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Toggles the cook mode on/off
  Future<void> toggleCookMode(BuildContext context) async {
    if (_isProcessing) {
      CookModeLogger.logCookMode('Toggle rejected - already processing');
      return;
    }
    
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      if (!_isActive) {
        // Requesting to turn on cook mode
        if (!_hasPermission) {
          final granted = await requestPermission(context);
          if (!granted) {
            throw Exception('Camera permission required for cook mode');
          }
        }
        
        // Initialize camera
        await _initializeCamera();
        
        // Check lighting conditions
        final hasGoodLighting = await _cameraService.checkLightingConditions();
        if (!hasGoodLighting) {
          CookModeLogger.logCamera('Poor lighting conditions detected');
          // We'll still continue, but log it for now
          // Later we can add UI feedback for this
        }
        
        // Start camera preview
        await _cameraService.startPreview();
      } else {
        // Turning off cook mode
        await _cameraService.stopPreview();
      }
      
      _isActive = !_isActive;
      await _prefs.setBool('cook_mode_active', _isActive);
      CookModeLogger.logCookMode(_isActive ? 'Activated' : 'Deactivated', data: {
        'hasPermission': _hasPermission,
        'isPhoneFlat': _isPhoneFlat,
        'isCameraReady': _isCameraReady,
        'error': _error,
      });
      
    } catch (e, stackTrace) {
      _error = e.toString();
      _isActive = false;
      await _prefs.setBool('cook_mode_active', false);
      CookModeLogger.error('CookMode', 'Failed to toggle cook mode', 
        data: {'error': e.toString()},
        stackTrace: stackTrace
      );
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  /// Updates the phone's flat position state
  void updatePhonePosition(bool isFlat) {
    if (_isPhoneFlat != isFlat) {
      _isPhoneFlat = isFlat;
      CookModeLogger.logCookMode('Phone position changed', data: {
        'isFlat': isFlat,
        'wasFlat': _isPhoneFlat,
        'isActive': _isActive,
      });
      notifyListeners();
    }
  }

  /// Updates the permission state
  void updatePermissionStatus(bool hasPermission) {
    if (_hasPermission != hasPermission) {
      _hasPermission = hasPermission;
      CookModeLogger.logCookMode('Permission status changed', data: {
        'hasPermission': hasPermission,
        'hadPermission': _hasPermission,
        'isActive': _isActive,
      });
      notifyListeners();
    }
  }

  /// Clears any error state
  void clearError() {
    if (_error != null) {
      final previousError = _error;
      _error = null;
      CookModeLogger.logCookMode('Error cleared', data: {
        'previousError': _error,
        'isActive': _isActive,
      });
      notifyListeners();
    }
  }

  /// Setter for rewind duration
  void setRewindDuration(int milliseconds) {
    _rewindDurationMs = milliseconds.clamp(1000, 10000); // Limit between 1-10 seconds
    _prefs.setInt('cook_mode_rewind_duration_ms', _rewindDurationMs);
    CookModeLogger.logCookMode('Rewind duration updated', data: {
      'previousDuration': _rewindDurationMs,
      'newDuration': milliseconds,
      'isActive': _isActive,
    });
    notifyListeners();
  }

  /// Cleanup resources
  @override
  void dispose() {
    _isActive = false;
    _cameraService.dispose();
    CookModeLogger.logCookMode('Disposed');
    _rewindAnimationTimer?.cancel();
    super.dispose();
  }
} 