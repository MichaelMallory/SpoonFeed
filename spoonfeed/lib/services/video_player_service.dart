import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:logger/logger.dart';

class VideoPlayerService extends ChangeNotifier {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  String? _currentVideoId;
  final Logger _logger = Logger();

  bool get isPlaying => _isPlaying;
  VideoPlayerController? get controller => _controller;
  String? get currentVideoId => _currentVideoId;

  void setController(VideoPlayerController? controller, {String? videoId}) {
    _logger.i('🎥 Setting video controller - Video ID: $videoId');
    
    // Always update controller if it's different
    if (_controller != controller) {
      // Clean up old controller
      if (_controller != null) {
        _controller?.removeListener(_updatePlayingState);
      }
      
      // Set new controller
      _controller = controller;
      
      // Add listener to new controller
      if (_controller != null) {
        _controller?.addListener(_updatePlayingState);
        _isPlaying = _controller?.value.isPlaying ?? false;
      } else {
        _isPlaying = false;
      }
    }
    
    // Always update video ID if provided
    if (videoId != null) {
      _currentVideoId = videoId;
      _logger.i('🎥 Updated current video ID: $videoId');
    }
    
    // Ensure state is consistent
    _updatePlayingState();
    notifyListeners();
  }

  void setCurrentVideoId(String? videoId) {
    if (_currentVideoId != videoId) {
      _logger.i('🎥 Setting current video ID: $videoId');
      _currentVideoId = videoId;
      notifyListeners();
    }
  }

  void _updatePlayingState() {
    if (_controller != null) {
      final isNowPlaying = _controller?.value.isPlaying ?? false;
      if (_isPlaying != isNowPlaying) {
        _isPlaying = isNowPlaying;
        notifyListeners();
      }
    }
  }

  Future<void> play() async {
    if (_controller?.value.isInitialized ?? false) {
      await _controller?.play();
      _isPlaying = true;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_controller?.value.isInitialized ?? false) {
      await _controller?.pause();
      _isPlaying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_updatePlayingState);
    _controller = null;
    super.dispose();
  }
} 