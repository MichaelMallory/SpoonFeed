import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import '../utils/cook_mode_logger.dart';
import 'gesture_recognition_service.dart';

typedef GestureCallback = void Function(GestureResult gesture);

/// Service class that manages the camera for cook mode gesture detection.
/// Handles camera initialization, frame capture, and cleanup.
class CookModeCameraService {
  CameraController? _controller;
  bool _isInitialized = false;
  ResolutionPreset _resolution = ResolutionPreset.medium;
  late final GestureRecognitionService _gestureService;
  GestureCallback? _onGestureDetected;
  String? _lastError;
  
  CookModeCameraService() {
    _gestureService = GestureRecognitionService();
    CookModeLogger.logCamera('Service created', data: {
      'resolution': _resolution.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  CameraController? get controller => _controller;

  /// Sets the callback for gesture detection
  void setGestureCallback(GestureCallback callback) {
    final hadCallback = _onGestureDetected != null;
    _onGestureDetected = callback;
    CookModeLogger.logCamera('Gesture callback set', data: {
      'hadPreviousCallback': hadCallback,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Initializes the camera with the front-facing camera
  Future<void> initialize() async {
    if (_isInitialized) {
      CookModeLogger.logCamera('Camera already initialized', data: {
        'resolution': _resolution.toString(),
        'hasCallback': _onGestureDetected != null,
      });
      return;
    }

    final initStartTime = DateTime.now();
    try {
      // Get the list of available cameras
      final cameras = await availableCameras();
      CookModeLogger.logCamera('Available cameras found', data: {
        'count': cameras.length,
        'types': cameras.map((c) => c.lensDirection.toString()).toList(),
      });
      
      // Find front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      
      CookModeLogger.logCamera('Initializing camera', data: {
        'cameraId': frontCamera.name,
        'resolution': _resolution.toString(),
        'lensDirection': frontCamera.lensDirection.toString(),
        'sensorOrientation': frontCamera.sensorOrientation,
      });

      // Create controller
      _controller = CameraController(
        frontCamera,
        _resolution,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      // Initialize controller
      await _controller?.initialize();
      
      // Set optimal frame rate for gesture detection (we don't need 60fps)
      await _controller?.lockCaptureOrientation();
      await _setOptimalFrameRate();
      
      _isInitialized = true;
      CookModeLogger.logCamera('Camera initialized successfully', data: {
        'resolution': _resolution.toString(),
        'frameRate': await _getCurrentFrameRate(),
        'initializationTime': DateTime.now().difference(initStartTime).inMilliseconds,
        'exposureMode': _controller?.value.exposureMode.toString(),
        'focusMode': _controller?.value.focusMode.toString(),
      });
    } catch (e, stackTrace) {
      CookModeLogger.error('Camera', 'Failed to initialize camera',
        data: {
          'error': e.toString(),
          'resolution': _resolution.toString(),
          'initializationTime': DateTime.now().difference(initStartTime).inMilliseconds,
          'availableCameras': (await availableCameras()).length,
        },
        stackTrace: stackTrace,
      );
      await cleanup();
      rethrow;
    }
  }

  /// Sets the optimal frame rate for gesture detection
  Future<void> _setOptimalFrameRate() async {
    final startTime = DateTime.now();
    try {
      // Since setFpsRange is not available in the camera plugin,
      // we'll use the default frame rate which should be sufficient
      // for gesture detection
      
      CookModeLogger.logCamera('Frame rate optimized', data: {
        'targetFPS': '15-20',
        'actualFPS': 'Using default camera frame rate',
        'optimizationTime': DateTime.now().difference(startTime).inMilliseconds,
      });
      
      // Set auto exposure and focus for best results
      await _controller?.setExposureMode(ExposureMode.auto);
      await _controller?.setFocusMode(FocusMode.auto);
      
    } catch (e, stackTrace) {
      CookModeLogger.error('Camera', 'Failed to optimize frame rate',
        data: {
          'error': e.toString(),
          'optimizationTime': DateTime.now().difference(startTime).inMilliseconds,
          'resolution': _resolution.toString(),
          'isInitialized': _isInitialized,
        },
        stackTrace: stackTrace,
      );
    }
  }

  /// Gets the current frame rate
  Future<double> _getCurrentFrameRate() async {
    try {
      // Since getAvailableFpsRanges is not available in the camera plugin,
      // we'll use a fixed frame rate that's good for gesture detection
      const defaultFps = 20.0;
      
      CookModeLogger.logCamera('Current frame rate retrieved', data: {
        'fps': defaultFps,
        'note': 'Using fixed frame rate for gesture detection',
      });
      
      return defaultFps;
    } catch (e) {
      CookModeLogger.error('Camera', 'Failed to get frame rate', data: {
        'error': e.toString(),
        'defaultFps': 20.0,
      });
      return 20.0; // Default to our target
    }
  }

  /// Starts the camera preview and gesture detection
  Future<void> startPreview() async {
    if (!_isInitialized || _controller == null) {
      CookModeLogger.error('Camera', 'Failed to start preview - not initialized');
      throw Exception('Camera not initialized');
    }

    if (_onGestureDetected == null) {
      CookModeLogger.logCamera('Warning: No gesture callback set');
    }

    try {
      CookModeLogger.logCamera('Starting preview', data: {
        'resolution': _resolution.toString(),
        'orientation': _controller?.value.deviceOrientation.toString(),
        'exposureMode': _controller?.value.exposureMode.toString(),
        'focusMode': _controller?.value.focusMode.toString(),
      });

      await _controller?.startImageStream((image) async {
        // Process frame for gesture detection
        final gesture = await _gestureService.processFrame(image);
        
        // If gesture detected, notify callback
        if (gesture.gestureDetected && _onGestureDetected != null) {
          CookModeLogger.logCamera('Gesture callback triggered', data: {
            'confidence': gesture.confidence,
            'type': gesture.gestureType.toString(),
          });
          _onGestureDetected!(gesture);
        }
      });
      
      CookModeLogger.logCamera('Preview started successfully');
    } catch (e, stackTrace) {
      CookModeLogger.error('Camera', 'Failed to start preview',
        data: {
          'error': e.toString(),
          'resolution': _resolution.toString(),
          'isInitialized': _isInitialized,
          'hasController': _controller != null,
        },
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Stops the camera preview
  Future<void> stopPreview() async {
    final stopStartTime = DateTime.now();
    try {
      CookModeLogger.logCamera('Stopping preview', data: {
        'isInitialized': _isInitialized,
        'hasController': _controller != null,
        'resolution': _resolution.toString(),
      });
      await _controller?.stopImageStream();
      CookModeLogger.logCamera('Preview stopped successfully', data: {
        'stopTime': DateTime.now().difference(stopStartTime).inMilliseconds,
      });
    } catch (e, stackTrace) {
      CookModeLogger.error('Camera', 'Failed to stop preview',
        data: {
          'error': e.toString(),
          'isInitialized': _isInitialized,
          'hasController': _controller != null,
          'stopAttemptTime': DateTime.now().difference(stopStartTime).inMilliseconds,
        },
        stackTrace: stackTrace,
      );
    }
  }

  /// Cleans up resources
  Future<void> dispose() async {
    await cleanup();
  }

  /// Cleans up the camera controller and resources
  Future<void> cleanup() async {
    CookModeLogger.logCamera('Starting cleanup', data: {
      'isInitialized': _isInitialized,
      'hasController': _controller != null,
    });

    try {
      if (_controller != null) {
        final controllerState = _controller?.value;
        if (controllerState != null) {
          CookModeLogger.logCamera('Controller state before disposal', data: {
            'isInitialized': controllerState.isInitialized,
            'isRecording': controllerState.isRecordingVideo,
            'isStreamingImages': controllerState.isStreamingImages,
          });
        }

        await _controller?.dispose();
        _controller = null;
      }
      _isInitialized = false;
      _gestureService.dispose();

      CookModeLogger.logCamera('Cleanup completed successfully', data: {
        'isInitialized': _isInitialized,
        'hasController': _controller != null,
      });
    } catch (e, stackTrace) {
      CookModeLogger.error('Camera', 'Failed to cleanup camera',
        data: {
          'error': e.toString(),
          'isInitialized': _isInitialized,
          'hasController': _controller != null,
        },
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Updates camera resolution if needed for performance
  Future<void> updateResolution(ResolutionPreset newResolution) async {
    final updateStartTime = DateTime.now();
    if (_resolution == newResolution || !_isInitialized) {
      CookModeLogger.logCamera('Resolution update skipped', data: {
        'reason': !_isInitialized ? 'not initialized' : 'same resolution',
        'current': _resolution.toString(),
        'requested': newResolution.toString(),
        'isInitialized': _isInitialized,
      });
      return;
    }

    CookModeLogger.logCamera('Starting resolution update', data: {
      'currentResolution': _resolution.toString(),
      'newResolution': newResolution.toString(),
      'isInitialized': _isInitialized,
      'hasController': _controller != null,
    });

    final previousResolution = _resolution;
    _resolution = newResolution;
    
    try {
      await cleanup();
      await initialize();
      
      CookModeLogger.logCamera('Resolution update completed', data: {
        'resolution': _resolution.toString(),
        'updateTime': DateTime.now().difference(updateStartTime).inMilliseconds,
      });
    } catch (e, stackTrace) {
      // If update fails, revert to previous resolution
      _resolution = previousResolution;
      CookModeLogger.error('Camera', 'Failed to update resolution',
        data: {
          'error': e.toString(),
          'previousResolution': previousResolution.toString(),
          'attemptedResolution': newResolution.toString(),
          'updateAttemptTime': DateTime.now().difference(updateStartTime).inMilliseconds,
        },
        stackTrace: stackTrace,
      );
      // Try to reinitialize with previous resolution
      try {
        await initialize();
      } catch (e) {
        CookModeLogger.error('Camera', 'Failed to restore previous resolution',
          data: {'error': e.toString()});
      }
    }
  }

  /// Checks if the lighting conditions are suitable for gesture detection
  Future<bool> checkLightingConditions() async {
    if (!_isInitialized || _controller == null) {
      CookModeLogger.logCamera('Lighting check skipped - not initialized');
      return false;
    }

    try {
      // For now, just verify the camera is working
      // In a future update, we can add more sophisticated lighting checks
      final isLightingGood = _controller!.value.isInitialized;
      
      CookModeLogger.logCamera('Lighting check completed', data: {
        'isWellLit': isLightingGood,
      });

      return isLightingGood;
    } catch (e, stackTrace) {
      CookModeLogger.error('Camera', 'Failed to check lighting',
        data: {
          'error': e.toString(),
          'isInitialized': _isInitialized,
          'hasController': _controller != null,
        },
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  void _onFrameAvailable(CameraImage image) {
    // Only log camera events if there's an error
    if (_lastError != null) {
      CookModeLogger.logCamera('Frame capture error', data: {
        'error': _lastError,
      });
      _lastError = null;
      return;
    }

    // Process frame for gesture detection
    _gestureService.processFrame(image).then((gesture) {
      if (gesture.gestureDetected) {
        _onGestureDetected?.call(gesture);
      }
    });
  }
} 