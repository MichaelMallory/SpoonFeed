import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../components/video_player_fullscreen.dart';
import '../../components/spoon_slash_game.dart';
import '../../components/spoon_slash_game_widget.dart';
import '../../models/video_model.dart';
import '../../services/video/video_service.dart';
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
  bool _hasMoreVideos = true;
  DocumentSnapshot? _lastDocument;
  int _currentVideoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialVideos() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final docs = await _videoService.loadMoreVideos();
      if (docs.isEmpty) {
        setState(() {
          _hasMoreVideos = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _videos.clear(); // Clear existing videos
        _videos.addAll(docs.map((doc) => VideoModel.fromFirestore(doc)).toList());
        _lastDocument = docs.isNotEmpty ? docs.last['id'] : null;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('[FeedScreen] ❌ Error loading initial videos: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMoreVideos) return;

    setState(() => _isLoadingMore = true);

    try {
      final docs = await _videoService.loadMoreVideos(
        lastDocument: _lastDocument,
      );

      if (docs.isEmpty) {
        setState(() {
          _hasMoreVideos = false;
          _isLoadingMore = false;
        });
        return;
      }

      // Check for duplicates before adding
      final newVideos = docs.map((doc) => VideoModel.fromFirestore(doc)).where((video) {
        return !_videos.any((existing) => existing.id == video.id);
      }).toList();

      if (newVideos.isNotEmpty) {
        setState(() {
          _videos.addAll(newVideos);
          _lastDocument = docs.last['id'];
        });
      } else {
        _hasMoreVideos = false;
      }

      setState(() => _isLoadingMore = false);
    } catch (e) {
      print('[FeedScreen] ❌ Error loading more videos: $e');
      setState(() => _isLoadingMore = false);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentVideoIndex = index);
    
    // Load more videos when user reaches near the end
    if (_hasMoreVideos && index >= _videos.length - 3) {
      _loadMoreVideos();
    }
  }

  Widget _buildGameDots(BuildContext context, GameService gameService) {
    return GestureDetector(
      onTap: () => gameService.toggleGameMode(),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          Icons.sports_esports,
          color: gameService.isGameModeActive ? Colors.orange : Colors.white,
          size: 24,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('[FeedScreen] Building feed screen');
    final screenSize = MediaQuery.of(context).size;
    print('[FeedScreen] Screen size: ${screenSize.width} x ${screenSize.height}');
    
    if (_videos.isEmpty && !_isLoadingMore) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      children: [
        // Video feed - Make it take full screen or half screen when game is active
        Consumer<GameService>(
          builder: (context, gameService, child) {
            final isGameActive = gameService.isGameModeActive;
            print('[FeedScreen] Game active: $isGameActive');
            
            return Positioned(
              top: 0,
              left: 0,
              right: 0,
              // Take up full height if game not active, otherwise only top half
              bottom: isGameActive ? MediaQuery.of(context).size.height * 0.5 : 0,
              child: PageView.builder(
                scrollDirection: Axis.vertical,
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _videos.length,
                itemBuilder: (context, index) {
                  print('[FeedScreen] Building video item $index');
                  final video = _videos[index];
                  return VideoPlayerFullscreen(
                    key: ValueKey(video.id),
                    video: video,
                    isActive: index == _currentVideoIndex,
                    shouldPreload: index == _currentVideoIndex + 1 || index == _currentVideoIndex - 1,
                    isGameMode: isGameActive,
                  );
                },
              ),
            );
          },
        ),

        // Game dots in top right - Ensure it's above video
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 12,
          child: Consumer<GameService>(
            builder: (context, gameService, child) {
              print('[FeedScreen] Building game dots, isActive: ${gameService.isGameModeActive}');
              return _buildGameDots(context, gameService);
            },
          ),
        ),

        // Game overlay when active
        if (context.watch<GameService>().isGameModeActive)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.5,
            child: Stack(
              children: [
                SpoonSlashGameWidget(
                  onScoreChanged: (score) {
                    print('[FeedScreen] Game score updated: $score');
                    context.read<GameService>().updateScore(score);
                  },
                ),
                // Position interaction buttons below game area
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ... existing interaction buttons ...
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Top navigation - Keep it minimal
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 8,
            ),
            child: const Row(
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
    );
  }
} 