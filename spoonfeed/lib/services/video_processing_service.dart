import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import './transcript_service.dart';

/// Service for processing videos and generating transcripts
class VideoProcessingService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final TranscriptService _transcriptService;
  final _logger = Logger();
  final _uuid = Uuid();

  VideoProcessingService({TranscriptService? transcriptService}) 
      : _transcriptService = transcriptService ?? TranscriptService();

  /// Upload a video file and start the transcription process
  Future<String> processVideo(File videoFile) async {
    try {
      // Generate a unique ID for the video
      final videoId = _uuid.v4();
      _logger.i('🎥 Starting video processing for ID: $videoId');

      // Mark transcript as processing
      await _transcriptService.markAsProcessing(videoId);

      // Upload video to Firebase Storage
      final videoRef = _storage.ref().child('videos/$videoId/${path.basename(videoFile.path)}');
      _logger.i('📤 Uploading video to storage');
      
      final metadata = SettableMetadata(
        contentType: 'video/mp4',
        customMetadata: {
          'videoId': videoId,
          'originalName': path.basename(videoFile.path),
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      await videoRef.putFile(videoFile, metadata);
      final videoUrl = await videoRef.getDownloadURL();
      _logger.i('✅ Video uploaded successfully');

      // Trigger Cloud Function for transcription
      _logger.i('🔄 Triggering transcription function');
      final callable = _functions.httpsCallable('generateTranscript');
      await callable.call({
        'videoId': videoId,
        'videoUrl': videoUrl,
      });

      _logger.i('✅ Transcription process initiated');
      return videoId;
    } catch (e) {
      _logger.e('❌ Failed to process video: $e');
      if (e is FirebaseFunctionsException) {
        await _transcriptService.markAsFailed(
          e.details['videoId'] ?? 'unknown',
          'Failed to process video: ${e.message}',
        );
      }
      rethrow;
    }
  }

  /// Get the processing status of a video
  Future<Map<String, dynamic>> getProcessingStatus(String videoId) async {
    try {
      _logger.i('🔍 Checking processing status for video: $videoId');
      final transcript = await _transcriptService.getTranscript(videoId);
      
      if (transcript == null) {
        return {
          'status': 'not_found',
          'message': 'No processing record found for this video',
        };
      }

      if (transcript.error != null) {
        return {
          'status': 'error',
          'message': transcript.error,
        };
      }

      if (transcript.isProcessing) {
        return {
          'status': 'processing',
          'message': 'Video is currently being processed',
        };
      }

      return {
        'status': 'completed',
        'message': 'Processing completed successfully',
        'segments': transcript.segments.length,
      };
    } catch (e) {
      _logger.e('❌ Failed to get processing status: $e');
      rethrow;
    }
  }

  /// Cancel video processing and cleanup resources
  Future<void> cancelProcessing(String videoId) async {
    try {
      _logger.i('🛑 Cancelling processing for video: $videoId');
      
      // Delete video from storage
      final videoRef = _storage.ref().child('videos/$videoId');
      await videoRef.listAll().then((result) {
        return Future.wait(
          result.items.map((ref) => ref.delete()),
        );
      });

      // Delete transcript
      await _transcriptService.deleteTranscript(videoId);
      
      _logger.i('✅ Processing cancelled and resources cleaned up');
    } catch (e) {
      _logger.e('❌ Failed to cancel processing: $e');
      rethrow;
    }
  }

  /// Stream processing status updates
  Stream<Map<String, dynamic>> streamProcessingStatus(String videoId) {
    return _transcriptService.streamTranscript(videoId).map((transcript) {
      if (transcript == null) {
        return {
          'status': 'not_found',
          'message': 'No processing record found',
        };
      }

      if (transcript.error != null) {
        return {
          'status': 'error',
          'message': transcript.error,
        };
      }

      if (transcript.isProcessing) {
        return {
          'status': 'processing',
          'message': 'Video is being processed',
        };
      }

      return {
        'status': 'completed',
        'message': 'Processing completed successfully',
        'segments': transcript.segments.length,
      };
    });
  }
} 