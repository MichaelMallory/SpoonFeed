import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a voice command and its processed result
class VoiceCommand {
  final String text;
  final double confidence;
  final DateTime timestamp;
  final bool isProcessed;
  final String? error;
  final String? command;

  VoiceCommand({
    required this.text,
    this.confidence = 0.0,
    DateTime? timestamp,
    this.isProcessed = false,
    this.error,
    this.command,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create a VoiceCommand from JSON data
  factory VoiceCommand.fromJson(Map<String, dynamic> json) {
    return VoiceCommand(
      text: json['text'] ?? '',
      confidence: json['confidence']?.toDouble() ?? 0.0,
      isProcessed: json['isProcessed'] ?? false,
      error: json['error'],
      command: json['command'],
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'confidence': confidence,
      'timestamp': timestamp.toIso8601String(),
      'isProcessed': isProcessed,
      'error': error,
      'command': command,
    };
  }

  @override
  String toString() => 'VoiceCommand(text: $text, confidence: $confidence)';
} 