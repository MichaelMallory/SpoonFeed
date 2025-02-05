import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../services/game_service.dart';
import '../../models/user_model.dart';
import '../../models/game_score_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final GameService _gameService = GameService();
  UserModel? _user;
  GameScoreModel? _gameScore;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        Navigator.of(context).pushReplacementNamed('/auth');
        return;
      }

      final userData = await _authService.getUserData(currentUser.uid);
      final gameScore = await _gameService.getUserScore();
      
      if (mounted) {
        setState(() {
          _user = userData;
          _gameScore = gameScore;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: $e')),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final result = await Navigator.of(context).pushNamed('/profile-setup');
    if (result == true) {
      _loadUserData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Error loading profile'),
              ElevatedButton(
                onPressed: _loadUserData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
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
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Implement settings
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
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
                        _buildStat('Recipes', _user?.recipes.length ?? 0),
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
              // TODO: Add tabs for Videos, Recipes, Liked
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(
                  child: Text('Videos coming soon...'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
} 