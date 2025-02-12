import 'package:cloud_functions/cloud_functions.dart';

/// Service for handling video transcription and voice command processing using OpenAI's Whisper API
class WhisperService {
  final FirebaseFunctions _functions;

  WhisperService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Transcribes a video file and returns timestamped segments
  Future<Map<String, dynamic>> transcribeVideo(String videoUrl) async {
    try {
      final result = await _functions.httpsCallable('transcribeVideo').call({
        'videoUrl': videoUrl,
      });
      
      return result.data;
    } catch (e) {
      print('Error transcribing video: $e');
      rethrow;
    }
  }

  /// Transcribes a voice command and returns the text
  Future<String> transcribeVoiceCommand(String audioBase64) async {
    try {
      final result = await _functions.httpsCallable('transcribeVoiceCommand').call({
        'audioData': audioBase64,
      });
      
      return result.data['text'];
    } catch (e) {
      print('Error transcribing voice command: $e');
      rethrow;
    }
  }
} 