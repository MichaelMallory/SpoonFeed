import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerService extends ChangeNotifier {
  VideoPlayerController? _controller;
  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;
  VideoPlayerController? get controller => _controller;

  void setController(VideoPlayerController? controller) {
    if (_controller != controller) {
      _controller = controller;
      notifyListeners();
    }
  }

  void play() {
    if (_controller?.value.isInitialized ?? false) {
      _controller?.play();
      _isPlaying = true;
      notifyListeners();
    }
  }

  void pause() {
    if (_controller?.value.isInitialized ?? false) {
      _controller?.pause();
      _isPlaying = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }
} 