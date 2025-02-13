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
import '../../utils/texture_painter.dart';
import 'dart:async';

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
  bool _isInitialLoadComplete = false;
  Timer? _preloadTimer;

  @override
  void initState() {
    super.initState();
    _loadInitialVideos();
  }

  @override
  void dispose() {
    _preloadTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialVideos() async {
    if (_isLoadingMore) {
      print('[FeedScreen] 🚫 Skipping initial load - already loading');
      return;
    }
    setState(() => _isLoadingMore = true);

    try {
      print('[FeedScreen] 🎬 Loading initial videos...');
      print('  - Current video count: ${_videos.length}');
      print('  - Has more videos: $_hasMoreVideos');
      
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _videoService.loadMoreVideos();
      
      if (snapshot.docs.isEmpty) {
        print('[FeedScreen] ℹ️ No videos found in initial load');
        setState(() {
          _hasMoreVideos = false;
          _isLoadingMore = false;
        });
        return;
      }

      print('[FeedScreen] ✅ Loaded ${snapshot.docs.length} initial videos');
      final List<VideoModel> videos = [];
      
      for (final doc in snapshot.docs) {
        try {
          final video = VideoModel.fromFirestore(doc);
          videos.add(video);
          print('  ✓ Parsed video: ${video.id} - ${video.title}');
        } catch (e) {
          print('  ⚠️ Error parsing video:');
          print('    - Document ID: ${doc.id}');
          print('    - Error: $e');
        }
      }
      
      print('[FeedScreen] 📱 Successfully parsed ${videos.length} valid videos');
      
      if (videos.isEmpty) {
        print('[FeedScreen] ⚠️ No valid videos after parsing');
        setState(() {
          _hasMoreVideos = false;
          _isLoadingMore = false;
        });
        return;
      }

      setState(() {
        _videos.clear();
        _videos.addAll(videos);
        _lastDocument = snapshot.docs.last;
        _isLoadingMore = false;
        _isInitialLoadComplete = true;
      });

      // Set initial video in GameService
      if (_videos.isNotEmpty) {
        final gameService = Provider.of<GameService>(context, listen: false);
        gameService.setCurrentVideo(_videos[0]);
        print('  ✅ Set initial video in GameService: ${_videos[0].id}');
      }

      print('[FeedScreen] 🔄 Updated state:');
      print('  - Video count: ${_videos.length}');
      print('  - Last document ID: ${_lastDocument?.id}');

      // Preload the first few videos with a longer delay to ensure UI is ready
      if (videos.isNotEmpty) {
        _preloadTimer?.cancel();
        _preloadTimer = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            print('[FeedScreen] 🎯 Triggering preload for initial videos');
            setState(() {}); // Trigger rebuild to start preloading
          }
        });
      }
    } catch (e, stackTrace) {
      print('[FeedScreen] ❌ Error loading initial videos:');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _hasMoreVideos = false;
        });
      }
    }
  }

  Future<void> _loadMoreVideos() async {
    if (_isLoadingMore || !_hasMoreVideos || _lastDocument == null) {
      print('[FeedScreen] ℹ️ Skipping loadMoreVideos:');
      print('  - isLoadingMore: $_isLoadingMore');
      print('  - hasMoreVideos: $_hasMoreVideos');
      print('  - hasLastDocument: ${_lastDocument != null}');
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      print('[FeedScreen] 🎬 Loading more videos...');
      print('  - Current video count: ${_videos.length}');
      print('  - Last document ID: ${_lastDocument?.id}');

      final QuerySnapshot<Map<String, dynamic>> snapshot = await _videoService.loadMoreVideos(
        lastDocument: _lastDocument,
      );

      if (snapshot.docs.isEmpty) {
        print('[FeedScreen] ℹ️ No more videos available');
        setState(() {
          _hasMoreVideos = false;
          _isLoadingMore = false;
        });
        return;
      }

      final List<VideoModel> newVideos = [];
      for (final doc in snapshot.docs) {
        try {
          final video = VideoModel.fromFirestore(doc);
          // Check for duplicates
          if (!_videos.any((existing) => existing.id == video.id)) {
            newVideos.add(video);
            print('  ✓ Added new video: ${video.id} - ${video.title}');
          } else {
            print('  ⚠️ Skipped duplicate video: ${video.id}');
          }
        } catch (e) {
          print('  ❌ Error parsing video:');
          print('    - Document ID: ${doc.id}');
          print('    - Error: $e');
        }
      }

      print('[FeedScreen] ✅ Found ${newVideos.length} new valid videos');

      if (newVideos.isNotEmpty) {
        setState(() {
          _videos.addAll(newVideos);
          _lastDocument = snapshot.docs.last;
          _isLoadingMore = false;
        });

        print('[FeedScreen] 🔄 Updated state:');
        print('  - Total videos: ${_videos.length}');
        print('  - New last document ID: ${_lastDocument?.id}');

        // Trigger preload for new videos with a small delay
        _preloadTimer?.cancel();
        _preloadTimer = Timer(const Duration(milliseconds: 100), () {
          if (mounted) {
            print('[FeedScreen] 🎯 Triggering preload for new videos');
            setState(() {}); // Trigger rebuild to start preloading
          }
        });
      } else {
        print('[FeedScreen] ℹ️ No new valid videos to add');
        setState(() {
          _hasMoreVideos = snapshot.docs.length >= 10; // Assuming batch size of 10
          _isLoadingMore = false;
        });
      }
    } catch (e, stackTrace) {
      print('[FeedScreen] ❌ Error loading more videos:');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  void _verifyPreloadedVideos() {
    print('\n[FeedScreen] 🔍 Verifying preloaded videos:');
    print('  - Current index: $_currentVideoIndex');
    
    // Check next two videos
    for (int i = 1; i <= 2; i++) {
      final nextIndex = _currentVideoIndex + i;
      if (nextIndex < _videos.length) {
        print('  - Checking next video $i (index $nextIndex)');
        if (_shouldPreloadVideo(nextIndex)) {
          // Force a rebuild of this video to ensure it starts preloading
          setState(() {});
        }
      }
    }
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    
    print('\n[FeedScreen] 📄 Page changed:');
    print('  - Previous index: $_currentVideoIndex');
    print('  - New index: $index');
    print('  - Total videos: ${_videos.length}');
    print('  - Has more videos: $_hasMoreVideos');
    print('  - Is loading more: $_isLoadingMore');
    
    setState(() => _currentVideoIndex = index);
    
    // Update current video in GameService
    if (index >= 0 && index < _videos.length) {
      final gameService = Provider.of<GameService>(context, listen: false);
      gameService.setCurrentVideo(_videos[index]);
      print('  ✅ Updated current video in GameService: ${_videos[index].id}');
    }
    
    // Verify preloading of upcoming videos
    _verifyPreloadedVideos();
    
    // Load more videos when approaching the end
    if (_hasMoreVideos && index >= _videos.length - 3) {
      print('  ⚡ Triggering load more videos (index near end)');
      _loadMoreVideos();
    }
  }

  bool _shouldPreloadVideo(int index) {
    // Prioritize next videos over previous ones
    // Always preload next 2 videos, and only 1 previous video
    final shouldPreload = (index > _currentVideoIndex - 2 && index < _currentVideoIndex + 3) &&
           index != _currentVideoIndex &&
           index >= 0 &&
           index < _videos.length;
           
    print('[FeedScreen] 🔍 Preload check for index $index:');
    print('  - Current index: $_currentVideoIndex');
    print('  - Should preload: $shouldPreload');
    if (shouldPreload) {
      print('  - Priority: ${index > _currentVideoIndex ? "High (upcoming)" : "Low (previous)"}');
    }
    
    return shouldPreload;
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

  Future<void> _retryVideo(int index) async {
    print('\n[FeedScreen] 🔄 Retrying video at index $index');
    print('  - Current video count: ${_videos.length}');
    
    if (index < 0 || index >= _videos.length) {
      print('  ❌ Invalid index for retry');
      return;
    }

    final targetVideo = _videos[index];
    print('  - Target video ID: ${targetVideo.id}');

    try {
      // Fetch just the single video document
      final videoDoc = await FirebaseFirestore.instance
          .collection('videos')
          .doc(targetVideo.id)
          .get();

      if (!videoDoc.exists) {
        print('  ❌ Video document not found');
        return;
      }

      try {
        final updatedVideo = VideoModel.fromFirestore(videoDoc);
        if (mounted) {
          setState(() {
            // Update just this video in the list
            _videos[index] = updatedVideo;
          });
          
          // Update GameService if this is the current video
          if (index == _currentVideoIndex) {
            final gameService = Provider.of<GameService>(context, listen: false);
            gameService.setCurrentVideo(updatedVideo);
            print('  ✅ Updated current video in GameService: ${updatedVideo.id}');
          }
          
          print('\n[FeedScreen] ✅ Video refreshed successfully:');
          print('  - Video ID: ${updatedVideo.id}');
        }
      } catch (e) {
        print('  ❌ Error parsing video: ${videoDoc.id}');
        print('    Error: $e');
      }
    } catch (e) {
      print('  ❌ Error during retry: $e');
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
    print('\n[FeedScreen] 🏗️ Building feed screen:');
    print('  - Initial load complete: $_isInitialLoadComplete');
    print('  - Video count: ${_videos.length}');
    print('  - Current index: $_currentVideoIndex');
    print('  - Is loading more: $_isLoadingMore');

    // Verify preloaded videos on each build
    if (_isInitialLoadComplete && _videos.isNotEmpty) {
      _verifyPreloadedVideos();
    }

    if (!_isInitialLoadComplete) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Add empty state handling with retry
    if (_videos.isEmpty) {
      print('[FeedScreen] ⚠️ No videos available, showing empty state');
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.video_library_outlined,
                color: Colors.white.withOpacity(0.6),
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'No videos available',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  print('[FeedScreen] 🔄 Retrying video load');
                  setState(() {
                    _hasMoreVideos = true;
                    _lastDocument = null;
                    _isInitialLoadComplete = false;
                  });
                  _loadInitialVideos();
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Main content
          PageView.builder(
            scrollDirection: Axis.vertical,
            controller: _pageController,
            onPageChanged: _onPageChanged,
            physics: const BouncingScrollPhysics(),
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              if (index >= _videos.length) return const SizedBox.shrink();
              final video = _videos[index];
              return Container(
                key: ValueKey(video.id),
                child: VideoPlayerFullscreen(
                  video: video,
                  isActive: index == _currentVideoIndex,
                  shouldPreload: _shouldPreloadVideo(index),
                  isGameMode: Provider.of<GameService>(context).isGameModeActive,
                  onRetry: () => _retryVideo(index),
                ),
              );
            },
          ),

          // SafeArea overlay content
          SafeArea(
            child: Stack(
              children: [
                // Loading indicator at bottom when loading more
                if (_isLoadingMore)
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),

                // Header with title
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  color: Colors.black.withOpacity(0.2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Your SpoonFeed',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Consumer<GameService>(
                        builder: (context, gameService, child) {
                          print('[FeedScreen] Building game dots, isActive: ${gameService.isGameModeActive}');
                          return _buildGameDots(context, gameService);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Game layer - Must be last in stack to be on top
          Consumer<GameService>(
            builder: (context, gameService, child) {
              if (!gameService.isGameModeActive) return const SizedBox.shrink();
              
              final screenSize = MediaQuery.of(context).size;
              final gameHeight = screenSize.height / 2;
              
              return Stack(
                children: [
                  // Fixed game area container
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: gameHeight,
                      width: screenSize.width,
                      child: Stack(
                        children: [
                          // Game board texture background
                          Positioned.fill(
                            child: CustomPaint(
                              painter: WoodTexturePainter(),
                            ),
                          ),
                          // Game widget on top of texture
                          Positioned.fill(
                            child: SpoonSlashGameWidget(
                              onScoreChanged: (score) {
                                final gameService = Provider.of<GameService>(context, listen: false);
                                gameService.updateScore(score);
                                print('[FeedScreen] Game score updated: $score');
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
} 