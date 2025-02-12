import 'package:flutter/material.dart';
import '../services/voice_command_service.dart';
import '../services/command_parser_service.dart';
import '../models/command_intent.dart';
import 'package:provider/provider.dart';
import '../services/video_player_service.dart';

class WakeWordTestScreen extends StatelessWidget {
  const WakeWordTestScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final voiceService = Provider.of<VoiceCommandService>(context);
    final videoService = Provider.of<VideoPlayerService>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wake Word Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Wake Word Status: ${voiceService.isListeningForWakeWord ? "Listening" : "Not Listening"}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            if (voiceService.lastError != null)
              Text(
                'Error: ${voiceService.lastError}',
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (voiceService.isListeningForWakeWord) {
                  voiceService.dispose();
                } else {
                  voiceService.startListeningForWakeWord();
                }
              },
              child: Text(
                voiceService.isListeningForWakeWord ? 'Stop Listening' : 'Start Listening',
              ),
            ),
          ],
        ),
      ),
    );
  }
} 