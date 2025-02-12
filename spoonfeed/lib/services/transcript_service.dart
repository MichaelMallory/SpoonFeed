import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import '../models/video_transcript.dart';

/// Service for managing video transcripts in Firestore
class TranscriptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _logger = Logger();

  /// Collection reference for transcripts
  CollectionReference<Map<String, dynamic>> get _transcripts =>
      _firestore.collection('transcripts');

  /// Create or update a transcript
  Future<void> saveTranscript(VideoTranscript transcript) async {
    try {
      _logger.i('💾 Saving transcript for video ${transcript.videoId}');
      await _transcripts.doc(transcript.videoId).set(
            transcript.toMap(),
            SetOptions(merge: true),
          );
      _logger.i('✅ Transcript saved successfully');
    } catch (e) {
      _logger.e('❌ Failed to save transcript: $e');
      rethrow;
    }
  }

  /// Get a transcript by video ID
  Future<VideoTranscript?> getTranscript(String videoId) async {
    try {
      _logger.i('🔍 Fetching transcript for video $videoId');
      final doc = await _transcripts.doc(videoId).get();
      
      if (!doc.exists) {
        _logger.w('⚠️ No transcript found for video $videoId');
        return null;
      }

      final transcript = VideoTranscript.fromFirestore(doc);
      
      // Update last accessed timestamp
      await _transcripts.doc(videoId).update({
        'metadata.lastAccessed': FieldValue.serverTimestamp(),
      });
      
      _logger.i('✅ Transcript retrieved successfully');
      return transcript;
    } catch (e) {
      _logger.e('❌ Failed to get transcript: $e');
      rethrow;
    }
  }

  /// Mark a transcript as processing
  Future<void> markAsProcessing(String videoId) async {
    try {
      _logger.i('⏳ Marking transcript $videoId as processing');
      final transcript = VideoTranscript.processing(videoId);
      await saveTranscript(transcript);
      _logger.i('✅ Transcript marked as processing');
    } catch (e) {
      _logger.e('❌ Failed to mark transcript as processing: $e');
      rethrow;
    }
  }

  /// Mark a transcript as failed with error
  Future<void> markAsFailed(String videoId, String error) async {
    try {
      _logger.e('❌ Marking transcript $videoId as failed: $error');
      final transcript = VideoTranscript.error(videoId, error);
      await saveTranscript(transcript);
      _logger.i('✅ Transcript marked as failed');
    } catch (e) {
      _logger.e('❌ Failed to mark transcript as failed: $e');
      rethrow;
    }
  }

  /// Search for transcripts containing specific text
  Future<List<VideoTranscript>> searchTranscripts(String query) async {
    try {
      _logger.i('🔍 Searching transcripts for: "$query"');
      final querySnapshot = await _transcripts
          .where('segments', arrayContains: {'text': query})
          .get();

      final transcripts = querySnapshot.docs
          .map((doc) => VideoTranscript.fromFirestore(doc))
          .toList();

      _logger.i('✅ Found ${transcripts.length} matching transcripts');
      return transcripts;
    } catch (e) {
      _logger.e('❌ Failed to search transcripts: $e');
      rethrow;
    }
  }

  /// Delete a transcript
  Future<void> deleteTranscript(String videoId) async {
    try {
      _logger.i('🗑️ Deleting transcript for video $videoId');
      await _transcripts.doc(videoId).delete();
      _logger.i('✅ Transcript deleted successfully');
    } catch (e) {
      _logger.e('❌ Failed to delete transcript: $e');
      rethrow;
    }
  }

  /// Stream transcript updates for a video
  Stream<VideoTranscript?> streamTranscript(String videoId) {
    return _transcripts.doc(videoId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return VideoTranscript.fromFirestore(doc);
    });
  }
} 