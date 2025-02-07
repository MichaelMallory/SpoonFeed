import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../components/video_player_fullscreen.dart';
import '../../models/video_model.dart';
import '../../services/video/video_service.dart';

class UserVideosScreen extends StatefulWidget {
  final String userId;

  const UserVideosScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  _UserVideosScreenState createState() => _UserVideosScreenState();
}

class _UserVideosScreenState extends State<UserVideosScreen> {
  final VideoService _videoService = VideoService();
  final PageController _pageController = PageController();
  final List<VideoModel> _videos = [];
  bool _isLoading = true;
  int _currentVideoIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadUserVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserVideos() async {
    setState(() => _isLoading = true);

    try {
      final docs = await _videoService.getUserVideos(widget.userId);
      setState(() {
        _videos.addAll(
          docs.map((doc) => VideoModel.fromFirestore(doc)).toList(),
        );
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user videos: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentVideoIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos.isEmpty) {
      return const Center(
        child: Text('No videos found'),
      );
    }

    return PageView.builder(
      scrollDirection: Axis.vertical,
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final video = _videos[index];
        return VideoPlayerFullscreen(
          key: ValueKey(video.id),
          video: video,
          isActive: index == _currentVideoIndex,
          shouldPreload: index == _currentVideoIndex + 1 || index == _currentVideoIndex - 1,
        );
      },
    );
  }
} 