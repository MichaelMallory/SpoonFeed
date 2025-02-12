import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/voice_command_service.dart';
import '../services/command_parser_service.dart';
import '../services/transcript_service.dart';
import '../models/voice_command.dart';
import '../models/command_intent.dart';
import '../models/video_transcript.dart';
import 'dart:async';

/// Provider for managing voice control state and video player integration
class VoiceControlProvider extends ChangeNotifier {
  final VoiceCommandService _voiceService;
  final CommandParserService _commandParser;
  final TranscriptService _transcriptService;
  final _logger = Logger();
  VideoPlayerController? _videoController;
  String? _currentVideoId;
  bool _isEnabled = false;
  bool _isListening = false;
  String? _feedbackMessage;
  bool _hasPermission = false;
  String? _currentSpeech; // Track current speech being recognized

  VoiceControlProvider(this._voiceService)
      : _commandParser = CommandParserService(),
        _transcriptService = TranscriptService() {
    // Listen to voice service state changes
    _voiceService.addListener(_onVoiceServiceUpdate);
    _checkPermission();
  }

  // Getters
  bool get isEnabled => _isEnabled;
  bool get isListening => _voiceService.isListeningForCommand;
  bool get isProcessing => _voiceService.isProcessing;
  bool get isListeningForWakeWord => _voiceService.isListeningForWakeWord;
  bool get isListeningForCommand => _voiceService.isListeningForCommand;
  String? get feedbackMessage => _feedbackMessage;
  VideoPlayerController? get videoController => _videoController;
  bool get hasPermission => _hasPermission;
  String? get currentSpeech => _voiceService.currentSpeech;

  /// Check microphone permission
  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    _hasPermission = status.isGranted;
    _updateFeedbackMessage();
    notifyListeners();
  }

  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    _hasPermission = status.isGranted;
    _updateFeedbackMessage();
    notifyListeners();
    return _hasPermission;
  }

  /// Set the video controller and ID to control
  void setVideo(VideoPlayerController? controller, String? videoId) {
    // If we're just updating to a new video, preserve the old ID
    if (controller != null && _videoController != null) {
      _currentVideoId = videoId ?? _currentVideoId;
    } else {
      _currentVideoId = videoId;
    }
    _videoController = controller;
    
    // Update voice service if needed
    if (_voiceService != null) {
      _voiceService.setVideoController(controller);
    }
    
    notifyListeners();
  }

  /// Enable or disable voice control
  Future<void> setEnabled(bool enabled) async {
    if (enabled && !_hasPermission) {
      final granted = await requestPermission();
      if (!granted) {
        _feedbackMessage = 'Microphone permission required for voice control';
        notifyListeners();
        return;
      }
    }

    _isEnabled = enabled;
    if (enabled) {
      await _voiceService.startListeningForWakeWord();
      _feedbackMessage = 'Listening for "Chef"...';
    } else {
      // Don't clear video controller when disabling voice mode
      await _voiceService.stopRecording();
      _feedbackMessage = null;
    }
    notifyListeners();
  }

  /// Update feedback message based on current state
  void _updateFeedbackMessage() {
    if (!_hasPermission) {
      _feedbackMessage = 'Microphone permission required';
    } else if (!_isEnabled) {
      _feedbackMessage = null;
    } else if (_voiceService.isListeningForCommand) {
      _feedbackMessage = 'Listening for command...';
    } else if (_voiceService.isListeningForWakeWord) {
      _feedbackMessage = 'Listening for "Chef"...';
    } else if (_voiceService.isProcessing) {
      _feedbackMessage = 'Processing...';
    }
  }

  /// Process a voice command and control video playback
  Future<void> _processCommand(VoiceCommand command) async {
    if (_videoController == null) {
      _logger.w('❌ No video controller available');
      return;
    }

    final text = command.text.toLowerCase();
    _logger.i('🎤 Processing voice command: "$text"');
    _feedbackMessage = 'Processing: $text';
    notifyListeners();

    bool shouldResumePlayback = false;
    bool commandExecuted = false;  // Track if a valid command was executed
    
    try {
      // Parse and execute the command
      final intent = _commandParser.parseCommand(text);
      _logger.i('🎯 Parsed intent: ${intent.type}');

      switch (intent.type) {
        case CommandType.play:
          await _videoController!.play();
          await _videoController!.setVolume(1.0);
          _feedbackMessage = 'Playing video';
          commandExecuted = true;
          break;
        case CommandType.pause:
          await _videoController!.pause();
          _feedbackMessage = 'Video paused';
          commandExecuted = true;
          break;
        case CommandType.seek:
          if (intent.seekDirection != null && intent.seekSeconds != null) {
            final seconds = intent.seekSeconds! * (intent.seekDirection == SeekDirection.backward ? -1 : 1);
            final position = _videoController!.value.position + Duration(seconds: seconds);
            await _videoController!.seekTo(position);
            shouldResumePlayback = _videoController!.value.isPlaying;
            _feedbackMessage = 'Seeking ${intent.seekDirection == SeekDirection.backward ? 'backward' : 'forward'} ${intent.seekSeconds} seconds';
            commandExecuted = true;
          }
          break;
        case CommandType.contentSeek:
          if (intent.contentDescription != null) {
            await _seekToContent(intent.contentDescription!);
            commandExecuted = true;
          }
          break;
        case CommandType.rewind:
          final position = _videoController!.value.position - const Duration(seconds: 10);
          await _videoController!.seekTo(position);
          shouldResumePlayback = _videoController!.value.isPlaying;
          _feedbackMessage = 'Rewound 10 seconds';
          commandExecuted = true;
          break;
        case CommandType.fastForward:
          final position = _videoController!.value.position + const Duration(seconds: 10);
          await _videoController!.seekTo(position);
          shouldResumePlayback = _videoController!.value.isPlaying;
          _feedbackMessage = 'Fast forwarded 10 seconds';
          commandExecuted = true;
          break;
        case CommandType.unknown:
          _feedbackMessage = 'Sorry, I didn\'t understand that command';
          break;
      }

      // Resume playback if we were playing before or if no valid command was executed
      if (shouldResumePlayback || !commandExecuted) {
        await _videoController!.setVolume(1.0);
        await _videoController!.play();
        if (!commandExecuted) {
          _feedbackMessage = 'No valid command given, resuming video';
        }
      }
      
      notifyListeners();
    } catch (e) {
      _logger.e('❌ Command execution error: $e');
      _feedbackMessage = 'Error executing command';
      
      // Resume video playback on error
      if (_videoController != null) {
        await _videoController!.setVolume(1.0);
        await _videoController!.play();
      }
      
      notifyListeners();
    }
  }

  /// Handle wake word detection by pausing video and preparing for command
  void _handleWakeWord() async {
    if (_videoController != null) {
      if (_videoController!.value.isPlaying) {
        _logger.i('⏸️ Pausing video for voice command');
        await _videoController!.pause();
        // Mute video during command listening
        await _videoController!.setVolume(0.0);
      }
    }
    _feedbackMessage = 'Listening for command...';
    notifyListeners();

    // Set up a timer to resume video if no command is given
    Timer(const Duration(seconds: 5), () async {
      if (_videoController != null && 
          !_videoController!.value.isPlaying && 
          !_voiceService.isProcessing) {
        _logger.i('▶️ No command given, resuming video');
        await _videoController!.setVolume(1.0);
        await _videoController!.play();
        notifyListeners();
      }
    });
  }

  /// Seek to content matching the description
  Future<void> _seekToContent(String contentDescription) async {
    if (_currentVideoId == null || _videoController == null) {
      _logger.w('❌ Cannot seek: No video ID or controller');
      return;
    }

    try {
      _logger.i('🔍 Searching transcript for: "$contentDescription"');
      final transcript = await _transcriptService.getTranscript(_currentVideoId!);
      
      if (transcript == null) {
        _feedbackMessage = 'Sorry, I couldn\'t find a transcript for this video';
        _logger.w('❌ No transcript found for video: $_currentVideoId');
        return;
      }

      _logger.i('📝 Found transcript, searching for matches...');
      final matches = transcript.searchText(contentDescription);
      _logger.i('✨ Found ${matches.length} matches');
      
      if (matches.isEmpty) {
        _feedbackMessage = 'Sorry, I couldn\'t find that part in the video';
        _logger.w('❌ No matches found for: "$contentDescription"');
        return;
      }

      // For now, just use the first match
      final segment = matches.first;
      _logger.i('✅ Using match: "${segment.text}" at ${segment.start}ms');

      // Seek to the start of the segment
      final position = Duration(milliseconds: segment.start);
      _logger.i('⏩ Seeking to ${position.inSeconds}s');
      await _videoController!.seekTo(position);
      _feedbackMessage = 'Found it! Playing from matching part';
      
      // Start playing from the found segment
      await _videoController!.play();
      _logger.i('▶️ Started playback');
    } catch (e) {
      _feedbackMessage = 'Sorry, there was an error finding that part';
      _logger.e('❌ Error during content seek: $e');
    }
  }

  /// Handle voice service updates
  void _onVoiceServiceUpdate() {
    // Update feedback message based on current state
    _updateFeedbackMessage();

    // Handle command completion
    if (_voiceService.lastCommand != null && !_voiceService.isListeningForCommand) {
      _processCommand(_voiceService.lastCommand!);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _voiceService.removeListener(_onVoiceServiceUpdate);
    super.dispose();
  }
} 