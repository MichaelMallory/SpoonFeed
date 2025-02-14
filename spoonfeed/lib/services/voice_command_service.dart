import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';  // Add this import for max function

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:picovoice_flutter/picovoice_error.dart';
import 'package:logger/logger.dart';
import '../models/voice_command.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:spoonfeed/services/video_player_service.dart';
import 'package:flutter/widgets.dart';
import '../models/video_transcript.dart';
import './transcript_service.dart';
import '../models/command_intent.dart';
import './command_parser_service.dart';

/// Service for handling voice commands, including recording and processing
class VoiceCommandService extends ChangeNotifier {
  AudioRecorder? _recorder;
  final _functions = FirebaseFunctions.instance;
  final _logger = Logger();
  PorcupineManager? _porcupineManager;
  Timer? _silenceTimer;
  DateTime? _lastAudioActivity;
  String? _currentVideoId;
  
  // Configuration
  static const silenceThreshold = -50.0; // dB
  static const silenceTimeout = Duration(milliseconds: 1500); // Stop after 1.5s of silence
  static const maxRecordingDuration = Duration(seconds: 10); // Maximum total recording time
  
  final stt.SpeechToText _speech = stt.SpeechToText();
  
  bool _isDisposed = false;
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isListeningForWakeWord = false;
  bool _isListeningForCommand = false;
  String? _lastError;
  VoiceCommand? _lastCommand;
  String? _currentSpeech;
  Timer? _commandTimeout;
  static const commandTimeoutDuration = Duration(seconds: 5);

  // Add these new fields
  static const _consecutiveLowAudioThreshold = 5;  // Number of consecutive low audio readings before warning
  int _lowAudioCount = 0;
  DateTime? _lastAudioCheck;
  bool _hasWarnedAboutAudio = false;

  double _currentAudioLevel = -50.0;
  
  // Add new field for video controller
  VideoPlayerController? _videoController;

  // Add this field near the top of the class with other fields
  final String _accessKey = dotenv.env['PICOVOICE_API_KEY'] ?? '';

  final VideoPlayerService _videoPlayerService;
  final TranscriptService _transcriptService = TranscriptService();
  final CommandParserService _commandParserService = CommandParserService();

  // Getters
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isListeningForWakeWord => _isListeningForWakeWord;
  bool get isListeningForCommand => _isListeningForCommand;
  String? get lastError => _lastError;
  VoiceCommand? get lastCommand => _lastCommand;
  String? get currentSpeech => _currentSpeech;
  double get currentAudioLevel => _currentAudioLevel;

  VoiceCommandService(this._videoPlayerService);

  bool _isRecording = false;

  /// Set the current video controller
  void setVideoController(VideoPlayerController? controller) {
    // Only update if the controller has actually changed and we're not disposed
    if (!_isDisposed && _videoController != controller) {
      _logger.i('🎥 Setting video controller in VoiceCommandService');
      _videoController = controller;
      
      if (_videoController != null) {
        _logger.i('🎥 Video controller connected');
        _logger.i('   - Is initialized: ${_videoController!.value.isInitialized}');
        _logger.i('   - Is playing: ${_videoController!.value.isPlaying}');
        _logger.i('   - Position: ${_videoController!.value.position.inSeconds}s');
        if (_videoController!.value.isInitialized) {
          _logger.i('   - Duration: ${_videoController!.value.duration.inSeconds}s');
        }
      } else {
        _logger.i('🎥 Video controller disconnected');
      }
      
      // Schedule the notification for the next frame to avoid build-phase updates
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isDisposed) {
          notifyListeners();
        }
      });
    }
  }

  /// Initialize wake word detection
  Future<void> initializeWakeWord() async {
    try {
      if (_accessKey.isEmpty) {
        throw Exception('Picovoice API key not found in environment variables');
      }

      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        throw Exception('Microphone permission is required');
      }

      // Initialize with keyword file
      final keywordPath = 'assets/keywords/chef_android.ppn';
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        _accessKey,
        [keywordPath],
        _wakeWordCallback,
      );

      await _porcupineManager?.start();
      _isListeningForWakeWord = true;
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Initialize speech recognition
  Future<bool> _initializeSpeech() async {
    if (_isInitialized) return true;

    try {
      _logger.i('🎤 Starting speech recognition initialization...');
      
      // Request microphone permission explicitly
      _logger.i('🎙️ Requesting microphone permission...');
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _logger.e('❌ Microphone permission not granted: ${micStatus.name}');
        _lastError = 'Microphone permission is required for voice commands';
        notifyListeners();
        return false;
      }
      _logger.i('✅ Microphone permission granted');

      // Initialize speech recognition with more detailed error handling
      bool isAvailable = false;
      try {
        _logger.i('🔄 Initializing speech recognition engine...');
        isAvailable = await _speech.initialize(
          onError: (errorNotification) {
            final error = errorNotification.errorMsg;
            _logger.e('❌ Speech recognition error: $error');
            _lastError = 'Speech recognition error: $error';
            
            // Check for specific error conditions
            if (error.contains('error_audio') || error.contains('error_client')) {
              _logger.e('🎤 Audio system error detected');
              _lastError = 'Audio system error. Please check your microphone settings.';
            } else if (error.contains('error_no_match')) {
              _logger.w('⚠️ No speech detected');
              _lastError = 'No speech detected. Please try speaking again.';
            } else if (error.contains('error_network')) {
              _logger.e('🌐 Network error detected');
              _lastError = 'Network error. Please check your internet connection.';
            }
            
            notifyListeners();
          },
          onStatus: (status) {
            _logger.i('📢 Speech recognition status: $status');
            if (status == 'listening') {
              _logger.i('🎙️ Speech recognition is now listening');
              _isListeningForCommand = true;
              notifyListeners();
            } else if (status == 'notListening') {
              _logger.i('🔇 Speech recognition stopped listening');
              _isListeningForCommand = false;
              _currentSpeech = null;
              notifyListeners();
            }
          },
          debugLogging: true,
        );
        
        if (!isAvailable) {
          _logger.e('❌ Speech recognition not available on this device');
          _lastError = 'Speech recognition is not available on this device';
          notifyListeners();
          return false;
        }
        
        _logger.i('✅ Speech recognition initialized successfully');
        _isInitialized = true;
        
        // Configure preferred language
        final locales = await _speech.locales();
        String? preferredLocale;
        
        // Try to find English locale
        for (var locale in locales) {
          if (locale.localeId.startsWith('en')) {
            preferredLocale = locale.localeId;
            _logger.i('🌐 Found preferred locale: $preferredLocale');
            break;
          }
        }
        
        if (preferredLocale == null) {
          _logger.w('⚠️ No English locale found, using default');
          preferredLocale = locales.first.localeId;
        }
        
        _logger.i('🌐 Setting preferred language to: $preferredLocale');
        
        return true;
      } catch (e) {
        _logger.e('❌ Speech recognition initialization error: $e');
        _lastError = 'Failed to initialize speech recognition: $e';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _logger.e('❌ Fatal error during speech initialization: $e');
      _lastError = 'Fatal error during speech initialization: $e';
      notifyListeners();
      return false;
    }
  }

  /// Reset audio monitoring state
  void _resetAudioMonitoring() {
    _lowAudioCount = 0;
    _lastAudioCheck = null;
    _hasWarnedAboutAudio = false;
  }

  /// Monitor audio levels for potential issues
  void _monitorAudioLevel(double level) {
    final now = DateTime.now();
    _lastAudioCheck ??= now;
    _currentAudioLevel = level;  // Update the current audio level

    // Only check every 500ms to avoid too frequent updates
    if (now.difference(_lastAudioCheck!) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastAudioCheck = now;

    _logger.v('🔊 Sound level: $level dB');

    // Track consecutive low audio levels
    if (level < -50) {
      _lowAudioCount++;
      _logger.v('⚠️ Low audio level detected (count: $_lowAudioCount)');
      
      // Warn about potential microphone issues
      if (_lowAudioCount >= _consecutiveLowAudioThreshold && !_hasWarnedAboutAudio) {
        _hasWarnedAboutAudio = true;
        _logger.w('🚨 Possible microphone issue detected - very low audio levels');
        _lastError = 'Microphone may not be working properly. Please check your microphone settings.';
        notifyListeners();
      }
    } else {
      _lowAudioCount = 0;
      _hasWarnedAboutAudio = false;
    }
    
    notifyListeners();  // Notify listeners of audio level change
  }

  /// Callback when wake word is detected
  void _wakeWordCallback(int keywordIndex) async {
    if (_videoController?.value.isPlaying ?? false) {
      await _videoController?.pause();
    }
    // Add any additional wake word handling here
  }

  /// Process the voice command
  Future<void> _processVoiceCommand(String command) async {
    _logger.i('🎯 Processing command: "$command"');
    
    if (_videoController == null || !_videoController!.value.isInitialized) {
      _logger.w('⚠️ No valid video controller available');
      throw Exception('Video controller not available');
    }

    bool commandExecuted = false;
    final startPosition = _videoController!.value.position;
    final videoId = _videoPlayerService.currentVideoId;
    
    _logger.i('🎥 Current video state - ID: $videoId, Position: ${startPosition.inSeconds}s');
    
    try {
      final commandIntent = _commandParserService.parseCommand(command);
      _logger.i('🎯 Parsed command intent: $commandIntent');

      switch (commandIntent.type) {
        case CommandType.play:
          _logger.i('▶️ Attempting to play video');
          await _videoController!.setVolume(1.0);
          await Future.delayed(const Duration(milliseconds: 100));
          await _videoController!.play();
          commandExecuted = true;
          break;

        case CommandType.pause:
          _logger.i('⏸️ Attempting to pause video');
          await _videoController!.pause();
          commandExecuted = true;
          break;

        case CommandType.seek:
        case CommandType.rewind:
        case CommandType.fastForward:
          final seconds = commandIntent.seekSeconds ?? _extractSeconds(command);
          final currentPosition = _videoController!.value.position;
          final newPosition = (commandIntent.seekDirection == SeekDirection.forward || 
                           commandIntent.type == CommandType.fastForward)
              ? currentPosition + Duration(seconds: seconds)
              : currentPosition - Duration(seconds: seconds);
          
          _logger.i('⏩ Attempting to seek from ${currentPosition.inSeconds}s to ${newPosition.inSeconds}s');
          
          try {
            await _videoController!.seekTo(newPosition);
            await Future.delayed(const Duration(milliseconds: 100));
            await _videoController!.play();
            await _videoController!.setVolume(1.0);
            
            // Verify the seek operation
            final actualPosition = _videoController!.value.position;
            _logger.i('✅ Seek complete. Current position: ${actualPosition.inSeconds}s');
            
            commandExecuted = true;
          } catch (e) {
            _logger.e('❌ Error during seek operation: $e');
            throw e;
          }
          break;

        case CommandType.contentSeek:
          if (commandIntent.contentDescription != null) {
            final videoId = _videoPlayerService.currentVideoId;
            _logger.i('🔍 Content seek - Video ID: $videoId, searching for: "${commandIntent.contentDescription}"');
            
            if (videoId != null) {
              try {
                _logger.i('📑 Fetching transcript for video: $videoId');
                final transcript = await _transcriptService.getTranscript(videoId);
                
                if (transcript != null) {
                  _logger.i('✅ Transcript found, searching for: "${commandIntent.contentDescription}"');
                  final matchingSegments = transcript.searchText(commandIntent.contentDescription!);
                  _logger.i('🔍 Found ${matchingSegments.length} matching segments');
                  
                  if (matchingSegments.isNotEmpty) {
                    // Sort segments by start time and pick the first occurrence
                    matchingSegments.sort((a, b) => a.start.compareTo(b.start));
                    final targetSegment = matchingSegments.first;
                    
                    // Seek to slightly before the segment starts
                    final seekPosition = Duration(milliseconds: max(0, targetSegment.start - 500));
                    _logger.i('🎯 Found matching segment at ${seekPosition.inSeconds}s: "${targetSegment.text}"');
                    
                    try {
                      await _videoController!.seekTo(seekPosition);
                      await Future.delayed(const Duration(milliseconds: 100));
                      await _videoController!.play();
                      await _videoController!.setVolume(1.0);
                      _logger.i('✅ Successfully seeked to position and resumed playback');
                      commandExecuted = true;
                    } catch (e) {
                      _logger.e('❌ Error during seek operation: $e');
                      throw e;
                    }
                  } else {
                    _logger.w('⚠️ No matching content found in transcript for: "${commandIntent.contentDescription}"');
                  }
                } else {
                  _logger.w('⚠️ No transcript found for video: $videoId');
                }
              } catch (e) {
                _logger.e('❌ Error during content seek: $e');
                throw e;
              }
            } else {
              _logger.w('⚠️ No current video ID available');
              // Try to restore video state
              await _videoController!.seekTo(startPosition);
              await _videoController!.setVolume(1.0);
              await _videoController!.play();
            }
          }
          break;

        case CommandType.unknown:
          _logger.w('⚠️ Unknown command type');
          break;
      }

      // Log final state after command execution
      _logger.i('📹 Final Video Controller State:');
      _logger.i('   - Is Playing: ${_videoController?.value.isPlaying}');
      _logger.i('   - Position: ${_videoController?.value.position}');
      _logger.i('   - Volume: ${_videoController?.value.volume}');
      _logger.i('   - Video ID: $videoId');

      if (!commandExecuted) {
        _logger.w('⚠️ No valid command executed, restoring previous state');
        await _videoController!.seekTo(startPosition);
        await _videoController!.setVolume(1.0);
        await _videoController!.play();
      }
    } catch (e) {
      _logger.e('❌ Error processing command: $e');
      // Restore original state on error
      await _videoController!.seekTo(startPosition);
      await _videoController!.setVolume(1.0);
      await _videoController!.play();
      throw e;
    }
  }

  /// Extract number of seconds from command text
  int _extractSeconds(String text) {
    final numbers = RegExp(r'\d+').allMatches(text);
    return numbers.isEmpty ? 10 : int.parse(numbers.first.group(0)!);
  }

  static const minCommandDuration = Duration(seconds: 5); // Minimum time to listen for command
  static const maxCommandDuration = Duration(seconds: 10); // Maximum time to listen for command
  
  /// Start recording voice command
  Future<void> startRecording() async {
    _logger.i('🎯 Attempting to start recording...');
    
    try {
      // Initialize speech recognition if needed
      if (!await _initializeSpeech()) {
        _logger.e('❌ Failed to initialize speech recognition');
        _lastError = 'Failed to initialize speech recognition';
        notifyListeners();
        return;
      }

      _isProcessing = true;
      _isListeningForCommand = true;
      _lastError = null;
      _lastCommand = null;
      _currentSpeech = null;
      notifyListeners();
      
      _logger.i('🎤 Starting to listen for command...');
      
      // Set minimum duration timer
      Timer? minDurationTimer;
      bool canEndEarly = false;
      bool commandReceived = false;
      
      minDurationTimer = Timer(minCommandDuration, () {
        _logger.i('✅ Minimum command duration reached, allowing early completion');
        canEndEarly = true;
      });
      
      // Set maximum duration timer
      _commandTimeout?.cancel();
      _commandTimeout = Timer(maxCommandDuration, () {
        _logger.i('⏰ Maximum command duration reached');
        if (!commandReceived && _videoController != null) {
          _logger.i('▶️ No command received, resuming video playback');
          _videoController!.play();
          _videoController!.setVolume(1.0);
        }
        stopRecording();
      });

      // Get available locales
      final locales = await _speech.locales();
      String? preferredLocale;
      
      // Try to find English locale
      for (var locale in locales) {
        if (locale.localeId.startsWith('en')) {
          preferredLocale = locale.localeId;
          break;
        }
      }
      
      bool success = false;
      try {
        success = await _speech.listen(
          localeId: preferredLocale,
          onResult: (result) {
            _logger.i('🎤 Speech recognition result:');
            _logger.i('   Words: "${result.recognizedWords}"');
            _logger.i('   Final: ${result.finalResult}');
            _logger.i('   Confidence: ${result.confidence}');
            
            _currentSpeech = result.recognizedWords;
            
            // Only process final results after minimum duration or if we have a clear command
            if (result.finalResult && (canEndEarly || result.recognizedWords.isNotEmpty)) {
              _logger.i('✅ Final result received');
              if (result.recognizedWords.isNotEmpty) {
                commandReceived = true;
                _lastCommand = VoiceCommand(
                  text: result.recognizedWords,
                  confidence: result.confidence,
                );
                
                // Cancel the minimum duration timer if it's still active
                minDurationTimer?.cancel();
                
                // Process the command and stop recording
                _processVoiceCommand(result.recognizedWords);
              } else {
                _logger.i('⚠️ No speech detected, will resume playback');
              }
              stopRecording();
            }
            
            notifyListeners();
          },
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false, // Don't cancel on error to maintain the listening window
          partialResults: true,
          onSoundLevelChange: (level) {
            _monitorAudioLevel(level);
          },
          onDevice: false,
        );
      } catch (e) {
        _logger.e('❌ Error starting speech recognition: $e');
        success = false;
      }

      if (!success) {
        _logger.e('❌ Failed to start speech recognition');
        minDurationTimer?.cancel();
        if (_videoController != null) {
          _logger.i('▶️ Speech recognition failed, resuming video playback');
          _videoController!.play();
          _videoController!.setVolume(1.0);
        }
        throw Exception('Failed to start speech recognition');
      } else {
        _logger.i('✅ Successfully started listening for speech');
      }
    } catch (e) {
      _logger.e('❌ Failed to start recording: $e');
      _lastError = 'Failed to start recording: $e';
      _isProcessing = false;
      _isListeningForCommand = false;
      notifyListeners();
      
      // Resume video playback before restarting wake word detection
      if (_videoController != null) {
        _logger.i('▶️ Error occurred, resuming video playback');
        _videoController!.play();
        _videoController!.setVolume(1.0);
      }
      
      // Restart wake word detection after a delay
      await Future.delayed(const Duration(milliseconds: 500));
      await startListeningForWakeWord();
    }
  }

  /// Start monitoring audio amplitude for silence detection
  void _startAmplitudeMonitoring() {
    _lastAudioActivity = DateTime.now();
    _silenceTimer?.cancel();
    
    _silenceTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isRecording || _recorder == null) {
        _logger.w('⚠️ Stopping amplitude monitoring: recording=${_isRecording}, recorder=${_recorder != null}');
        timer.cancel();
        return;
      }

      try {
        final amplitude = await _recorder!.getAmplitude();
        final now = DateTime.now();
        
        // Update current level and notify listeners
        _currentAudioLevel = amplitude.current;
        _logger.v('🔊 Current audio level: ${_currentAudioLevel.toStringAsFixed(1)} dB');
        notifyListeners();
        
        if (amplitude.current > silenceThreshold) {
          _lastAudioActivity = now;
        } else if (now.difference(_lastAudioActivity!) > silenceTimeout) {
          _logger.i('🤫 Silence detected, stopping recording...');
          timer.cancel();
          stopRecording();
        }
      } catch (e) {
        _logger.e('❌ Error getting amplitude: $e');
        timer.cancel();
      }
    });
  }

  /// Stop recording
  Future<void> stopRecording() async {
    _logger.i('🛑 Stopping recording...');
    _commandTimeout?.cancel();
    
    try {
      // Stop speech recognition
      await _speech.stop();
      _logger.i('✅ Speech recognition stopped');
    } catch (e) {
      _logger.e('❌ Error stopping speech recognition: $e');
    }
    
    try {
      // Stop audio recording
      await _recorder?.stop();
      _logger.i('✅ Audio recording stopped');
    } catch (e) {
      _logger.e('❌ Error stopping audio recording: $e');
    }
    
    _isListeningForCommand = false;
    _isProcessing = false;
    _isRecording = false;
    notifyListeners();
    
    // Restart wake word detection after a short delay
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_isListeningForWakeWord && !_isListeningForCommand) {
      await _restartWakeWordDetection();
    }
  }

  /// Cancel current recording if any
  Future<void> cancelRecording() async {
    if (_isRecording) {
      await _recorder?.stop();
      _isRecording = false;
      notifyListeners();
    }
  }

  /// Dispose of resources
  @override
  void dispose() {
    _isDisposed = true;
    _silenceTimer?.cancel();
    _recorder?.dispose();
    _porcupineManager?.stop();
    _porcupineManager?.delete();
    _commandTimeout?.cancel();
    _speech.cancel();
    // Don't clear video controller on dispose
    super.dispose();
  }

  /// Clear any error state
  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  /// Get information about the current audio input device
  Future<Map<String, dynamic>> getAudioInputInfo() async {
    try {
      if (_recorder == null) {
        return {
          'error': 'Recorder not initialized',
          'isInitialized': false,
          'currentLevel': _currentAudioLevel,
        };
      }

      final hasPermission = await _recorder!.hasPermission();
      final amplitude = await _recorder!.getAmplitude();
      
      return {
        'name': 'Android Audio Input',  // Default name for Android
        'id': 'default',
        'isInitialized': _isInitialized,
        'hasPermission': hasPermission,
        'sampleRate': 16000,  // Our configured sample rate
        'audioFormat': 'PCM 16-bit',
        'channels': 1,
        'currentLevel': amplitude.current,
      };
    } catch (e) {
      _logger.e('Failed to get audio input info: $e');
      return {
        'error': 'Failed to get device info: $e',
        'isInitialized': _isInitialized,
        'currentLevel': _currentAudioLevel,
      };
    }
  }

  /// Set the current video ID
  void setCurrentVideoId(String? videoId) {
    _logger.i('🎥 Setting current video ID in VoiceCommandService: $videoId');
    if (_currentVideoId != videoId) {
      _currentVideoId = videoId;
      notifyListeners();
    }
  }

  /// Helper method to safely restart wake word detection
  Future<void> _restartWakeWordDetection() async {
    _logger.i('🔄 Restarting wake word detection');
    
    try {
      // Ensure proper cleanup
      await _porcupineManager?.stop();
      _porcupineManager = null;
      await _speech.stop();
      
      // Reset all state flags
      _isListeningForWakeWord = false;
      _isListeningForCommand = false;
      _isProcessing = false;
      _currentSpeech = null;
      _lastError = null;
      
      // Cancel any pending timers
      _commandTimeout?.cancel();
      _silenceTimer?.cancel();
      
      // Wait for state to settle
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (_isDisposed) return;

      // Initialize fresh instance of wake word detection
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        _accessKey,
        ['assets/keywords/chef_android.ppn'],
        _handleWakeWordDetected,
      );

      await _porcupineManager?.start();
      _isListeningForWakeWord = true;
      notifyListeners();
      
      _logger.i('✅ Successfully restarted wake word detection');
    } catch (e) {
      _logger.e('❌ Error restarting wake word detection: $e');
      _lastError = 'Failed to restart wake word detection';
      
      // Try again after a longer delay if not disposed
      if (!_isDisposed) {
        await Future.delayed(const Duration(seconds: 2));
        await startListeningForWakeWord();
      }
    }
  }

  /// Start listening for wake word
  Future<void> startListeningForWakeWord() async {
    if (_isDisposed) return;

    try {
      if (_porcupineManager != null) {
        await _porcupineManager!.stop();
        _porcupineManager = null;
      }

      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      _porcupineManager = await PorcupineManager.fromKeywordPaths(
        _accessKey,
        ['assets/keywords/chef_android.ppn'],
        _handleWakeWordDetected,
      );

      await _porcupineManager?.start();
      _isListeningForWakeWord = true;
      _lastError = null;
      notifyListeners();
    } catch (error) {
      _lastError = 'Error starting wake word detection: $error';
      _isListeningForWakeWord = false;
      notifyListeners();
      
      // Retry after a delay
      if (!_isDisposed) {
        await Future.delayed(const Duration(seconds: 5));
        await startListeningForWakeWord();
      }
    }
  }

  Future<void> _handleWakeWordDetected(int keywordIndex) async {
    if (_isDisposed) return;
    
    try {
      _logger.i('🎯 Wake word "hey chef" detected');
      
      // Stop wake word detection immediately
      await _porcupineManager?.stop();
      _isListeningForWakeWord = false;
      
      // Ensure we have a valid video controller
      if (_videoController == null || !_videoController!.value.isInitialized) {
        _logger.w('⚠️ No valid video controller available');
        throw Exception('Video controller not available');
      }
      
      // Store current video state
      final wasPlaying = _videoController!.value.isPlaying;
      final currentPosition = _videoController!.value.position;
      
      _logger.i('📹 Current video state - Playing: $wasPlaying, Position: ${currentPosition.inSeconds}s');
      
      // Pause video immediately when wake word is detected
      if (wasPlaying) {
        _logger.i('⏸️ Attempting to pause video and mute audio');
        try {
          await _videoController!.pause();
          await Future.delayed(const Duration(milliseconds: 100));
          await _videoController!.setVolume(0.0);
          
          // Verify the pause state
          if (_videoController!.value.isPlaying) {
            _logger.w('⚠️ Video failed to pause, retrying...');
            await _videoController!.pause();
          }
          
          _logger.i('✅ Video paused successfully');
        } catch (e) {
          _logger.e('❌ Error pausing video: $e');
          throw e;
        }
      }

      // Start listening for command
      _isListeningForCommand = true;
      notifyListeners();

      // Initialize speech recognition
      bool isInitialized = await _initializeSpeech();
      if (!isInitialized) {
        throw Exception('Failed to initialize speech recognition');
      }

      // Set up command timeout
      _commandTimeout?.cancel();
      _commandTimeout = Timer(const Duration(seconds: 5), () async {
        if (_videoController != null && wasPlaying) {
          _logger.i('⚠️ No command received within timeout, resuming playback');
          try {
            await _videoController!.setVolume(1.0);
            await _videoController!.seekTo(currentPosition);
            await _videoController!.play();
            _logger.i('✅ Playback resumed at ${currentPosition.inSeconds}s');
          } catch (e) {
            _logger.e('❌ Error resuming playback: $e');
          }
        }
        
        // Reset state and restart wake word detection
        _isListeningForCommand = false;
        notifyListeners();
        await _restartWakeWordDetection();
      });
      
      // Start listening for speech
      await _speech.listen(
        onResult: (result) async {
          if (result.finalResult) {
            _isListeningForCommand = false;
            notifyListeners();
            
            // Process the voice command
            final command = result.recognizedWords.toLowerCase();
            if (command.isNotEmpty) {
              _logger.i('🎯 Processing command: "$command"');
              try {
                await _processVoiceCommand(command);
                _logger.i('✅ Command processed successfully');
              } catch (e) {
                _logger.e('❌ Error processing command: $e');
                // Restore original state on error
                if (wasPlaying && _videoController != null) {
                  await _videoController!.setVolume(1.0);
                  await _videoController!.seekTo(currentPosition);
                  await _videoController!.play();
                }
              }
            } else {
              _logger.w('⚠️ Empty command received');
              // Restore original state
              if (wasPlaying && _videoController != null) {
                await _videoController!.setVolume(1.0);
                await _videoController!.seekTo(currentPosition);
                await _videoController!.play();
              }
            }
            
            // Clean up and restart wake word detection
            _commandTimeout?.cancel();
            await _speech.stop();
            await _restartWakeWordDetection();
          }
        },
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        partialResults: true,
      );
    } catch (error) {
      _logger.e('Error handling wake word detection: $error');
      // Attempt to restore video state
      if (_videoController != null) {
        try {
          await _videoController!.setVolume(1.0);
          await _videoController!.play();
          _logger.i('✅ Video state restored after error');
        } catch (e) {
          _logger.e('❌ Error restoring video state: $e');
        }
      }
      
      // Reset state
      _isListeningForCommand = false;
      notifyListeners();
      
      // Restart wake word detection
      await _restartWakeWordDetection();
    }
  }
} 