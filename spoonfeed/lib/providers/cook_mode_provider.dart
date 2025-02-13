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
import 'voice_control_provider.dart';
import 'package:provider/provider.dart';

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
  final BuildContext context;  // Add context to access providers

  VideoPlayerController? _videoController;
  String? _currentVideoId;
  bool _isActive = false;
  bool _isProcessing = false;
  bool _hasPermission = false;
  bool _isPhoneFlat = false;
  String? _error;
  bool _isCameraReady = false;
  DateTime? _lastGestureTime;
  DateTime? _lastMotionTime;
  bool _forceReset = false;
  bool _fieldsCleared = false;
  static const _gestureDebounceMs = 1000; // 1 second debounce

  // Rewind settings
  int _rewindDurationMs = 10000; // Default 10 seconds
  final int _rewindAnimationMs = 300;
  Timer? _rewindAnimationTimer;

  MotionMetrics _motionMetrics = const MotionMetrics();

  // Settings for gesture and voice control
  bool _gestureControlEnabled = true;
  bool _voiceControlEnabled = true;

  CookModeProvider(
    this._prefs,
    this._cameraService,
    this._permissionService,
    this._gestureService,
    this.context,  // Add context parameter
  ) {
    _init();
  }

  Future<void> _init() async {
    // Always start with cook mode off
    _isActive = false;
    await _prefs.setBool('cook_mode_active', false);
    _rewindDurationMs = _prefs.getInt('cook_mode_rewind_duration_ms') ?? 10000;
    _gestureControlEnabled = _prefs.getBool('cook_mode_gesture_enabled') ?? true;
    _voiceControlEnabled = _prefs.getBool('cook_mode_voice_enabled') ?? true;
    
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

  // Add getters for new settings
  bool get gestureControlEnabled => _gestureControlEnabled;
  bool get voiceControlEnabled => _voiceControlEnabled;

  /// Sets the video controller and ID to control
  void setVideo(VideoPlayerController? controller, String? videoId) {
    final hadController = _videoController != null;
    _videoController = controller;
    _currentVideoId = videoId;
    
    // Update voice control provider if available
    if (controller != null && videoId != null) {
      try {
        final voiceProvider = _getVoiceControlProvider();
        if (voiceProvider != null) {
          voiceProvider.setVideo(controller, videoId);
        }
      } catch (e) {
        CookModeLogger.error('CookMode', 'Failed to update voice control provider', data: {
          'error': e.toString(),
        });
      }
    }

    // Reset gesture state when switching videos
    if (hadController && controller != null && _gestureControlEnabled) {
      _lastGestureTime = null;
      _lastMotionTime = null;
      _forceReset = false;
      _fieldsCleared = false;
    }

    CookModeLogger.logVideo('Video controller set', data: {
      'hasController': controller != null,
      'videoId': videoId,
      'previouslyHadController': hadController,
      'isActive': _isActive,
      'isCameraReady': _isCameraReady,
      'gestureControlEnabled': _gestureControlEnabled,
    });
  }

  /// Helper to get voice control provider
  VoiceControlProvider? _getVoiceControlProvider() {
    try {
      return Provider.of<VoiceControlProvider>(context, listen: false);
    } catch (e) {
      CookModeLogger.error('CookMode', 'Failed to get voice control provider', data: {
        'error': e.toString(),
      });
      return null;
    }
  }

  /// Handles gesture detection from camera with smooth rewind animation
  void _handleGesture(GestureResult gesture) {
    // Debounce gestures
    final now = DateTime.now();
    if (_lastGestureTime != null && 
        now.difference(_lastGestureTime!).inMilliseconds < _gestureDebounceMs) {
      CookModeLogger.logCookMode('Gesture debounced', data: {
        'timeSinceLastGesture': now.difference(_lastGestureTime!).inMilliseconds,
        'debounceThreshold': _gestureDebounceMs,
      });
      return;
    }
    _lastGestureTime = now;

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

    if (!gesture.gestureDetected || !_isActive || !_gestureControlEnabled) {
      CookModeLogger.logCookMode('Gesture control check failed', data: {
        'gestureDetected': gesture.gestureDetected,
        'isActive': _isActive,
        'gestureControlEnabled': _gestureControlEnabled,
      });
      return;
    }

    CookModeLogger.logCookMode('Processing detected gesture', data: {
      'isActive': _isActive,
      'hasVideoController': _videoController != null,
      'videoControllerInitialized': _videoController?.value.isInitialized ?? false,
      'isVideoPlaying': _videoController?.value.isPlaying ?? false,
      'currentPosition': _videoController?.value.position.toString() ?? 'unknown',
      'gestureControlEnabled': _gestureControlEnabled,
      'videoId': _currentVideoId,
    });

    if (_videoController == null) {
      CookModeLogger.logVideo('No video controller available');
      return;
    }

    if (!_videoController!.value.isInitialized) {
      CookModeLogger.logVideo('Video controller not initialized');
      return;
    }

    final wasPlaying = _videoController!.value.isPlaying;
    
    if (wasPlaying) {
      // If video is playing, pause it
      CookModeLogger.logVideo('Pausing video from gesture');
      _videoController!.pause().then((_) {
        CookModeLogger.logVideo('Video paused successfully', data: {
          'position': _videoController!.value.position.toString(),
        });
        notifyListeners();
      }).catchError((error) {
        CookModeLogger.error('Video', 'Failed to pause video', data: {'error': error.toString()});
      });
    } else {
      // If video is paused, rewind and play
      CookModeLogger.logVideo('Playing video from gesture with rewind');
      _performRewind().then((_) {
        // Play video after rewind
        _videoController!.play().then((_) {
          CookModeLogger.logVideo('Video playing after rewind', data: {
            'position': _videoController!.value.position.toString(),
          });
          notifyListeners();
        });
      });
    }
  }

  /// Performs a smooth rewind animation and returns a Future that completes when done
  Future<void> _performRewind() async {
    if (_videoController == null) {
      CookModeLogger.logVideo('Rewind cancelled - no video controller');
      return;
    }

    final startPosition = _videoController!.value.position;
    final targetPosition = Duration(
      milliseconds: max(0, startPosition.inMilliseconds - _rewindDurationMs),
    );

    CookModeLogger.logVideo('Starting rewind', data: {
      'startPosition': startPosition.toString(),
      'targetPosition': targetPosition.toString(),
      'rewindDuration': '${_rewindDurationMs}ms',
    });

    // Perform the seek operation
    await _videoController!.seekTo(targetPosition);
    
    CookModeLogger.logVideo('Rewind complete', data: {
      'finalPosition': _videoController!.value.position.toString(),
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
        if (_gestureControlEnabled && !_hasPermission) {
          final granted = await requestPermission(context);
          if (!granted) {
            throw Exception('Camera permission required for gesture control');
          }
        }
        
        // Initialize camera if gesture control is enabled
        if (_gestureControlEnabled) {
          await _initializeCamera();
          await _cameraService.startPreview();
          _cameraService.setGestureCallback(_handleGesture);
        }

        // Enable voice control if enabled
        if (_voiceControlEnabled) {
          final voiceProvider = _getVoiceControlProvider();
          if (voiceProvider != null) {
            voiceProvider.setEnabled(true);
          }
        }
      } else {
        // Turning off cook mode
        if (_gestureControlEnabled) {
          await _cameraService.stopPreview();
          _cameraService.setGestureCallback((_) {});
        }

        // Disable voice control if it was enabled
        if (_voiceControlEnabled) {
          final voiceProvider = _getVoiceControlProvider();
          if (voiceProvider != null) {
            voiceProvider.setEnabled(false);
          }
        }
      }
      
      _isActive = !_isActive;
      await _prefs.setBool('cook_mode_active', _isActive);
      CookModeLogger.logCookMode(_isActive ? 'Activated' : 'Deactivated', data: {
        'hasPermission': _hasPermission,
        'isPhoneFlat': _isPhoneFlat,
        'isCameraReady': _isCameraReady,
        'gestureControlEnabled': _gestureControlEnabled,
        'voiceControlEnabled': _voiceControlEnabled,
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

  /// Disable gesture control
  Future<void> _disableGestureControl() async {
    _gestureControlEnabled = false;
    if (_cameraService != null) {
      _cameraService!.setGestureCallback((_) {}); // Empty callback instead of null
    }
    notifyListeners();
  }

  /// Set gesture control enabled state
  Future<void> setGestureControlEnabled(bool enabled) async {
    if (_gestureControlEnabled == enabled) return;
    
    _gestureControlEnabled = enabled;
    await _prefs.setBool('cook_mode_gesture_enabled', enabled);
    
    // Update gesture service if cook mode is active
    if (_isActive) {
      if (enabled) {
        await _initializeCamera();
        _cameraService.setGestureCallback(_handleGesture);
      } else {
        await _cameraService.stopPreview();
        _cameraService.setGestureCallback((_) {}); // Empty callback instead of null
      }
    }
    
    notifyListeners();
  }

  /// Set voice control enabled state
  Future<void> setVoiceControlEnabled(bool enabled) async {
    if (_voiceControlEnabled == enabled) return;
    
    _voiceControlEnabled = enabled;
    await _prefs.setBool('cook_mode_voice_enabled', enabled);
    
    // Update voice control if cook mode is active
    if (_isActive) {
      final voiceProvider = _getVoiceControlProvider();
      if (voiceProvider != null) {
        voiceProvider.setEnabled(enabled);
      }
    }
    
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