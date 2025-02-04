import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/video_player_fullscreen.dart';
import '../../models/video_model.dart';
import '../../services/video_service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final VideoService _videoService = VideoService();
  final PageController _pageController = PageController();
  final List<VideoModel> _videos = [];
  bool _isLoadingMore = false;
  int _currentVideoIndex = 0;

  @override
  void initState() {
    super.initState();
    print('FeedScreen: Initializing');
    _loadInitialVideos();
  }

  @override
  void dispose() {
    print('FeedScreen: Disposing');
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialVideos() async {
    print('FeedScreen: Loading initial videos');
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final docs = await _videoService.loadMoreVideos();
      final videos = docs.map((doc) => VideoModel.fromFirestore(doc)).toList();
      print('FeedScreen: Loaded ${videos.length} initial videos');

      setState(() {
        _videos.addAll(videos);
        _isLoadingMore = false;
      });
    } catch (e) {
      print('FeedScreen: Error loading initial videos - $e');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreVideos() async {
    if (!_isLoadingMore && _videoService.hasMoreVideos) {
      print('FeedScreen: Loading more videos');
      setState(() {
        _isLoadingMore = true;
      });

      try {
        final docs = await _videoService.loadMoreVideos();
        final videos = docs.map((doc) => VideoModel.fromFirestore(doc)).toList();
        print('FeedScreen: Loaded ${videos.length} more videos');

        setState(() {
          _videos.addAll(videos);
          _isLoadingMore = false;
        });
      } catch (e) {
        print('FeedScreen: Error loading more videos - $e');
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    print('FeedScreen: Page changed to $index');
    setState(() {
      _currentVideoIndex = index;
    });
    
    // Load more videos when approaching the end
    if (index >= _videos.length - 2) {
      _loadMoreVideos();
    }
  }

  bool _shouldPreloadVideo(int index) {
    // Preload the next video and keep the previous video in memory
    return index == _currentVideoIndex + 1 || index == _currentVideoIndex - 1;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    print('FeedScreen: Building with screen size ${size.width}x${size.height}');

    if (_videos.isEmpty && !_isLoadingMore) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Full screen PageView for videos
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              print('FeedScreen: Building video at index $index');
              final video = _videos[index];
              return VideoPlayerFullscreen(
                key: ValueKey(video.id), // Add key for better widget recycling
                video: video,
                isActive: index == _currentVideoIndex,
                shouldPreload: _shouldPreloadVideo(index),
              );
            },
          ),

          // Top navigation
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'For You',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 