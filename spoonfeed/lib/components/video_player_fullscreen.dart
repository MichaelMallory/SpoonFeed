import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import '../models/video_model.dart';
import '../services/video/video_service.dart';
import 'comments_sheet.dart';
import 'share_sheet.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import '../services/cookbook_service.dart';
import 'package:provider/provider.dart';
import '../models/cookbook_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/cook_mode_provider.dart';
import 'cook_mode/cook_mode_button.dart';
import 'cook_mode/camera_preview_overlay.dart';
import '../providers/voice_control_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:collection';
import '../utils/texture_painter.dart';
import 'package:logger/logger.dart';

/// Widget that shows voice recognition feedback
class VoiceFeedbackOverlay extends StatelessWidget {
  const VoiceFeedbackOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceControlProvider>(
      builder: (context, provider, _) {
        if (!provider.isEnabled) return const SizedBox.shrink();

        // Get the current state text and icon
        IconData stateIcon;
        Color iconColor;
        String stateText;
        
        if (provider.isListeningForCommand) {
          stateIcon = Icons.mic;
          iconColor = Colors.red;
          stateText = 'Listening for command...';
        } else if (provider.isProcessing) {
          stateIcon = Icons.settings;
          iconColor = Colors.orange;
          stateText = 'Processing command...';
        } else if (provider.isListeningForWakeWord) {
          stateIcon = Icons.mic_none;
          iconColor = Colors.blue;
          stateText = 'Listening for "Chef"...';
        } else {
          return const SizedBox.shrink();
        }

        return Positioned(
          left: 16,
          right: 16,
          bottom: 100,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: provider.isListeningForCommand ? Colors.red.withOpacity(0.3) : Colors.white.withOpacity(0.1),
                width: provider.isListeningForCommand ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // State indicator with pulsing animation
                Row(
                  children: [
                    _buildPulsingIcon(
                      icon: stateIcon,
                      color: iconColor,
                      shouldPulse: provider.isListeningForCommand,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      stateText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                // Show current speech if available
                if (provider.currentSpeech?.isNotEmpty == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Heard: "${provider.currentSpeech}"',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                
                // Show feedback message if available
                if (provider.feedbackMessage?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    provider.feedbackMessage!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12,
                    ),
                  ),
                ],
                
                // Show processing indicator
                if (provider.isProcessing)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Processing command...',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
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

  Widget _buildPulsingIcon({
    required IconData icon,
    required Color color,
    required bool shouldPulse,
  }) {
    if (!shouldPulse) {
      return Icon(
        icon,
        color: color,
        size: 20,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.2),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        );
      },
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }
}

class VideoPlayerFullscreen extends StatefulWidget {
  final VideoModel video;
  final bool isActive;
  final bool shouldPreload;
  final bool isGameMode;
  final VoidCallback onRetry;

  const VideoPlayerFullscreen({
    Key? key,
    required this.video,
    required this.isActive,
    this.shouldPreload = false,
    this.isGameMode = false,
    required this.onRetry,
  }) : super(key: key);

  @override
  _VideoPlayerFullscreenState createState() => _VideoPlayerFullscreenState();
}

class _VideoPlayerFullscreenState extends State<VideoPlayerFullscreen> with AutomaticKeepAliveClientMixin, RouteAware {
  final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
    ),
  );
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  final VideoService _videoService = VideoService();
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  int _shareCount = 0;
  bool _hasError = false;
  bool _isCancelled = false;
  static int _activeControllers = 0;
  static const int MAX_ACTIVE_CONTROLLERS = 3;
  late final RouteObserver<ModalRoute<void>> _routeObserver;
  bool _isPreloaded = false;
  bool _isDisposed = false;
  int _retryCount = 0;
  Timer? _bufferingTimer;
  static final Queue<String> _initializationQueue = Queue<String>();
  static bool _isProcessingQueue = false;

  @override
  bool get wantKeepAlive => widget.isActive || widget.shouldPreload;

  @override
  void initState() {
    super.initState();
    _routeObserver = RouteObserver<ModalRoute<void>>();
    print('\n[VideoPlayer] 🎬 Initializing player for video: ${widget.video.id}');
    print('  - Is active: ${widget.isActive}');
    print('  - Should preload: ${widget.shouldPreload}');
    print('  - Route observer: ${_routeObserver.hashCode}');
    
    // Initialize immediately if active, regardless of route
    if (widget.isActive) {
      _initializeVideo(highPriority: true);
    } else if (widget.shouldPreload) {
      _addToInitializationQueue();
    }
    _initializeMetadata();

    // Connect to providers after a frame to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _connectToProviders();
      }
    });
  }

  void _connectToProviders() {
    print('\n[VideoPlayer] 🔌 Attempting to connect providers:');
    print('  - Is mounted: $mounted');
    print('  - Has controller: ${_controller != null}');
    print('  - Controller initialized: ${_controller?.value.isInitialized}');
    print('  - Video ID: ${widget.video.id}');

    if (!mounted || _controller == null) {
      print('  ❌ Cannot connect - widget not mounted or no controller');
      return;
    }

    // Connect to cook mode provider for gesture control
    final cookModeProvider = Provider.of<CookModeProvider>(context, listen: false);
    cookModeProvider.setVideo(_controller, widget.video.id);

    // Connect to voice control provider
    final voiceControlProvider = Provider.of<VoiceControlProvider>(context, listen: false);
    voiceControlProvider.setVideo(_controller, widget.video.id);

    print('\n[VideoPlayer] ✅ Connected to control providers:');
    print('  - Video ID: ${widget.video.id}');
    print('  - Cook mode active: ${cookModeProvider.isActive}');
    print('  - Voice control enabled: ${voiceControlProvider.isEnabled}');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Always unsubscribe before subscribing to avoid duplicate subscriptions
    _routeObserver.unsubscribe(this);
    
    final modalRoute = ModalRoute.of(context);
    if (modalRoute != null) {
      print('\n[VideoPlayer] 🔄 Subscribing to route: ${modalRoute.settings.name}');
      _routeObserver.subscribe(this, modalRoute);
    }
  }

  @override
  void didPushNext() {
    print('\n[VideoPlayer] 📱 Route pushed on top: ${widget.video.id}');
    // Pause but don't cleanup when pushing new route
    if (widget.isActive) {
      _pauseVideo();
    }
  }

  @override
  void didPopNext() {
    print('\n[VideoPlayer] 📱 Returning to route: ${widget.video.id}');
    // Resume playback if active
    if (widget.isActive) {
      if (!_isInitialized) {
        _initializeVideo(highPriority: true);
      } else {
        _playVideo();
      }
    }
  }

  @override
  void didUpdateWidget(VideoPlayerFullscreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    print('\n[VideoPlayer] 🔄 Widget updated for video: ${widget.video.id}');
    print('  - Old active: ${oldWidget.isActive}');
    print('  - New active: ${widget.isActive}');
    print('  - Old preload: ${oldWidget.shouldPreload}');
    print('  - New preload: ${widget.shouldPreload}');
    
    // Handle active state changes
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        if (!_isInitialized && !_isPreloaded) {
          _initializeVideo(highPriority: true);
        } else {
          _playVideo();
        }
        // Reconnect to providers when becoming active
        _connectToProviders();
      } else {
        _pauseVideo();
        if (!widget.shouldPreload) {
          _cleanupController(reason: 'No longer active or preloaded');
        }
      }
    }
    
    // Handle preload state changes
    if (widget.shouldPreload != oldWidget.shouldPreload) {
      if (widget.shouldPreload && !_isInitialized && !_isPreloaded) {
        _initializeVideo(highPriority: false);
      } else if (!widget.shouldPreload && !widget.isActive) {
        _cleanupController(reason: 'No longer preloaded or active');
      }
    }
  }

  @override
  void deactivate() {
    print('\n[VideoPlayer] 🔌 DEACTIVATE for video: ${widget.video.id}');
    print('  - Screen transition or widget tree change detected');
    print('  - Has controller: ${_controller != null}');
    print('  - Controller initialized: ${_controller?.value.isInitialized}');
    print('  - Total active controllers: $_activeControllers');
    print('  - Should preload: ${widget.shouldPreload}');
    
    // Always cleanup on deactivate unless explicitly preloading and still mounted
    if (!widget.shouldPreload || !mounted) {
      _cleanupController(reason: 'Widget deactivated');
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    print('\n[VideoPlayer] 🗑️ Disposing video player:');
    print('  - Video ID: ${widget.video.id}');
    
    // Disconnect from providers
    if (mounted) {
      try {
        Provider.of<CookModeProvider>(context, listen: false).setVideo(null, null);
        Provider.of<VoiceControlProvider>(context, listen: false).setVideo(null, null);
      } catch (e) {
        print('  ⚠️ Error disconnecting from providers: $e');
      }
    }
    
    _isDisposed = true;
    _bufferingTimer?.cancel();
    _cleanupController(reason: 'Widget disposed');
    super.dispose();
  }

  Future<void> _initializeMetadata() async {
    try {
      // Get the actual likes count from Firestore
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.video.id)
          .get();
      
      if (videoDoc.exists) {
        _likeCount = videoDoc.data()?['likes'] ?? 0;
      } else {
        _likeCount = 0;
      }
      
      _commentCount = widget.video.comments;
      _shareCount = widget.video.shares;
      _isLiked = await _videoService.isVideoLikedByUser(widget.video.id);
      
      if (mounted) setState(() {});
    } catch (e) {
      print('[VideoPlayer] Error initializing metadata: $e');
      // Fallback to video model data if Firestore fetch fails
      if (mounted) {
        setState(() {
          _likeCount = widget.video.likes;
          _commentCount = widget.video.comments;
          _shareCount = widget.video.shares;
        });
      }
    }
  }

  Future<void> _initializeVideo({bool highPriority = false}) async {
    if (_isInitialized || _isPreloaded || _isDisposed) {
      print('\n[VideoPlayer] 🚫 Skipping initialization:');
      print('  - Already initialized: $_isInitialized');
      print('  - Already preloaded: $_isPreloaded');
      print('  - Is disposed: $_isDisposed');
      return;
    }
    
    try {
      print('\n[VideoPlayer] 🎬 Initializing video: ${widget.video.id}');
      print('  - Priority: ${highPriority ? "High" : "Low"}');
      print('  - Is active: ${widget.isActive}');
      print('  - Should preload: ${widget.shouldPreload}');
      print('  - Has existing controller: ${_controller != null}');
    
      _incrementControllerCount();
      _isCancelled = false;
      _retryCount = 0;

      // Check network condition for quality selection
      final connection = await (Connectivity().checkConnectivity());
      final quality = connection == ConnectivityResult.wifi ? 'high' : 'low';
      print('  - Network: ${connection.toString()}, Selected quality: $quality');
      
      // First try to get from cache
      final cachedPath = await _videoService.getCachedVideoPath(widget.video.videoUrl);
      if (cachedPath != null && await File(cachedPath).exists()) {
        print('  ✅ Using cached video:');
        print('    - Path: $cachedPath');
        
        if (_isDisposed) return;
        
        _controller = VideoPlayerController.file(
          File(cachedPath),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        print('  ⚠️ Cache miss, fetching network URL');
        final videoUrl = await _videoService.getVideoUrl(
          widget.video.videoUrl,
          quality: quality,
        );
        
        if (_isDisposed) return;
        
        if (videoUrl == null) {
          print('  ❌ Failed to get video URL');
          _decrementControllerCount();
          return;
        }

        _controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      _controller!.addListener(_onControllerUpdate);

      // Initialize with timeout based on priority
      await _controller!.initialize().timeout(
        Duration(seconds: highPriority ? 10 : 15),
        onTimeout: () {
          _logger.e('❌ Video initialization timed out');
          throw TimeoutException('Video initialization timed out');
        },
      );
      
      if (_isDisposed) {
        _cleanupController(reason: 'Disposed during initialization');
        return;
      }

      // Verify initialization was successful
      if (!_controller!.value.isInitialized) {
        _logger.e('❌ Video controller not properly initialized');
        throw Exception('Video controller not properly initialized');
      }

      // Set initial volume to 0 to prevent audio bleed
      await _controller!.setVolume(0.0);

      setState(() {
        _isInitialized = true;
        _isPreloaded = true;
        _hasError = false;
      });

      // Connect to providers after initialization
      _connectToProviders();

      // For active videos, start playing
      if (widget.isActive) {
        _playVideo();
      } else if (widget.shouldPreload) {
        // For preloaded videos, prepare first frame and buffer
        await _preparePreloadedVideo();
      }
      
      print('\n[VideoPlayer] ✅ Video initialized successfully:');
      print('  - Video ID: ${widget.video.id}');
      print('  - Is active: ${widget.isActive}');
      print('  - Is preloaded: ${widget.shouldPreload}');
      print('  - Controller initialized: ${_controller?.value.isInitialized}');
      
    } catch (e) {
      print('\n[VideoPlayer] ❌ Error initializing video:');
      print('  - Video ID: ${widget.video.id}');
      print('  - Error: $e');
      
      _cleanupController(reason: 'Initialization error');
      
      // Only retry initialization if it's the active video and we haven't exceeded retry limit
      if ((widget.isActive || widget.shouldPreload) && _retryCount < 2 && !_isCancelled && mounted) {
        _retryCount++;
        print('  - Retrying initialization (attempt $_retryCount)');
        Future.delayed(Duration(seconds: _retryCount), () {
          if (!_isDisposed && mounted) {
            _initializeVideo(highPriority: widget.isActive);
          }
        });
      } else if (mounted && !_isDisposed) {
        setState(() {
          _hasError = true;
          _isInitialized = false;
          _isPreloaded = false;
        });
      }
    }
  }

  Future<void> _preparePreloadedVideo() async {
    if (_controller == null || !mounted) return;
    
    try {
      print('\n[VideoPlayer] 🎯 Preparing preloaded video:');
      print('  - Video ID: ${widget.video.id}');
      
      // Set volume to 0 before any playback
      await _controller!.setVolume(0);
      
      // Seek to beginning
      await _controller!.seekTo(Duration.zero);
      
      // Start buffering
      await _controller!.play();
      
      // Use a timer to track buffering progress
      _bufferingTimer?.cancel();
      _bufferingTimer = Timer(const Duration(milliseconds: 500), () async {
        if (_controller != null && mounted && !widget.isActive) {
          await _controller!.pause();
          print('  ✅ Preloaded video prepared successfully');
        }
      });
    } catch (e) {
      print('  ⚠️ Error preparing preloaded video: $e');
    }
  }

  void _playVideo() {
    if (_controller != null && _isInitialized && mounted) {
      print('\n[VideoPlayer] ▶️ Playing video: ${widget.video.id}');
      _bufferingTimer?.cancel();
      _controller!.setVolume(1.0);
      _controller!.seekTo(Duration.zero);
      _controller!.play();
    } else {
      print('\n[VideoPlayer] ⚠️ Cannot play video: ${widget.video.id}');
      print('  - Controller exists: ${_controller != null}');
      print('  - Is initialized: $_isInitialized');
      print('  - Is mounted: $mounted');
    }
  }

  void _pauseVideo() {
    if (_controller != null && _isInitialized && mounted) {
      print('\n[VideoPlayer] ⏸️ Pausing video: ${widget.video.id}');
      _bufferingTimer?.cancel();
      _controller!.pause();
      _controller!.setVolume(0);
    }
  }

  Future<void> _cleanupController({required String reason}) async {
    print('\n[VideoPlayer] 🧹 Cleaning up controller:');
      print('  - Video ID: ${widget.video.id}');
      print('  - Reason: $reason');
    print('  - Is initialized: $_isInitialized');
    print('  - Is preloaded: $_isPreloaded');
    
    _bufferingTimer?.cancel();
    
    if (_controller != null) {
      try {
        // Immediately stop playback and audio
        await _controller!.setVolume(0);
        await _controller!.pause();
        
        _controller!.removeListener(_onControllerUpdate);
        await _controller!.dispose();
        _controller = null;
        _decrementControllerCount();
        
        // Only clear cache if we're not preloading and have too many controllers
        if (!widget.shouldPreload && _activeControllers > MAX_ACTIVE_CONTROLLERS) {
          // Instead of clearing cache, just decrement counter
          _activeControllers = MAX_ACTIVE_CONTROLLERS - 1;
        }
      } catch (e) {
        print('  ⚠️ Error during cleanup: $e');
        // Force counter reset on cleanup error
        _activeControllers = 0;
      }
    }
      
    if (mounted && !_isDisposed) {
      setState(() {
        _isInitialized = false;
        _isPreloaded = false;
      });
    }
  }

  void _onControllerUpdate() {
    if (_controller == null || !mounted) return;
    
    // Handle playback errors
    if (_controller!.value.hasError) {
      print('\n[VideoPlayer] ⚠️ Playback error:');
      print('  - Video ID: ${widget.video.id}');
      print('  - Error: ${_controller!.value.errorDescription}');
      
      // Only retry twice before showing error to user
      if (_retryCount < 2 && widget.isActive && !_isCancelled) {
        _retryCount++;
        print('  - Retrying playback (attempt $_retryCount)');
        _cleanupController(reason: 'Playback error');
        Future.delayed(Duration(seconds: _retryCount), () {
          if (mounted && !_isCancelled) {
            _initializeVideo(highPriority: widget.isActive);
          }
        });
      } else {
        setState(() => _hasError = true);
      }
    }
    
    // Monitor buffering state
    if (_controller!.value.isBuffering) {
      print('  - Buffering: ${widget.video.id}');
    }

    // Handle video completion - auto replay
    if (_controller!.value.position >= _controller!.value.duration) {
      print('\n[VideoPlayer] 🔄 Video completed, auto-replaying:');
      print('  - Video ID: ${widget.video.id}');
      _controller!.seekTo(Duration.zero);
      _controller!.play();
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _togglePlayPause() {
    // Don't handle taps if cook mode is active
    if (Provider.of<CookModeProvider>(context, listen: false).isActive) {
      return;
    }
    
    setState(() {
      if (_controller?.value.isPlaying ?? false) {
        _controller?.pause();
      } else {
        _controller?.play();
        _controller?.setVolume(1.0);
      }
    });
  }

  void _handleLike() async {
    final previousLikeState = _isLiked;
    final previousCount = _likeCount;
    
    // Optimistically update UI
    setState(() {
      if (_isLiked) {
        _likeCount--;
      } else {
        _likeCount++;
      }
      _isLiked = !_isLiked;
    });

    try {
      // Update backend
      await _videoService.likeVideo(widget.video.id, _isLiked);
      
      // Refresh the actual count from Firestore
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(widget.video.id)
          .get();
      
      if (mounted && videoDoc.exists) {
        setState(() {
          _likeCount = videoDoc.data()?['likes'] ?? 0;
        });
      }
    } catch (e) {
      print('[VideoPlayer] Error handling like: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _isLiked = previousLikeState;
          _likeCount = previousCount;
        });
      }
    }
  }

  void _showComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: CommentsSheet(
          videoId: widget.video.id,
          initialCommentCount: _commentCount,
          videoService: _videoService,
          onCommentCountUpdated: (newCount) {
            setState(() => _commentCount = newCount);
          },
        ),
      ),
    );
  }

  void _showShareSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ShareSheet(
        video: widget.video,
        videoService: _videoService,
        onShareCountUpdated: (newCount) {
          setState(() => _shareCount = newCount);
        },
      ),
    );
  }

  void _showBookmarkDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final cookbookService = Provider.of<CookbookService>(context);
          
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Save to Cookbook',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        Navigator.pop(context);
                        final nameController = TextEditingController();
                        final descriptionController = TextEditingController();

                        final created = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Create New Cookbook'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                    hintText: 'Enter cookbook name',
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: descriptionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Description (optional)',
                                    hintText: 'Enter cookbook description',
                                  ),
                                  maxLines: 2,
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final name = nameController.text.trim();
                                  if (name.isEmpty) return;

                                  final cookbook = await cookbookService.createCookbook(
                                    name: name,
                                    description: descriptionController.text.trim(),
                                  );

                                  if (cookbook != null && context.mounted) {
                                    Navigator.pop(context, true);
                                  }
                                },
                                child: const Text('Create'),
                              ),
                            ],
                          ),
                        );

                        if (created == true && context.mounted) {
                          _showBookmarkDialog();
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<CookbookModel>>(
                  stream: cookbookService.getUserCookbooks(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final cookbooks = snapshot.data!;
                    if (cookbooks.isEmpty) {
                      return const Center(
                        child: Text('No cookbooks yet. Create one to save videos.'),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: cookbooks.length,
                      itemBuilder: (context, index) {
                        final cookbook = cookbooks[index];
                        return ListTile(
                          title: Text(cookbook.name),
                          subtitle: Text(
                            '${cookbook.videoCount} videos',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onTap: () async {
                            final added = await cookbookService.addVideoToCookbook(
                              cookbook.id,
                              widget.video,
                            );
                            if (added && context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added to ${cookbook.name}',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _shouldShowErrorToUser(dynamic error) {
    // Don't show errors for common/temporary issues
    if (error is TimeoutException) return false;
    if (error.toString().contains('MediaCodecVideoRenderer')) return false;
    return true;
  }

  void _addToInitializationQueue() {
    if (!_initializationQueue.contains(widget.video.id)) {
      _initializationQueue.add(widget.video.id);
      _processInitializationQueue();
    }
  }

  Future<void> _processInitializationQueue() async {
    if (_isProcessingQueue || _initializationQueue.isEmpty) return;
    
    _isProcessingQueue = true;
    
    try {
      while (_initializationQueue.isNotEmpty) {
        final nextVideoId = _initializationQueue.first;
        _initializationQueue.removeFirst(); // Remove immediately to prevent stuck videos
        
        // Skip if this video is no longer needed
        if (!mounted || _isDisposed || !widget.shouldPreload) {
          continue;
        }
        
        // Initialize if this is our video
        if (nextVideoId == widget.video.id) {
          await _initializeVideo(highPriority: false);
        }
        
        // Add small delay between initializations
        if (_initializationQueue.isNotEmpty) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    } finally {
      _isProcessingQueue = false;
    }
  }

  void _incrementControllerCount() {
    if (_activeControllers >= MAX_ACTIVE_CONTROLLERS) {
      _cleanupController(reason: 'Too many controllers');
      return;
    }
    _activeControllers++;
    print('\n[VideoPlayer] 📈 Controller counter incremented:');
    print('  - Video ID: ${widget.video.id}');
    print('  - New total: $_activeControllers');
    print('  - Is mounted: $mounted');
    print('  - Is active: ${widget.isActive}');
  }

  void _decrementControllerCount() {
    if (_activeControllers > 0) {
      _activeControllers--;
    } else {
      _activeControllers = 0;
    }
    print('\n[VideoPlayer] 📉 Controller counter decremented:');
    print('  - Video ID: ${widget.video.id}');
    print('  - New total: $_activeControllers');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    print('Building video player. Screen size: ${size.width} x ${size.height}');

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer - Constrain height when game mode is active
          if (widget.isGameMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size.height / 2,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.black.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: ClipRect(
                  child: _buildVideoPlayer(),
                ),
              ),
            )
          else
            _buildVideoPlayer(),

          // Status indicators in top-right corner
          Consumer<CookModeProvider>(
            builder: (context, cookModeProvider, _) {
              if (!cookModeProvider.isActive) return const SizedBox.shrink();
              
              return Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cook Mode Indicator
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Cook Mode',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Control Indicators
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (cookModeProvider.gestureControlEnabled)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.gesture,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Gesture',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          if (cookModeProvider.gestureControlEnabled && 
                              cookModeProvider.voiceControlEnabled)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(
                                '•',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          if (cookModeProvider.voiceControlEnabled)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Voice',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Voice feedback overlay
          const VoiceFeedbackOverlay(),

          // Title and description - Adjust position in game mode
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.isGameMode 
                ? (size.height / 2) + 16 // Position just above game area
                : MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight + 48,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title and description
                  Text(
                    widget.video.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          blurRadius: 4,
                          color: Colors.black,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  if (widget.video.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.video.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black,
                            offset: Offset(1, 1),
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Interaction buttons on the right - Adjust position in game mode
          Positioned(
            right: 16,
            bottom: widget.isGameMode 
                ? (size.height / 2) + 16 // Position just above game area
                : size.height * 0.15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Add cook mode button at the top
                const CookModeButton(),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  label: _likeCount.toString(),
                  color: _isLiked ? Colors.red : Colors.white,
                  onTap: _handleLike,
                ),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  icon: Icons.comment,
                  label: _commentCount.toString(),
                  onTap: _showComments,
                ),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                  onTap: _showBookmarkDialog,
                ),
                const SizedBox(height: 20),
                _buildInteractionButton(
                  icon: Icons.share,
                  label: _shareCount.toString(),
                  onTap: () => _showShareSheet(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      child: _isInitialized && _controller != null
          ? GestureDetector(
              onTap: _togglePlayPause,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          : Center(
              child: _hasError
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white.withOpacity(0.6),
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Unable to load video',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap retry to reload this video',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            print('\n[VideoPlayer] 🔄 Manual retry requested');
                            print('  - Video ID: ${widget.video.id}');
                            // Reset error state and retry count
                            setState(() {
                              _hasError = false;
                              _retryCount = 0;
                              _isInitialized = false;
                              _isPreloaded = false;
                            });
                            // Clean up existing controller
                            _cleanupController(reason: 'Manual retry');
                            // Call parent's retry callback
                            widget.onRetry();
                            // Reinitialize video
                            _initializeVideo(highPriority: true);
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required String label,
    Color color = Colors.white,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 14),
          ),
        ],
      ),
    );
  }
} 