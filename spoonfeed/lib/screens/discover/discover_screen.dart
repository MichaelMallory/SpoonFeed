import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/video_player_fullscreen.dart';
import '../../models/video_model.dart';
import '../../services/video/video_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({Key? key}) : super(key: key);

  @override
  _DiscoverScreenState createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final VideoService _videoService = VideoService();
  final PageController _pageController = PageController();
  final List<VideoModel> _videos = [];
  bool _isLoading = true;
  bool _isFullScreenMode = false;
  int _currentVideoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    print('[DiscoverScreen] Starting to load videos...');
    setState(() => _isLoading = true);

    try {
      print('[DiscoverScreen] Calling getDiscoverFeedVideos...');
      final docs = await _videoService.getDiscoverFeedVideos();
      print('[DiscoverScreen] Received ${docs.length} videos from service');
      
      final videos = docs.map((doc) {
        print('[DiscoverScreen] Processing video doc: ${doc['id']}');
        print('[DiscoverScreen] - thumbnailUrl: ${doc['thumbnailUrl']}');
        print('[DiscoverScreen] - status: ${doc['status']}');
        return VideoModel.fromFirestore(doc);
      }).toList();
      
      print('[DiscoverScreen] Converted ${videos.length} videos to models');
      
      setState(() {
        _videos.clear(); // Clear existing videos before adding new ones
        _videos.addAll(videos);
        _isLoading = false;
      });
      
      print('[DiscoverScreen] Updated state with ${_videos.length} videos');
    } catch (e, stackTrace) {
      print('[DiscoverScreen] Error loading discover videos:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      setState(() => _isLoading = false);
    }
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.6,
        crossAxisSpacing: 1,
        mainAxisSpacing: 1,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              _isFullScreenMode = true;
              _currentVideoIndex = index;
            });
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (video.thumbnailUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: video.thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey[900],
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey[900],
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library, color: Colors.white, size: 32),
                        SizedBox(height: 4),
                        Text(
                          'Video',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Container(
                  color: Colors.grey[900],
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library, color: Colors.white, size: 32),
                      SizedBox(height: 4),
                      Text(
                        'Video',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              Positioned(
                bottom: 8,
                left: 8,
                child: Row(
                  children: [
                    const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${video.likes}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        shadows: [
                          Shadow(
                            blurRadius: 2.0,
                            color: Colors.black,
                            offset: Offset(1.0, 1.0),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFullScreenVideos() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            itemCount: _videos.length,
            onPageChanged: (index) {
              setState(() => _currentVideoIndex = index);
              // Ensure the PageController is at the correct position
              if (_pageController.page?.round() != index) {
                _pageController.jumpToPage(index);
              }
            },
            itemBuilder: (context, index) {
              final video = _videos[index];
              return VideoPlayerFullscreen(
                key: ValueKey('fullscreen-${video.id}-$index'),
                video: video,
                isActive: index == _currentVideoIndex,
                shouldPreload: index == _currentVideoIndex + 1 || index == _currentVideoIndex - 1,
                onRetry: () {
                  setState(() {
                    // Force rebuild of the video player
                    _videos[index] = _videos[index];
                  });
                },
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => setState(() => _isFullScreenMode = false),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreenMode) {
      // Ensure the PageController is at the correct position when entering fullscreen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_pageController.hasClients && _pageController.page?.round() != _currentVideoIndex) {
          _pageController.jumpToPage(_currentVideoIndex);
        }
      });
      return _buildFullScreenVideos();
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: Colors.black,
      body: RefreshIndicator(
        onRefresh: _loadVideos,
        child: _videos.isEmpty
            ? const Center(
                child: Text(
                  'No videos found',
                  style: TextStyle(color: Colors.white),
                ),
              )
            : _buildVideoGrid(),
      ),
    );
  }
} 