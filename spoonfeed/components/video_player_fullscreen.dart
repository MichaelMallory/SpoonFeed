import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';
import '../services/video_service.dart';

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
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  final VideoService _videoService = VideoService();

  @override
  bool get wantKeepAlive => widget.isActive || widget.shouldPreload;

  @override
  void initState() {
    super.initState();
    print('Initializing video player for: ${widget.video.title}');
    _initializeVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerFullscreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      print('Video active state changed: ${widget.isActive}');
      if (widget.isActive) {
        _controller.play();
      } else {
        _controller.pause();
        if (!widget.shouldPreload) {
          _controller.setVolume(0);
          _controller.seekTo(Duration.zero);
        }
      }
    }
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.video.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller.initialize();
      print('Video initialized: ${_controller.value.size}');
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          if (widget.isActive) {
            _controller.play();
          } else if (widget.shouldPreload) {
            _controller.setVolume(0);
            _controller.seekTo(Duration.zero);
          }
        });
      }
      
      _controller.setLooping(true);
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    print('Disposing video player');
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
        _controller.setVolume(1.0);
      }
    });
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
            child: _isInitialized
                ? GestureDetector(
                    onTap: _togglePlayPause,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),

          // Video info overlay at bottom
          Positioned(
            left: 16,
            right: 72,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.video.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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
            bottom: 80,
            child: Column(
              children: [
                _ActionButton(
                  icon: Icons.favorite,
                  label: widget.video.likes.toString(),
                  onTap: () => _videoService.likeVideo(widget.video.id),
                ),
                const SizedBox(height: 16),
                _ActionButton(
                  icon: Icons.comment,
                  label: widget.video.comments.toString(),
                  onTap: () {},
                ),
                const SizedBox(height: 16),
                _ActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () {},
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

  const _ActionButton({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
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
              color: Colors.white,
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