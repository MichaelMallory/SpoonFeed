import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a word with timing information
class TranscriptWord {
  final String word;
  final int start;    // Start time in milliseconds
  final int end;      // End time in milliseconds

  const TranscriptWord({
    required this.word,
    required this.start,
    required this.end,
  });

  factory TranscriptWord.fromMap(Map<String, dynamic> map) {
    return TranscriptWord(
      word: map['word'] as String,
      start: map['start'] as int,
      end: map['end'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'start': start,
      'end': end,
    };
  }
}

/// Represents a segment of transcribed video content
class TranscriptSegment {
  final int start;      // Start time in milliseconds
  final int end;        // End time in milliseconds
  final String text;    // Transcribed text
  final List<TranscriptWord> words;  // Word-level timing data
  final List<String> keywords;  // Extracted key terms for searching

  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
    required this.words,
    this.keywords = const [],
  });

  /// Create a TranscriptSegment from Firestore data
  factory TranscriptSegment.fromMap(Map<String, dynamic> map) {
    return TranscriptSegment(
      start: map['start'] as int,
      end: map['end'] as int,
      text: map['text'] as String,
      words: (map['words'] as List? ?? [])
          .map((word) => TranscriptWord.fromMap(word as Map<String, dynamic>))
          .toList(),
      keywords: List<String>.from(map['keywords'] ?? []),
    );
  }

  /// Convert to a map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'start': start,
      'end': end,
      'text': text,
      'words': words.map((word) => word.toMap()).toList(),
      'keywords': keywords,
    };
  }

  /// Find the word containing a specific timestamp
  TranscriptWord? findWordAt(int milliseconds) {
    return words.cast<TranscriptWord?>().firstWhere(
          (word) => word!.start <= milliseconds && word.end >= milliseconds,
          orElse: () => null,
        );
  }
}

/// Represents a complete video transcript with metadata
class VideoTranscript {
  final String videoId;
  final List<TranscriptSegment> segments;
  final String language;
  final DateTime lastAccessed;
  final int version;
  final bool isProcessing;
  final String? error;

  const VideoTranscript({
    required this.videoId,
    required this.segments,
    required this.language,
    required this.lastAccessed,
    this.version = 1,
    this.isProcessing = false,
    this.error,
  });

  /// Create a VideoTranscript from Firestore document
  factory VideoTranscript.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoTranscript(
      videoId: doc.id,
      segments: (data['segments'] as List)
          .map((segment) => TranscriptSegment.fromMap(segment))
          .toList(),
      language: data['metadata']['language'] as String,
      lastAccessed: (data['metadata']['lastAccessed'] as Timestamp).toDate(),
      version: data['metadata']['version'] as int? ?? 1,
      isProcessing: data['isProcessing'] as bool? ?? false,
      error: data['error'] as String?,
    );
  }

  /// Convert to a map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'segments': segments.map((segment) => segment.toMap()).toList(),
      'metadata': {
        'language': language,
        'lastAccessed': Timestamp.fromDate(lastAccessed),
        'version': version,
      },
      'isProcessing': isProcessing,
      'error': error,
    };
  }

  /// Create an empty transcript in processing state
  factory VideoTranscript.processing(String videoId) {
    return VideoTranscript(
      videoId: videoId,
      segments: [],
      language: 'en',
      lastAccessed: DateTime.now(),
      isProcessing: true,
    );
  }

  /// Create a transcript with an error
  factory VideoTranscript.error(String videoId, String errorMessage) {
    return VideoTranscript(
      videoId: videoId,
      segments: [],
      language: 'en',
      lastAccessed: DateTime.now(),
      isProcessing: false,
      error: errorMessage,
    );
  }

  /// Find the segment containing a specific timestamp
  TranscriptSegment? findSegmentAt(int milliseconds) {
    return segments.cast<TranscriptSegment?>().firstWhere(
          (segment) => segment!.start <= milliseconds && segment.end >= milliseconds,
          orElse: () => null,
        );
  }

  /// Search for segments containing specific text
  List<TranscriptSegment> searchText(String query) {
    final normalizedQuery = query.toLowerCase();
    return segments.where((segment) {
      return segment.text.toLowerCase().contains(normalizedQuery) ||
          segment.keywords.any((keyword) => 
              keyword.toLowerCase().contains(normalizedQuery));
    }).toList();
  }
} 