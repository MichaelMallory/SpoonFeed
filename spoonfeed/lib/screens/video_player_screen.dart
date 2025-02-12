import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:spoonfeed/services/voice_command_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  // ... (existing code)
  @override
  _VideoPlayerScreenState createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  // ... (existing code)

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    
    // Connect to voice command service
    final voiceCommandService = Provider.of<VoiceCommandService>(context, listen: false);
    voiceCommandService.setVideoController(_controller);
  }

  @override
  void dispose() {
    // Clear video controller from voice command service
    final voiceCommandService = Provider.of<VoiceCommandService>(context, listen: false);
    voiceCommandService.setVideoController(null);
    
    _controller?.dispose();
    super.dispose();
  }

  // ... (rest of the existing code)
} 