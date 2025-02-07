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

  @override
  bool get wantKeepAlive => widget.isActive || widget.shouldPreload;

  @override
  void initState() {
    super.initState();
    print('Initializing video player for: ${widget.video.title}');
    _initializeVideo();
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
  void didUpdateWidget(VideoPlayerFullscreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      print('Video active state changed: ${widget.isActive}');
      if (widget.isActive) {
        _controller?.setVolume(1.0);
        _controller?.play();
      } else {
        _controller?.pause();
        if (!widget.shouldPreload) {
          _controller?.setVolume(0);
          _controller?.seekTo(Duration.zero);
        }
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      print('[VideoPlayer] Starting initialization for video: ${widget.video.id}');
      if (_controller != null) {
        print('[VideoPlayer] Controller already exists, checking state...');
        if (!_controller!.value.isInitialized) {
          print('[VideoPlayer] Existing controller not initialized, reinitializing...');
          await _controller!.dispose();
          _controller = null;
        } else {
          print('[VideoPlayer] Using existing initialized controller');
          return;
        }
      }

      // Check if we should initialize now
      if (!widget.isActive && !widget.shouldPreload) {
        print('[VideoPlayer] Skipping initialization - video not active or preloading');
        return;
      }

      print('[VideoPlayer] Fetching video URL...');
      String? videoUrl;
      
      // First try to get from cache
      final cachedPath = await _videoService.getCachedVideoPath(widget.video.videoUrl);
      if (cachedPath != null && await File(cachedPath).exists()) {
        print('[VideoPlayer] Using cached video: $cachedPath');
        _controller = VideoPlayerController.file(
          File(cachedPath),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      } else {
        // Fallback to network URL
        videoUrl = await _videoService.getVideoUrl(widget.video.videoUrl);
        if (videoUrl == null) {
          print('[VideoPlayer] Failed to get video URL');
          setState(() => _isInitialized = false);
          return;
        }

        print('[VideoPlayer] Using network URL: $videoUrl');
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(videoUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
      }

      // Add listeners before initialization
      _controller!.addListener(_onControllerUpdate);

      print('[VideoPlayer] Initializing controller');
      await _controller?.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('[VideoPlayer] Initialization timeout');
          throw TimeoutException('Video initialization timed out');
        },
      );
      
      final value = _controller?.value;
      print('[VideoPlayer] Controller initialized:');
      print('[VideoPlayer] - Video size: ${value?.size}');
      print('[VideoPlayer] - Duration: ${value?.duration}');
      print('[VideoPlayer] - Is playing: ${value?.isPlaying}');
      
      await _controller?.setLooping(true);
      
      if (widget.isActive) {
        print('[VideoPlayer] Video is active, starting playback');
        await _controller?.setVolume(1.0);
        await _controller?.play();
      } else if (widget.shouldPreload) {
        print('[VideoPlayer] Preloading video without playback');
        await _controller?.setVolume(0);
        // Just initialize without playing
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          print('[VideoPlayer] State updated: initialized = true');
        });
      }
    } catch (e, stackTrace) {
      print('[VideoPlayer] Error initializing video:');
      print('[VideoPlayer] Error: $e');
      print('[VideoPlayer] Stack trace: $stackTrace');
      
      // Cleanup on error
      await _cleanupController();
      
      if (mounted) {
        setState(() => _isInitialized = false);
        
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing video: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _onControllerUpdate() {
    if (_controller == null || !mounted) return;
    
    // Handle playback errors
    if (_controller!.value.hasError) {
      print('[VideoPlayer] Playback error: ${_controller!.value.errorDescription}');
      _cleanupController();
      // Retry initialization after error
      _initializeVideo();
    }
  }

  Future<void> _cleanupController() async {
    final oldController = _controller;
    _controller = null;
    try {
      await oldController?.dispose();
    } catch (e) {
      print('[VideoPlayer] Error disposing controller: $e');
    }
  }

  @override
  void dispose() {
    _cleanupController();
    super.dispose();
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
                : const Center(child: CircularProgressIndicator()),
          ),
        ),

        // Video info overlay at bottom
        Positioned(
          left: 0,
          right: 0,
          bottom: widget.isGameMode 
              ? MediaQuery.of(context).size.height * 0.5 + 16 // When game is active, position above game
              : 16, // Just above navigation bar
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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