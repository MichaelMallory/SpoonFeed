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
  bool _isAuthenticated = false;
  final List<VideoModel> _videos = [];
  bool _isFullScreenMode = false;
  int _currentVideoIndex = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoadData();
  }

  @override
  void dispose() {
    _gameService.removeListener(_onGameServiceChanged);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndLoadData() async {
    try {
      // Wait for Firebase Auth to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isAuthenticated = false;
          });
        }
        return;
      }

      setState(() {
        _isAuthenticated = true;
      });

      // Now that we're authenticated, load the data
      await _loadUserData();
      _gameService.addListener(_onGameServiceChanged);
    } catch (e) {
      print('[ProfileScreen] Error checking auth state: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isAuthenticated = false;
        });
      }
    }
  }

  void _onGameServiceChanged() async {
    if (!_isAuthenticated) return;
    
    final gameScore = await _gameService.getUserScore();
    if (mounted) {
      setState(() {
        _gameScore = gameScore;
      });
    }
  }

  Future<void> _loadUserData() async {
    if (!_isAuthenticated) return;

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
    if (!_isAuthenticated) return;

    try {
      print('[ProfileScreen] Loading videos for user: ${widget.userId}');
      final snapshot = await _videoService.getUserVideos(widget.userId);
      
      if (mounted) {
        setState(() {
          _videos.clear();
          _videos.addAll(snapshot.docs.map((doc) => VideoModel.fromFirestore(doc)).toList());
        });
      }

      await _videoService.updateUserVideoCount(widget.userId);
      print('[ProfileScreen] Loaded ${_videos.length} videos');
    } catch (e) {
      print('[ProfileScreen] Error loading user videos: $e');
    }
  }

  Future<void> _editProfile() async {
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to edit your profile')),
      );
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in to view your profile',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/auth');
                },
                child: const Text('Sign In'),
              ),
            ],
          ),
        ),
      );
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
                        _buildStat('Videos', _videos.length),
                        _buildStat('Followers', _user?.followers.length ?? 0),
                        _buildStat('Following', _user?.following.length ?? 0),
                      ],
                    ),
                  ],
                ),
              ),
              // Videos Grid
              if (_videos.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Videos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => Scaffold(
                              backgroundColor: Colors.black,
                              body: SafeArea(
                                child: Stack(
                                  children: [
                                    VideoPlayerFullscreen(
                                      key: ValueKey('fullscreen-${video.id}-$index'),
                                      video: video,
                                      isActive: true,
                                      shouldPreload: false,
                                      onRetry: () {
                                        // Retry logic for video playback
                                        setState(() {
                                          // Trigger a rebuild to retry loading the video
                                        });
                                      },
                                    ),
                                    Positioned(
                                      top: 16,
                                      left: 16,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.arrow_back,
                                            color: Colors.white,
                                          ),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (video.thumbnailUrl != null)
                            CachedNetworkImage(
                              imageUrl: video.thumbnailUrl!,
                              fit: BoxFit.cover,
                            ),
                          const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else if (!_isLoading) ...[
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'No videos yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
} 