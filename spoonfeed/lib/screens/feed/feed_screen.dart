import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flame/game.dart';
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
  bool _isDragging = false;
  double _dragStartY = 0;

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
    
    // Update current video context in GameService
    final gameService = Provider.of<GameService>(context, listen: false);
    final video = _videos[index];
    gameService.setCurrentVideo(video);
    
    // Load more videos when user reaches near the end
    if (_hasMoreVideos && index >= _videos.length - 3) {
      _loadMoreVideos();
    }
  }

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragStartY = details.localPosition.dy;
  }
  
  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    
    final delta = details.primaryDelta ?? 0;
    if (delta.abs() > 20) { // Add some threshold to prevent accidental swipes
      if (delta > 0 && _currentVideoIndex > 0) {
        // Swipe down, go to previous video
        _pageController.previousPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        _isDragging = false;
      } else if (delta < 0 && _currentVideoIndex < _videos.length - 1) {
        // Swipe up, go to next video
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
        _isDragging = false;
      }
    }
  }
  
  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
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

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // Video feed layer
          Consumer<GameService>(
            builder: (context, gameService, child) {
              final isGameActive = gameService.isGameModeActive;
              print('[FeedScreen] Game active: $isGameActive');
              
              // Set initial video context if not set
              if (_videos.isNotEmpty && gameService.currentVideoId == null) {
                gameService.setCurrentVideo(_videos[_currentVideoIndex]);
              }
              
              return SizedBox.expand(
                child: Column(
                  children: [
                    // Video section - full height or half height depending on game state
                    Expanded(
                      flex: isGameActive ? 1 : 2,  // Take half space when game active, full space otherwise
                      child: GestureDetector(
                        // Only handle vertical drags that start in the top half during game mode
                        onVerticalDragStart: (details) {
                          if (!isGameActive || details.localPosition.dy < screenSize.height / 2) {
                            // Allow the drag to start if not in game mode, or if in game mode and in top half
                            _handleDragStart(details);
                          }
                        },
                        onVerticalDragUpdate: (details) {
                          if (_isDragging) {
                            _handleDragUpdate(details);
                          }
                        },
                        onVerticalDragEnd: (details) {
                          if (_isDragging) {
                            _handleDragEnd(details);
                          }
                        },
                        child: PageView.builder(
                          scrollDirection: Axis.vertical,
                          controller: _pageController,
                          onPageChanged: _onPageChanged,
                          // Always use NeverScrollableScrollPhysics since we're handling gestures manually
                          physics: const NeverScrollableScrollPhysics(),
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
                      ),
                    ),
                    // Add placeholder for game area when game is active
                    if (isGameActive)
                      const Expanded(
                        flex: 1,
                        child: SizedBox(), // Transparent placeholder
                      ),
                  ],
                ),
              );
            },
          ),

          // Game layer - Must be last in stack to be on top
          Consumer<GameService>(
            builder: (context, gameService, child) {
              if (!gameService.isGameModeActive) return const SizedBox.shrink();
              
              final screenSize = MediaQuery.of(context).size;
              final gameHeight = screenSize.height / 2;
              
              return Stack(
                children: [
                  // Purple background - bottom half only
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: gameHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.purple.withOpacity(0.6),
                            Colors.purple.withOpacity(0.8),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Game container - full screen for movement
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: gameHeight,
                    child: SpoonSlashGameWidget(
                      onScoreChanged: (score) {
                        // Update GameService with the new score
                        final gameService = Provider.of<GameService>(context, listen: false);
                        gameService.updateScore(score);
                        print('[FeedScreen] Game score updated: $score');
                      },
                    ),
                  ),
                ],
              );
            },
          ),

          // UI Overlay elements
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Your SpoonFeed',
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
            right: 12,
            child: Consumer<GameService>(
              builder: (context, gameService, child) {
                print('[FeedScreen] Building game dots, isActive: ${gameService.isGameModeActive}');
                return _buildGameDots(context, gameService);
              },
            ),
          ),
        ],
      ),
    );
  }
} 