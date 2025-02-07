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

class _VideoPlayerFullscreenState extends State<VideoPlayerFullscreen> with AutomaticKeepAliveClientMixin {
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

  @override
  bool get wantKeepAlive => widget.isActive || widget.shouldPreload;

  void _incrementControllerCount() {
    _activeControllers++;
    print('\n[VideoPlayer] 📈 Controller counter incremented:');
    print('  - Video ID: ${widget.video.id}');
    print('  - New total: $_activeControllers');
    print('  - Is mounted: $mounted');
    print('  - Is active: ${widget.isActive}');
  }

  void _decrementControllerCount() {
    _activeControllers--;
    print('\n[VideoPlayer] 📉 Controller counter decremented:');
    print('  - Video ID: ${widget.video.id}');
    print('  - New total: $_activeControllers');
    print('  - Is mounted: $mounted');
    
    // Safety check for negative values
    if (_activeControllers < 0) {
      print('  ⚠️ Counter went negative, resetting to 0');
      _activeControllers = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    print('\n[VideoPlayer] 🎬 INIT STATE for video: ${widget.video.id}');
    print('  - Active: ${widget.isActive}');
    print('  - Preload: ${widget.shouldPreload}');
    print('  - Total controllers: $_activeControllers');
    print('  - Is mounted: $mounted');
    _isCancelled = false;  // Reset cancelled state on init
    if (widget.isActive) {
      _initializeVideo();
    }
    _initializeMetadata();
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

  @override
  void deactivate() {
    print('\n[VideoPlayer] 🔌 DEACTIVATE for video: ${widget.video.id}');
    print('  - Screen transition or widget tree change detected');
    print('  - Has controller: ${_controller != null}');
    print('  - Controller initialized: ${_controller?.value.isInitialized}');
    print('  - Total active controllers: $_activeControllers');
    print('  - Is cancelled: $_isCancelled');
    _isCancelled = true;
    _cleanupController(isTransition: true);
    super.deactivate();
  }

  @override
  void dispose() {
    print('\n[VideoPlayer] 🗑️ DISPOSE for video: ${widget.video.id}');
    print('  - Final cleanup before widget destruction');
    print('  - Has controller: ${_controller != null}');
    print('  - Controller initialized: ${_controller?.value.isInitialized}');
    print('  - Total active controllers: $_activeControllers');
    print('  - Is cancelled: $_isCancelled');
    _isCancelled = true;
    _cleanupController(isTransition: true);
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPlayerFullscreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Reset cancelled state when video becomes active
    if (!oldWidget.isActive && widget.isActive) {
      print('\n[VideoPlayer] 🔄 Video becoming active: ${widget.video.id}');
      print('  - Previous active state: ${oldWidget.isActive}');
      print('  - New active state: ${widget.isActive}');
      print('  - Current controllers: $_activeControllers');
      _isCancelled = false;
    }
    
    if (widget.isActive != oldWidget.isActive) {
      print('\n[VideoPlayer] 🔄 Video active state changed:');
      print('  - Video ID: ${widget.video.id}');
      print('  - Previous state: ${oldWidget.isActive}');
      print('  - New state: ${widget.isActive}');
      print('  - Controller exists: ${_controller != null}');
      print('  - Controller initialized: ${_controller?.value.isInitialized}');
      print('  - Total active controllers: $_activeControllers');
      print('  - Is cancelled: $_isCancelled');
      
      if (widget.isActive) {
        if (_controller == null || !_isInitialized) {
          print('  - Initializing previously inactive video');
          _initializeVideo();
        } else {
          print('  - Resuming existing controller');
          _controller?.setVolume(1.0);
          _controller?.play();
        }
      } else {
        _isCancelled = true;
        _controller?.pause();
        print('  - Video inactive, cleaning up');
        _cleanupController();
      }
    }
  }

  Future<void> _initializeVideo() async {
    if (_isCancelled) {
      print('\n[VideoPlayer] ⚠️ Initialization cancelled:');
      print('  - Video ID: ${widget.video.id}');
      print('  - Is mounted: $mounted');
      print('  - Is active: ${widget.isActive}');
      return;
    }
    
    try {
      print('\n[VideoPlayer] 🔄 Starting initialization:');
      print('  - Video ID: ${widget.video.id}');
      print('  - Memory status:');
      print('    • Active controller: ${_controller != null}');
      print('    • Controller initialized: ${_controller?.value.isInitialized}');
      print('    • Is mounted: $mounted');
      print('    • Total active controllers: $_activeControllers');
      print('    • Is cancelled: $_isCancelled');
      print('    • Is active: ${widget.isActive}');
      
      // Only cleanup if we don't already have an initialized controller
      if (_controller != null) {
        print('  - Cleaning up existing controller first');
        await _cleanupController();
      }

      // Double check mount and active state
      if (!mounted || !widget.isActive || _isCancelled) {
        print('\n[VideoPlayer] ⚠️ Initialization aborted:');
        print('  - Is mounted: $mounted');
        print('  - Is active: ${widget.isActive}');
        print('  - Is cancelled: $_isCancelled');
        return;
      }

      _incrementControllerCount();

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
          setState(() => _isInitialized = false);
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

      // Initialize without timeout - rely on error handling instead
      print('\n[VideoPlayer] 🎯 Initializing controller...');
      if (!mounted || !widget.isActive || _isCancelled) {
        print('  ⚠️ Aborted before initialization:');
        print('    - Is mounted: $mounted');
        print('    - Is active: ${widget.isActive}');
        print('    - Is cancelled: $_isCancelled');
        _cleanupController();
        return;
      }

      await _controller?.initialize();
      
      if (!mounted || !widget.isActive || _isCancelled) {
        print('  ⚠️ Aborted after initialization:');
        print('    - Is mounted: $mounted');
        print('    - Is active: ${widget.isActive}');
        print('    - Is cancelled: $_isCancelled');
        _cleanupController();
        return;
      }

      final value = _controller?.value;
      print('\n[VideoPlayer] ✅ Controller initialized:');
      print('  - Video size: ${value?.size}');
      print('  - Duration: ${value?.duration}');
      print('  - Is playing: ${value?.isPlaying}');
      print('  - Is looping: ${value?.isLooping}');
      print('  - Is buffering: ${value?.isBuffering}');
      print('  - Volume: ${value?.volume}');
      
      if (!mounted || !widget.isActive || _isCancelled) {
        _cleanupController();
        return;
      }

      await _controller?.setLooping(true);
      
      if (widget.isActive && !_isCancelled) {
        print('\n[VideoPlayer] ▶️ Starting playback:');
        print('  - Video ID: ${widget.video.id}');
        await _controller?.setVolume(1.0);
        await _controller?.play();
      } else {
        print('\n[VideoPlayer] ⚠️ Video inactive or cancelled:');
        print('  - Is active: ${widget.isActive}');
        print('  - Is cancelled: $_isCancelled');
        _cleanupController();
        return;
      }

      if (mounted && !_isCancelled) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
          print('\n[VideoPlayer] 🔄 State updated:');
          print('  - Initialized: $_isInitialized');
          print('  - Has error: $_hasError');
        });
      }
    } catch (e, stackTrace) {
      print('\n[VideoPlayer] ❌ Initialization error:');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      
      _decrementControllerCount();
      
      await _cleanupController();
      
      if (mounted && !_isCancelled) {
        setState(() {
          _isInitialized = false;
          if (_shouldShowErrorToUser(e)) {
            _hasError = true;
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
        _cleanupController();
        // Add delay before retrying
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_isCancelled) {
            _initializeVideo();
          }
        });
      }
    }
  }

  Future<void> _cleanupController({bool isTransition = false}) async {
    final oldController = _controller;
    _controller = null;
    _isInitialized = false;
    
    try {
      print('\n[VideoPlayer] 🧹 Starting cleanup:');
      print('  - Video ID: ${widget.video.id}');
      print('  - Cleanup type: ${isTransition ? 'Screen Transition' : 'Normal Flow'}');
      print('  - Controller exists: ${oldController != null}');
      print('  - Controller initialized: ${oldController?.value.isInitialized}');
      print('  - Current active controllers: $_activeControllers');
      print('  - Is cancelled: $_isCancelled');
      print('  - Is mounted: $mounted');
      print('  - Is active: ${widget.isActive}');
      
      if (oldController != null) {
        print('  🔄 Cleaning up controller:');
        // Stop playback first
        await oldController.pause();
        await oldController.setVolume(0.0);
        print('    ✓ Playback stopped');
        
        // Remove listener
        oldController.removeListener(_onControllerUpdate);
        print('    ✓ Listener removed');
        
        // Dispose the controller
        await oldController.dispose();
        _decrementControllerCount();
        print('    ✓ Controller disposed');

        print('  📊 Cleanup status:');
        print('    - Active controllers: $_activeControllers');
        print('    - Is cancelled: $_isCancelled');
      }

      // Force counter reset during transitions if it's non-zero
      if (isTransition && _activeControllers > 0) {
        print('\n  ⚠️ Found lingering controllers during transition:');
        print('    - Current count: $_activeControllers');
        print('    - Forcing reset to 0');
        _activeControllers = 0;
      }
    } catch (e) {
      print('\n[VideoPlayer] ❌ Error during cleanup:');
      print('  - Error: $e');
      // Still decrement counter even if cleanup fails
      if (oldController != null) {
        _decrementControllerCount();
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _togglePlayPause() {
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
    return Stack(
      fit: StackFit.expand,
      children: [
        // Video player
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            color: Colors.black,
            child: _isInitialized && _controller != null
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  )
                : Center(
                    child: _hasError
                        ? const Icon(
                            Icons.error_outline,
                            color: Colors.white54,
                            size: 36,
                          )
                        : const CircularProgressIndicator(),
                  ),
          ),
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