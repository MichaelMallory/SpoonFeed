import '../models/command_intent.dart';
import 'package:logger/logger.dart';

/// Service for parsing voice commands into structured intents
class CommandParserService {
  final _logger = Logger();

  /// Parse a voice command text into a CommandIntent
  CommandIntent parseCommand(String text) {
    final normalizedText = text.toLowerCase().trim();
    _logger.i('🎯 Parsing command: "$normalizedText"');

    // Check for basic playback controls
    if (_containsAny(normalizedText, ['play', 'start', 'continue', 'resume'])) {
      return CommandIntent(type: CommandType.play);
    }
    
    if (_containsAny(normalizedText, ['pause', 'stop', 'wait'])) {
      return CommandIntent(type: CommandType.pause);
    }

    // Check for seek commands with relative time
    if (_containsAny(normalizedText, ['back', 'rewind', 'previous'])) {
      final seconds = _extractSeconds(normalizedText);
      return CommandIntent(
        type: CommandType.seek,
        seekDirection: SeekDirection.backward,
        seekSeconds: seconds,
      );
    }
    
    if (_containsAny(normalizedText, ['forward', 'skip', 'next', 'ahead'])) {
      final seconds = _extractSeconds(normalizedText);
      return CommandIntent(
        type: CommandType.seek,
        seekDirection: SeekDirection.forward,
        seekSeconds: seconds,
      );
    }

    // Check for content-based navigation
    if (_containsAny(normalizedText, ['show', 'find', 'go to', 'jump to'])) {
      final content = _extractContentDescription(normalizedText);
      if (content != null) {
        return CommandIntent(
          type: CommandType.contentSeek,
          contentDescription: content,
        );
      }
    }

    _logger.w('⚠️ Unknown command type: "$normalizedText"');
    return CommandIntent(type: CommandType.unknown, confidence: 0.0);
  }

  /// Extract the number of seconds from the command text
  int _extractSeconds(String text) {
    // Default to 10 seconds if no number specified
    int seconds = 10;
    
    // Try to find a number followed by "seconds" or "s"
    final timePattern = RegExp(r'(\d+)\s*(seconds?|s|secs?)');
    final match = timePattern.firstMatch(text);
    
    if (match != null) {
      seconds = int.parse(match.group(1)!);
    } else {
      // Try to find any number
      final numbers = RegExp(r'\d+').allMatches(text);
      if (numbers.isNotEmpty) {
        seconds = int.parse(numbers.first.group(0)!);
      }
    }
    
    _logger.d('⏱️ Extracted $seconds seconds from command');
    return seconds;
  }

  /// Extract content description from the command text
  String? _extractContentDescription(String text) {
    // Common patterns for content references
    final patterns = [
      RegExp(r'(?:show|find|go to|jump to)\s+(?:the\s+)?(?:part\s+)?(?:with|where)\s+(.+)'),
      RegExp(r'(?:show|find|go to|jump to)\s+(?:the\s+)?(.+?)\s+(?:part|section|step)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final content = match.group(1)!.trim();
        _logger.d('📝 Extracted content description: "$content"');
        return content;
      }
    }

    // If no pattern matches but we have keywords, take everything after them
    final keywords = ['show', 'find', 'go to', 'jump to'];
    for (final keyword in keywords) {
      if (text.contains(keyword)) {
        final parts = text.split(keyword);
        if (parts.length > 1) {
          final content = parts[1].trim()
              .replaceAll(RegExp(r'^(?:the|to)\s+'), '')
              .replaceAll(RegExp(r'\s+(?:part|section|step)$'), '')
              .trim();
          _logger.d('📝 Extracted content description (fallback): "$content"');
          return content;
        }
      }
    }

    return null;
  }

  /// Check if text contains any of the given phrases
  bool _containsAny(String text, List<String> phrases) {
    return phrases.any((phrase) => text.contains(phrase));
  }
} 