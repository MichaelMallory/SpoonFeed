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

class VideoPlayerFullscreen extends StatefulWidget {
  final VideoModel video;
  final bool isActive;
  final bool shouldPreload;
  final bool isGameMode;

  const VideoPlayerFullscreen({
    Key? key,
    required this.video,
    required this.isActive,
    this.shouldPreload = false,
    this.isGameMode = false,
  }) : super(key: key);

  @override
  _VideoPlayerFullscreenState createState() => _VideoPlayerFullscreenState();
}

class _VideoPlayerFullscreenState extends State<VideoPlayerFullscreen> with AutomaticKeepAliveClientMixin, RouteAware {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  final VideoService _videoService = VideoService();
  bool _isLiked = false;
  int _likeCount = 0;
  int _commentCount = 0;
  int _shareCount = 0;
  bool _hasError = false;
  bool _isCancelled = false;  // Flag to track cancellation state
  static int _activeControllers = 0;  // Static counter for active controllers
  static const int MAX_ACTIVE_CONTROLLERS = 3; // Back to 3 controllers for home feed
  late RouteObserver<ModalRoute<void>> _routeObserver;

  @override
  bool get wantKeepAlive => widget.isActive || widget.shouldPreload;

  void _incrementControllerCount() {
    _activeControllers++;
    print('\n[VideoPlayer] 📈 Controller counter incremented:');
    print('  - Video ID: ${widget.video.id}');
    print('  - New total: $_activeControllers');
    print('  - Is mounted: $mounted');
    print('  - Is active: ${widget.isActive}');
    
    // Safety check - if we have too many controllers, force cleanup of inactive ones
    if (_activeControllers > MAX_ACTIVE_CONTROLLERS) {
      print('  ⚠️ Too many controllers, cleaning up inactive ones');
      if (!widget.isActive) {
        _cleanupController(reason: 'Too many active controllers');
      }
    }
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
  void initState() {
    super.initState();
    _routeObserver = RouteObserver<ModalRoute<void>>();
    print('\n[VideoPlayer] 🎬 InitState for: ${widget.video.title}');
    print('  - Is active: ${widget.isActive}');
    print('  - Should preload: ${widget.shouldPreload}');
    
    // Only initialize if active or should preload
    if (widget.isActive || widget.shouldPreload) {
      _initializeVideo();
    }
    _initializeMetadata();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didUpdateWidget(VideoPlayerFullscreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    print('\n[VideoPlayer] 🔄 Widget updated:');
    print('  - Video ID: ${widget.video.id}');
    print('  - Old active: ${oldWidget.isActive}');
    print('  - New active: ${widget.isActive}');
    print('  - Should preload: ${widget.shouldPreload}');
    print('  - Is initialized: $_isInitialized');
    print('  - Has controller: ${_controller != null}');
    
    // Handle cook mode controller management
    if (Provider.of<CookModeProvider>(context, listen: false).isActive) {
      if (!widget.isActive && oldWidget.isActive) {
        Provider.of<CookModeProvider>(context, listen: false)
          .setVideoController(null);
      }
    }
    
    // Handle active state changes
    if (widget.isActive != oldWidget.isActive || widget.shouldPreload != oldWidget.shouldPreload) {
      if (widget.isActive || widget.shouldPreload) {
        // Becoming active or should preload
        if (!_isInitialized || _controller == null) {
          print('  - Initializing video on active/preload');
          _initializeVideo();
        } else if (widget.isActive) {
          print('  - Playing existing controller');
          // If we're activating a preloaded video, it should be ready to play instantly
          _controller?.setVolume(1.0);
          _controller?.play();
          // Update cook mode provider if needed
          if (Provider.of<CookModeProvider>(context, listen: false).isActive) {
            Provider.of<CookModeProvider>(context, listen: false)
              .setVideoController(_controller);
          }
        }
      } else {
        // No longer active or preloading
        print('  - Cleaning up inactive video');
        _cleanupController(reason: 'No longer active or preloading');
      }
    }

    // Only cleanup if really far from viewport (more than 1 video away)
    if (!widget.isActive && !widget.shouldPreload && _controller != null) {
      print('  - Cleaning up distant video');
      _cleanupController(reason: 'Too far from viewport');
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
    print('\n[VideoPlayer] 🗑 Disposing video player: ${widget.video.id}');
    _routeObserver.unsubscribe(this);
    // Clear controller from cook mode provider
    Provider.of<CookModeProvider>(context, listen: false)
      .setVideoController(null);
    _cleanupController(reason: 'Widget disposed');
    super.dispose();
  }

  @override
  void didPushNext() {
    // Route was pushed on top of this one - cleanup ALL controllers
    print('\n[VideoPlayer] 📱 Route pushed on top: ${widget.video.id}');
    _activeControllers = 0; // Reset counter since we're navigating away
    _cleanupController(reason: 'Route pushed on top');
  }

  @override
  void didPopNext() {
    // Returning to this route - only initialize if active
    print('\n[VideoPlayer] 📱 Returning to route: ${widget.video.id}');
    _activeControllers = 0; // Reset counter when returning
    if (widget.isActive) {
      _initializeVideo();
    }
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

  Future<void> _initializeVideo() async {
    print('\n[VideoPlayer] 🔄 Starting initialization:');
    print('  - Video ID: ${widget.video.id}');
    print('  - Is active: ${widget.isActive}');
    print('  - Should preload: ${widget.shouldPreload}');
    
    // Check if we should proceed
    if (!mounted || (!widget.isActive && !widget.shouldPreload)) {
      print('  ⚠️ Initialization skipped:');
      print('    - Is mounted: $mounted');
      print('    - Is active: ${widget.isActive}');
      print('    - Should preload: ${widget.shouldPreload}');
      return;
    }

    // Always allow initialization for explicitly active videos
    if (widget.isActive) {
      print('  ✅ Allowing initialization for active video');
    } 
    // For preloading/background videos, respect controller limit
    else if (_activeControllers >= MAX_ACTIVE_CONTROLLERS) {
      print('  ⚠️ Skipping initialization of background video due to controller limit');
      return;
    }

    // Only cleanup if we have an existing controller
    if (_controller != null) {
      print('  - Cleaning up existing controller');
      await _cleanupController(reason: 'Reinitializing video');
    }
    
    try {
      _incrementControllerCount();
      _isCancelled = false; // Reset cancellation flag

      print('\n[VideoPlayer] 🔍 Fetching video URL...');
      String? videoUrl;
      
      // First try to get from cache
      final cachedPath = await _videoService.getCachedVideoPath(widget.video.videoUrl);
      if (cachedPath != null && await File(cachedPath).exists()) {
        print('  ✅ Using cached video:');
        print('    - Path: $cachedPath');
        final cacheFile = File(cachedPath);
        print('    - Size: ${_formatFileSize(await cacheFile.length())}');
        _controller = VideoPlayerController.file(
          cacheFile,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
          ),
        );
      } else {
        print('  ⚠️ Cache miss, fetching network URL');
        videoUrl = await _videoService.getVideoUrl(widget.video.videoUrl);
        if (videoUrl == null) {
          print('  ❌ Failed to get video URL');
          _decrementControllerCount();
          return;
        }

        print('  🌐 Using network URL: $videoUrl');
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
          ),
        );
      }

      // Add listeners before initialization
      _controller!.addListener(_onControllerUpdate);

      print('\n[VideoPlayer] 🎯 Initializing controller...');
      
      // Initialize with timeout
      await _controller?.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Video initialization timed out');
        },
      );
      
      // For preloaded videos, we want to:
      // 1. Seek to beginning
      // 2. Start buffering
      // 3. Pause immediately
      // This ensures the video is ready for instant playback
      if (widget.shouldPreload && !widget.isActive) {
        print('  🔄 Preparing preloaded video');
        await _controller?.seekTo(Duration.zero);
        // Start playback briefly to trigger buffering
        await _controller?.play();
        await Future.delayed(const Duration(milliseconds: 100));
        await _controller?.pause();
        await _controller?.setVolume(0.0);
        print('  ✓ Preload preparation complete');
      }

      if (!mounted || _isCancelled) {
        print('  ⚠️ Widget unmounted or cancelled during initialization');
        await _cleanupController(reason: 'Widget unmounted or cancelled');
        return;
      }

      // Set controller in CookModeProvider if active
      if (widget.isActive) {
        Provider.of<CookModeProvider>(context, listen: false)
          .setVideoController(_controller);
      }

      final value = _controller?.value;
      print('\n[VideoPlayer] ✅ Controller initialized:');
      print('  - Video size: ${value?.size}');
      print('  - Duration: ${value?.duration}');
      print('  - Is playing: ${value?.isPlaying}');
      print('  - Is looping: ${value?.isLooping}');
      print('  - Is buffering: ${value?.isBuffering}');
      print('  - Volume: ${value?.volume}');
      print('  - Position: ${value?.position}');

      await _controller?.setLooping(true);
      
      if (widget.isActive) {
        print('\n[VideoPlayer] ▶️ Starting playback:');
        print('  - Video ID: ${widget.video.id}');
        await _controller?.setVolume(1.0);
        await _controller?.play();
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
          print('\n[VideoPlayer] 🔄 State updated:');
          print('  - Initialized: $_isInitialized');
          print('  - Has error: $_hasError');
          print('  - Is preloaded: ${widget.shouldPreload}');
        });
      }
    } catch (e, stackTrace) {
      print('\n[VideoPlayer] ❌ Initialization error:');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      
      await _cleanupController(reason: 'Initialization error');
      
      if (mounted) {
        setState(() {
          _isInitialized = false;
          if (_shouldShowErrorToUser(e)) {
            _hasError = true;
          }
        });
      }

      // Only retry if this is the active video and not a timeout
      if (widget.isActive && !_isCancelled && !(e is TimeoutException)) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted && !_isCancelled) {
            _initializeVideo();
          }
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (_controller == null || !mounted) return;
    
    // Handle playback errors
    if (_controller!.value.hasError) {
      print('[VideoPlayer] ⚠️ Playback error: ${_controller!.value.errorDescription}');
      // Only retry if this is the active video and not cancelled
      if (widget.isActive && !_isCancelled) {
        _cleanupController(reason: 'Playback error');
        // Add delay before retrying
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isCancelled) {
            _initializeVideo();
          }
        });
      }
    }
  }

  Future<void> _cleanupController({String reason = 'Unknown'}) async {
    final oldController = _controller;
    if (oldController == null) return;
    
    _controller = null;
    
    try {
      print('\n[VideoPlayer] 🧹 Starting cleanup:');
      print('  - Video ID: ${widget.video.id}');
      print('  - Reason: $reason');
      print('  - Controller initialized: ${oldController.value.isInitialized}');
      print('  - Current active controllers: $_activeControllers');
      
      // Decrement counter first to ensure accurate tracking
      _decrementControllerCount();
      
      // Stop playback and audio immediately
      try {
        await oldController.pause().timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => print('  ⚠️ Pause timed out'),
        );
        await oldController.setVolume(0.0).timeout(
          const Duration(milliseconds: 300),
          onTimeout: () => print('  ⚠️ Volume set timed out'),
        );
        print('    ✓ Playback stopped');
      } catch (e) {
        print('  ⚠️ Error stopping playback: $e');
      }
      
      // Remove listener
      oldController.removeListener(_onControllerUpdate);
      print('    ✓ Listener removed');
      
      // Clear from CookModeProvider if active
      if (widget.isActive) {
        Provider.of<CookModeProvider>(context, listen: false)
          .setVideoController(null);
      }
      
      // Dispose the controller with timeout
      try {
        await oldController.dispose().timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => print('  ⚠️ Dispose timed out'),
        );
        print('    ✓ Controller disposed');
      } catch (e) {
        print('  ⚠️ Error disposing controller: $e');
        // Force counter reset if we have disposal errors
        _activeControllers = 0;
      }
      
      // Reset initialization state
      _isInitialized = false;
      if (mounted) setState(() {});
      
      print('  📊 Memory cleanup complete:');
      print('    - Remaining controllers: $_activeControllers');
      
    } catch (e) {
      print('\n[VideoPlayer] ❌ Error during cleanup:');
      print('  - Error: $e');
      // Force counter reset on any cleanup error
      _activeControllers = 0;
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
      backgroundColor: Colors.transparent,
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
          // Video Layer
          Container(
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
                              if (widget.isActive) ...[
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _hasError = false;
                                      _initializeVideo();
                                    });
                                  },
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ],
                          )
                        : const CircularProgressIndicator(color: Colors.white),
                  ),
          ),

          // Camera Preview Overlay - Commented out for now
          // const CameraPreviewOverlay(),

          // Cook Mode Indicator
          Consumer<CookModeProvider>(
            builder: (context, cookModeProvider, _) {
              if (!cookModeProvider.isActive) return const SizedBox.shrink();
              
              return Positioned(
                top: 64, // Positioned below game icon
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.touch_app,  // Changed to hand icon
                        color: Colors.orange,  // Highlighted color
                        size: 18,
                      ),
                      const SizedBox(width: 4),
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
                ),
              );
            },
          ),

          // Video info overlay at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.25, // Gradient height
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),
          ),

          // Title and description
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.isGameMode 
                ? MediaQuery.of(context).size.height * 0.5 + 80 // When game is active, position above game
                : MediaQuery.of(context).viewPadding.bottom + kBottomNavigationBarHeight + 48, // Just above nav bar with some padding
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

          // Interaction buttons on the right
          Positioned(
            right: 16,
            bottom: widget.isGameMode 
                ? MediaQuery.of(context).size.height * 0.5 + 16 // When game is active, position above game
                : MediaQuery.of(context).size.height * 0.15, // Adjusted to be closer to the bottom
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