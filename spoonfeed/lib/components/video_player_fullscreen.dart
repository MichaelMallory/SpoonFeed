import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';
import 'comments_sheet.dart';
import 'share_sheet.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

class VideoPlayerFullscreen extends StatefulWidget {
  final VideoModel video;
  final bool isActive;
  final bool shouldPreload;

  const VideoPlayerFullscreen({
    Key? key,
    required this.video,
    required this.isActive,
    this.shouldPreload = false,
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
    _likeCount = widget.video.likes;
    _commentCount = widget.video.comments;
    _shareCount = widget.video.shares;
    _isLiked = await _videoService.isVideoLikedByUser(widget.video.id);
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(VideoPlayerFullscreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      print('Video active state changed: ${widget.isActive}');
      if (widget.isActive) {
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
      final videoUrl = await _videoService.getVideoUrl(widget.video.videoUrl);
      print('[VideoPlayer] Retrieved video URL: $videoUrl');
      
      print('[VideoPlayer] Creating controller for ${kIsWeb ? 'web' : 'file'} playback');
      _controller = kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(videoUrl))
          : VideoPlayerController.file(File(videoUrl));

      print('[VideoPlayer] Initializing controller');
      await _controller?.initialize();
      
      final value = _controller?.value;
      print('[VideoPlayer] Controller initialized:');
      print('[VideoPlayer] - Video size: ${value?.size}');
      print('[VideoPlayer] - Duration: ${value?.duration}');
      print('[VideoPlayer] - Is playing: ${value?.isPlaying}');
      print('[VideoPlayer] - Position: ${value?.position}');
      print('[VideoPlayer] - Buffered: ${value?.buffered}');
      
      await _controller?.setLooping(true);
      print('[VideoPlayer] Looping enabled');
      
      if (widget.isActive) {
        print('[VideoPlayer] Video is active, starting playback');
        _controller?.play();
      } else if (widget.shouldPreload) {
        print('[VideoPlayer] Preloading video without playback');
        await _controller?.setVolume(0);
        await _controller?.seekTo(Duration.zero);
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          print('[VideoPlayer] State updated: initialized = true');
        });
      } else {
        print('[VideoPlayer] Widget not mounted after initialization');
      }
    } catch (e, stackTrace) {
      print('[VideoPlayer] Error initializing video:');
      print('[VideoPlayer] Error: $e');
      print('[VideoPlayer] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isInitialized = false;
          print('[VideoPlayer] State updated: initialized = false due to error');
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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

  void _handleLike() {
    // Optimistically update UI
    setState(() {
      if (_isLiked) {
        _likeCount--;
      } else {
        _likeCount++;
      }
      _isLiked = !_isLiked;
    });

    // Update backend
    _videoService.likeVideo(
      widget.video.id,
      onLikeUpdated: (isLiked, newCount) {
        if (mounted) {
          setState(() {
            _isLiked = isLiked;
            _likeCount = newCount;
          });
        }
      },
    );
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

  void _showShareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final size = MediaQuery.of(context).size;
    print('[VideoPlayer] Building video player. Screen size: ${size.width} x ${size.height}');
    print('[VideoPlayer] Initialized: $_isInitialized, Active: ${widget.isActive}');
    
    if (_controller?.value.hasError ?? false) {
      print('[VideoPlayer] Controller has error: ${_controller?.value.errorDescription}');
    }

    if (_isInitialized && _controller != null) {
      print('[VideoPlayer] Video aspect ratio: ${_controller!.value.aspectRatio}');
      print('[VideoPlayer] Container color: ${Colors.transparent}');
    }

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video Layer
          Positioned.fill(
            child: _isInitialized && _controller != null
                ? GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      color: Colors.black,
                      child: Center(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            print('[VideoPlayer] Layout constraints: ${constraints.maxWidth} x ${constraints.maxHeight}');
                            
                            // Calculate video dimensions to maintain aspect ratio
                            final videoAspectRatio = _controller!.value.aspectRatio;
                            final screenAspectRatio = constraints.maxWidth / constraints.maxHeight;
                            
                            double videoWidth;
                            double videoHeight;
                            
                            if (videoAspectRatio < screenAspectRatio) {
                              // Video is taller than screen
                              videoWidth = constraints.maxWidth;
                              videoHeight = videoWidth / videoAspectRatio;
                            } else {
                              // Video is wider than screen
                              videoHeight = constraints.maxHeight;
                              videoWidth = videoHeight * videoAspectRatio;
                            }
                            
                            print('[VideoPlayer] Calculated video size: $videoWidth x $videoHeight');
                            
                            return Container(
                              width: videoWidth,
                              height: videoHeight,
                              color: Colors.black,
                              child: VideoPlayer(_controller!),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                : Container(
                    color: Colors.black,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 16),
                          Text(
                            'Initializing Video...',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // Video info overlay at bottom
          Positioned(
            left: 16,
            right: 72,
            bottom: MediaQuery.of(context).padding.bottom + 80,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    shadows: [
                      Shadow(
                        blurRadius: 4.0,
                        color: Colors.black,
                        offset: Offset(1.0, 1.0),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Right side action buttons
          Positioned(
            right: 8,
            bottom: MediaQuery.of(context).padding.bottom + 120,
            child: Column(
              children: [
                _ActionButton(
                  icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                  iconColor: _isLiked ? Colors.red : Colors.white,
                  label: _likeCount.toString(),
                  onTap: _handleLike,
                ),
                const SizedBox(height: 16),
                _ActionButton(
                  icon: Icons.comment,
                  label: _commentCount.toString(),
                  onTap: _showComments,
                ),
                const SizedBox(height: 16),
                _ActionButton(
                  icon: Icons.share,
                  label: _shareCount.toString(),
                  onTap: _showShareSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: iconColor ?? Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 