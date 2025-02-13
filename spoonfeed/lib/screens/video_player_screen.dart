import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spoonfeed/services/voice_command_service.dart';
import 'package:spoonfeed/components/recipe_viewer.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? recipe;

  const VideoPlayerScreen({
    Key? key,
    required this.videoUrl,
    required this.title,
    this.recipe,
  }) : super(key: key);

  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _showRecipe = false;
  List<String> _ingredients = [];
  List<String> _steps = [];

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _parseRecipe();
    
    // Connect to voice command service
    final voiceCommandService = Provider.of<VoiceCommandService>(context, listen: false);
    voiceCommandService.setVideoController(_controller);
  }

  void _parseRecipe() {
    if (widget.recipe != null) {
      final lines = widget.recipe!.split('\n');
      bool inIngredients = false;
      bool inSteps = false;

      for (final line in lines) {
        if (line.toLowerCase().contains('ingredients:')) {
          inIngredients = true;
          inSteps = false;
          continue;
        } else if (line.toLowerCase().contains('instructions:') || 
                   line.toLowerCase().contains('steps:') ||
                   line.toLowerCase().contains('directions:')) {
          inIngredients = false;
          inSteps = true;
          continue;
        }

        if (line.trim().isNotEmpty) {
          if (inIngredients) {
            _ingredients.add(line.trim());
          } else if (inSteps) {
            _steps.add(line.trim());
          }
        }
      }
    }
  }

  Future<void> _initializePlayer() async {
    _controller = VideoPlayerController.network(widget.videoUrl);
    await _controller.initialize();
    setState(() {});
  }

  @override
  void dispose() {
    // Clear video controller from voice command service
    final voiceCommandService = Provider.of<VoiceCommandService>(context, listen: false);
    voiceCommandService.setVideoController(null);
    
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Video Player
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
          
          // Controls Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                if (widget.recipe != null)
                  IconButton(
                    icon: Icon(_showRecipe ? Icons.close : Icons.restaurant_menu),
                    onPressed: () {
                      setState(() {
                        _showRecipe = !_showRecipe;
                      });
                    },
                  ),
              ],
            ),
          ),
          
          // Recipe Viewer
          if (_showRecipe && widget.recipe != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: RecipeViewer(
                title: widget.title,
                ingredients: _ingredients,
                steps: _steps,
                onClose: () {
                  setState(() {
                    _showRecipe = false;
                  });
                },
              ),
            ),
            
          // Play/Pause Button Overlay
          Center(
            child: IconButton(
              icon: Icon(
                _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 48,
                color: Colors.white.withOpacity(0.8),
              ),
              onPressed: () {
                setState(() {
                  _controller.value.isPlaying
                      ? _controller.pause()
                      : _controller.play();
                });
              },
            ),
          ),
        ],
      ),
    );
  }
} 