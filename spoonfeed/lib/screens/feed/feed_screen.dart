import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../components/video_player_fullscreen.dart';
import '../../components/spoon_slash_game.dart';
import '../../components/spoon_slash_game_widget.dart';
import '../../models/video_model.dart';
import '../../services/video_service.dart';
import '../../services/game_service.dart';

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
    print('[FeedScreen] Loading initial videos');
    print('[FeedScreen] Current videos count: ${_videos.length}');
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final docs = await _videoService.loadMoreVideos();
      print('[FeedScreen] Retrieved ${docs.length} video documents from Firestore');
      
      final videos = docs.map((doc) {
        final video = VideoModel.fromFirestore(doc);
        print('[FeedScreen] Parsed video: ${video.id} - ${video.title}');
        return video;
      }).toList();
      
      print('[FeedScreen] Successfully parsed ${videos.length} videos');

      setState(() {
        _videos.addAll(videos);
        _isLoadingMore = false;
        print('[FeedScreen] Updated state - Total videos: ${_videos.length}');
      });
    } catch (e, stackTrace) {
      print('[FeedScreen] Error loading initial videos:');
      print('[FeedScreen] Error: $e');
      print('[FeedScreen] Stack trace: $stackTrace');
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreVideos() async {
    if (!_isLoadingMore && _videoService.hasMoreVideos) {
      print('[FeedScreen] Loading more videos');
      print('[FeedScreen] Current video count: ${_videos.length}');
      setState(() {
        _isLoadingMore = true;
      });

      try {
        final docs = await _videoService.loadMoreVideos();
        print('[FeedScreen] Retrieved ${docs.length} additional video documents');
        
        final videos = docs.map((doc) {
          final video = VideoModel.fromFirestore(doc);
          print('[FeedScreen] Parsed additional video: ${video.id} - ${video.title}');
          return video;
        }).toList();

        setState(() {
          _videos.addAll(videos);
          _isLoadingMore = false;
          print('[FeedScreen] Updated state - New total: ${_videos.length}');
        });
      } catch (e, stackTrace) {
        print('[FeedScreen] Error loading more videos:');
        print('[FeedScreen] Error: $e');
        print('[FeedScreen] Stack trace: $stackTrace');
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onPageChanged(int index) {
    print('[FeedScreen] Page changed to index: $index');
    print('[FeedScreen] Video at index: ${_videos[index].title}');
    setState(() {
      _currentVideoIndex = index;
    });
    
    if (index >= _videos.length - 2) {
      print('[FeedScreen] Near end of list, loading more videos');
      _loadMoreVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    print('[FeedScreen] Building feed screen');
    print('[FeedScreen] Screen size: ${size.width} x ${size.height}');
    print('[FeedScreen] Videos loaded: ${_videos.length}');
    print('[FeedScreen] Current index: $_currentVideoIndex');
    print('[FeedScreen] Loading more: $_isLoadingMore');
    final gameService = Provider.of<GameService>(context);

    if (_videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Debug background
          Container(
            color: Colors.orange,
            child: Center(
              child: Text(
                'Feed Background',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),

          // Video section
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            left: 0,
            right: 0,
            height: gameService.isGameModeActive ? size.height / 2 : size.height,
            child: Container(
              color: Colors.purple.withOpacity(0.3),
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  final video = _videos[index];
                  print('[FeedScreen] Building video at index $index, current index: $_currentVideoIndex');
                  return SizedBox(
                    height: gameService.isGameModeActive ? size.height / 2 : size.height,
                    child: VideoPlayerFullscreen(
                      key: ValueKey(video.id),
                      video: video,
                      isActive: index == _currentVideoIndex,
                    ),
                  );
                },
              ),
            ),
          ),

          // Game section
          if (gameService.isGameModeActive)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              bottom: 0,
              left: 0,
              right: 0,
              height: size.height / 2,
              child: Container(
                color: Colors.cyan.withOpacity(0.3),
                child: SpoonSlashGameWidget(
                  onScoreChanged: (score) {
                    gameService.updateScore(score);
                  },
                ),
              ),
            ),

          // Top navigation
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
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

          // Game toggle button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white,
              ),
              onSelected: (String choice) {
                if (choice == 'toggleGame') {
                  print('Toggling game mode'); // Debug log
                  gameService.toggleGameMode();
                }
              },
              itemBuilder: (BuildContext context) => [
                PopupMenuItem<String>(
                  value: 'toggleGame',
                  child: Row(
                    children: [
                      Icon(
                        gameService.isGameModeActive ? Icons.sports_esports_outlined : Icons.sports_esports,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(gameService.isGameModeActive ? 'Disable Game Mode' : 'Enable Game Mode'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 