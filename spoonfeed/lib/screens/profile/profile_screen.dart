import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../services/game_service.dart';
import '../../models/user_model.dart';
import '../../models/game_score_model.dart';
import '../../components/video_player_fullscreen.dart';
import '../../models/video_model.dart';
import '../../services/video/video_service.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;

  const ProfileScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final GameService _gameService = GameService();
  final VideoService _videoService = VideoService();
  UserModel? _user;
  GameScoreModel? _gameScore;
  bool _isLoading = true;
  final List<VideoModel> _videos = [];
  bool _isFullScreenMode = false;
  int _currentVideoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUserVideos();
    // Listen to game service changes
    _gameService.addListener(_onGameServiceChanged);
  }

  @override
  void dispose() {
    _gameService.removeListener(_onGameServiceChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _onGameServiceChanged() async {
    // Reload game score when GameService notifies of changes
    final gameScore = await _gameService.getUserScore();
    if (mounted) {
      setState(() {
        _gameScore = gameScore;
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      print('[ProfileScreen] Loading user data for ID: ${widget.userId}');
      final userData = await _authService.getUserData(widget.userId);
      final gameScore = await _gameService.getUserScore();
      
      if (mounted) {
        setState(() {
          _user = userData;
          _gameScore = gameScore;
          _isLoading = false;
        });
      }

      // Load videos after user data is loaded
      await _loadUserVideos();
    } catch (e) {
      print('[ProfileScreen] Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _loadUserVideos() async {
    try {
      print('[ProfileScreen] Loading videos for user: ${widget.userId}');
      final snapshot = await _videoService.getUserVideos(widget.userId);
      
      if (mounted) {
        setState(() {
          _videos.clear(); // Clear existing videos before adding new ones
          _videos.addAll(snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList());
        });
      }

      // Update video count in user document
      await _videoService.updateUserVideoCount(widget.userId);
      
      print('[ProfileScreen] Loaded ${_videos.length} videos');
    } catch (e) {
      print('[ProfileScreen] Error loading user videos: $e');
    }
  }

  Future<void> _editProfile() async {
    final result = await Navigator.of(context).pushNamed('/profile-setup');
    if (result == true) {
      _loadUserData();
    }
  }

  Widget _buildStat(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editProfile,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadUserData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Header
              Container(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Profile Picture
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _user?.photoUrl != null
                          ? CachedNetworkImageProvider(_user!.photoUrl!)
                          : null,
                      child: _user?.photoUrl == null
                          ? Text(
                              (_user?.displayName ?? _user?.username ?? 'A')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 32),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Display Name
                    Text(
                      _user?.displayName ?? _user?.username ?? 'Anonymous',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_user?.isChef == true)
                      Chip(
                        label: const Text('Chef'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        labelStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Bio
                    if (_user?.bio != null)
                      Text(
                        _user!.bio!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    const SizedBox(height: 16),
                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStat('Followers', _user?.followers.length ?? 0),
                        _buildStat('Following', _user?.following.length ?? 0),
                        _buildStat('Videos', _videos.length),
                      ],
                    ),
                    if (_gameScore != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),
                      Text(
                        'Spoon Slash Stats',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStat('High Score', _gameScore!.highScore),
                          _buildStat('Games Played', _gameScore!.gamesPlayed),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(),
              // Videos Grid
              if (_videos.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No videos yet',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: _buildVideoGrid(),
                ),
            ],
          ),
        ),
      ),
    );
  }
} 