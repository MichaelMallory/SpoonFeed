/// Represents a parsed voice command with its intent and parameters
class CommandIntent {
  /// The type of command
  final CommandType type;
  
  /// The direction for seek commands (forward/backward)
  final SeekDirection? seekDirection;
  
  /// The duration in seconds for seek commands
  final int? seekSeconds;
  
  /// The content description for content-based navigation
  final String? contentDescription;
  
  /// The confidence score of the intent parsing
  final double confidence;

  const CommandIntent({
    required this.type,
    this.seekDirection,
    this.seekSeconds,
    this.contentDescription,
    this.confidence = 1.0,
  });

  @override
  String toString() => 'CommandIntent(type: $type, seekDirection: $seekDirection, '
      'seekSeconds: $seekSeconds, contentDescription: $contentDescription, '
      'confidence: $confidence)';
}

/// Types of commands that can be executed
enum CommandType {
  play,
  pause,
  seek,
  contentSeek,
  rewind,
  fastForward,
  unknown,
}

/// Direction for seek commands
enum SeekDirection {
  forward,
  backward,
} 