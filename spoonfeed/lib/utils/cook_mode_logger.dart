import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

/// Logger specifically for the Cook Mode feature, providing structured logging
/// with emojis and component-specific formatting.
class CookModeLogger {
  static final _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    filter: DevelopmentFilter(), // Changed to show all logs in development
    output: MultiOutput([ConsoleOutput(), DebugOutput()]), // Added DebugOutput
  );

  // Add log level control
  static bool _verboseLogging = false;
  static set verboseLogging(bool value) {
    _verboseLogging = value;
    debugPrint('CookModeLogger: Verbose logging ${value ? 'enabled' : 'disabled'}');
  }

  /// Logs an event with component-specific formatting and optional data
  static void log(String component, String event, {Map<String, dynamic>? data}) {
    final emoji = _getEmoji(component);
    final timestamp = DateTime.now().toIso8601String();
    final message = '\n[$timestamp] $emoji $component: $event';
    
    if (data != null) {
      _logger.i('$message\n${_formatData(data)}');
    } else {
      _logger.i(message);
    }
  }

  /// Logs an error with component-specific formatting and optional data
  static void error(String component, String error, {Map<String, dynamic>? data, StackTrace? stackTrace}) {
    final emoji = _getEmoji('Error');
    final timestamp = DateTime.now().toIso8601String();
    final message = '\n[$timestamp] $emoji $component Error: $error';
    
    if (data != null) {
      _logger.e('$message\n${_formatData(data)}', error: error, stackTrace: stackTrace);
    } else {
      _logger.e(message, error: error, stackTrace: stackTrace);
    }
  }

  /// Formats data map into a readable string
  static String _formatData(Map<String, dynamic> data) {
    return data.entries
        .map((e) => '  • ${e.key}: ${e.value}')
        .join('\n');
  }

  /// Returns an emoji for the given component
  static String _getEmoji(String component) {
    switch (component.toLowerCase()) {
      case 'cookmode':
        return '👨‍🍳';
      case 'camera':
        return '📸';
      case 'gesture':
        return '👋';
      case 'video':
        return '🎥';
      case 'state':
        return '🔄';
      case 'error':
        return '⚠️';
      case 'performance':
        return '⚡';
      default:
        return '📝';
    }
  }

  // Convenience methods for common logging scenarios
  
  /// Log cook mode state changes
  static void logCookMode(String event, {Map<String, dynamic>? data}) {
    final logData = {
      'event': event,
      'component': 'cook_mode',
      if (data != null) ...data,
    };
    
    _logger.i(logData);
  }

  /// Log camera-related events
  static void logCamera(String event, {Map<String, dynamic>? data}) {
    final logData = {
      'event': event,
      'component': 'camera',
      if (data != null) ...data,
    };
    
    _logger.i(logData);
  }

  /// Logs gesture detection events with detailed metrics
  static void logGesture(String event, {Map<String, dynamic>? data}) {
    // Always print frame processing in debug mode
    debugPrint('🔍 Raw Gesture Event: $event');
    if (data != null) {
      debugPrint('📊 Raw Data: $data');
    }
    
    if (!_verboseLogging && event == 'Processing frame') return;
    
    // Format the log message for better readability
    final message = StringBuffer('\n🔍 Gesture Detection: $event\n');
    if (data != null) {
      // Group related metrics
      if (data.containsKey('activeCells')) {
        message.writeln('Motion Metrics:');
        message.writeln('  • Active Cells: ${data['activeCells']}/${data['requiredCells']}');
        message.writeln('  • Max Luminance Diff: ${data['maxLuminanceDiff']}');
        if (data.containsKey('averageMotionRatio')) {
          message.writeln('  • Motion Ratio: ${(data['averageMotionRatio'] as double).toStringAsFixed(3)}');
        }
      }
      
      if (data.containsKey('processingTime')) {
        message.writeln('Performance:');
        message.writeln('  • Processing Time: ${data['processingTime']}ms');
        if (data.containsKey('timeSinceLastFrame')) {
          message.writeln('  • Frame Interval: ${data['timeSinceLastFrame']}ms');
        }
      }
      
      if (data.containsKey('totalFrames')) {
        message.writeln('Session Stats:');
        message.writeln('  • Total Frames: ${data['totalFrames']}');
        if (data.containsKey('frameRate')) {
          message.writeln('  • Frame Rate: ${(data['frameRate'] as double).toStringAsFixed(1)} fps');
        }
      }
    }
    
    debugPrint(message.toString());  // Direct debug print
    _logger.i(message.toString());   // Logger output
  }

  /// Log video player events
  static void logVideo(String event, {Map<String, dynamic>? data}) {
    final logData = {
      'event': event,
      'component': 'video',
      if (data != null) ...data,
    };
    
    _logger.i(logData);
  }

  /// Log performance metrics
  static void logPerformance(String event, {Map<String, dynamic>? data}) {
    log('Performance', event, data: data);
  }
}

/// Custom debug output that ensures logs appear in debug console
class DebugOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    event.lines.forEach(debugPrint);
  }
} 