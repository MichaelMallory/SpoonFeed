import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path/path.dart' as path;

class VideoCompressionService {
  // Singleton instance
  static final VideoCompressionService _instance = VideoCompressionService._internal();
  factory VideoCompressionService() => _instance;
  VideoCompressionService._internal();

  // Subscription for compression progress
  Subscription? _progressSubscription;

  // Valid video formats
  static const List<String> _validFormats = ['.mp4', '.mov', '.avi', '.mkv', '.wmv'];
  static const int maxRetries = 3;

  Future<File?> compressVideo(
    String videoPath, {
    void Function(double)? onProgress,
    bool isWeb = false,
    VideoQuality? forcedQuality,
  }) async {
    if (isWeb) {
      print('[VideoCompressionService] Web platform detected, compression not supported');
      return File(videoPath);
    }

    // Validate video format
    final extension = path.extension(videoPath).toLowerCase();
    if (!_validFormats.contains(extension)) {
      print('[VideoCompressionService] ❌ Unsupported video format: $extension');
      print('  - Supported formats: ${_validFormats.join(", ")}');
      return null;
    }

    int retryCount = 0;
    File? result;
    Exception? lastError;

    while (retryCount < maxRetries && result == null) {
      try {
        if (retryCount > 0) {
          print('\n[VideoCompressionService] 🔄 Retry attempt ${retryCount + 1}/$maxRetries');
          // Add exponential backoff
          await Future.delayed(Duration(seconds: retryCount * 2));
        }

        result = await _attemptCompression(
          videoPath,
          onProgress: onProgress,
          forcedQuality: forcedQuality,
          retryCount: retryCount,
        );
      } catch (e, stackTrace) {
        lastError = e is Exception ? e : Exception(e.toString());
        _logError(e, stackTrace);
        retryCount++;
        
        if (retryCount >= maxRetries) {
          print('[VideoCompressionService] ❌ Max retries reached');
          print('  - Last error: $lastError');
        }
      }
    }

    return result;
  }

  Future<File?> _attemptCompression(
    String videoPath, {
    void Function(double)? onProgress,
    VideoQuality? forcedQuality,
    required int retryCount,
  }) async {
    try {
      print('[VideoCompressionService] 🎬 Starting video compression...');
      print('  - Input path: $videoPath');
      print('  - Retry count: $retryCount');
      
      final inputFile = File(videoPath);
      if (!await inputFile.exists()) {
        print('[VideoCompressionService] ❌ Input file does not exist');
        return null;
      }

      final inputSize = await inputFile.length();
      print('  - Input size: ${_formatFileSize(inputSize)}');

      // Set up progress monitoring
      _setupProgressMonitoring(onProgress);

      // Generate output path
      final outputPath = await _generateOutputPath(videoPath);
      print('  - Output path: $outputPath');

      // Get video info before compression
      final info = await VideoCompress.getMediaInfo(videoPath);
      _logVideoInfo('Before compression', info);

      // Validate video duration and dimensions
      if (!_validateVideoProperties(info)) {
        return null;
      }

      print('[VideoCompressionService] 🔄 Compressing video...');
      
      final result = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.MediumQuality, // Force medium quality for better compatibility
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      );

      if (result == null || result.file == null) {
        print('[VideoCompressionService] ❌ Compression failed - no output generated');
        return null;
      }

      final outputFile = result.file!;
      final outputSize = await outputFile.length();
      
      // Get video info after compression
      final compressedInfo = await VideoCompress.getMediaInfo(outputFile.path);
      _logVideoInfo('After compression', compressedInfo);

      // Validate compressed video
      if (!_validateCompressedVideo(compressedInfo)) {
        return inputFile;
      }

      print('[VideoCompressionService] 📊 Compression results:');
      print('  - Original size: ${_formatFileSize(inputSize)}');
      print('  - Compressed size: ${_formatFileSize(outputSize)}');
      print('  - Reduction: ${((1 - outputSize / inputSize) * 100).toStringAsFixed(1)}%');

      // Check if compression actually reduced file size
      if (outputSize >= inputSize) {
        print('[VideoCompressionService] ⚠️ Compression did not reduce file size');
        return inputFile;
      }

      print('[VideoCompressionService] ✅ Video compressed successfully');
      return outputFile;
    } catch (e, stackTrace) {
      print('[VideoCompressionService] ❌ Error during compression attempt $retryCount:');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      
      if (retryCount < maxRetries - 1) {
        print('[VideoCompressionService] 🔄 Will retry with different settings...');
        return null;
      } else {
        print('[VideoCompressionService] ❌ Max retries reached, using original file');
        return File(videoPath);
      }
    } finally {
      await _cleanupProgress();
    }
  }

  bool _validateVideoProperties(MediaInfo info) {
    // Convert duration to seconds for better logging
    final durationInSeconds = (info.duration ?? 0) / 1000.0;
    
    if (info.duration == null || info.duration! <= 0) {
      print('[VideoCompressionService] ❌ Invalid video duration: ${durationInSeconds.toStringAsFixed(1)} seconds');
      return false;
    }

    // Check maximum duration (10 minutes = 600 seconds)
    if (durationInSeconds > 600) {
      print('[VideoCompressionService] ❌ Video too long: ${durationInSeconds.toStringAsFixed(1)} seconds (max: 600 seconds)');
      return false;
    }

    if (info.width == null || info.height == null || info.width! <= 0 || info.height! <= 0) {
      print('[VideoCompressionService] ❌ Invalid video dimensions: ${info.width}x${info.height}');
      return false;
    }

    print('[VideoCompressionService] ✓ Video properties valid:');
    print('  - Duration: ${durationInSeconds.toStringAsFixed(1)} seconds');
    print('  - Dimensions: ${info.width}x${info.height}');
    return true;
  }

  bool _validateCompressedVideo(MediaInfo info) {
    if (info.filesize == null || info.filesize! <= 0) {
      print('[VideoCompressionService] ❌ Invalid compressed file size');
      return false;
    }

    if (info.path == null || !File(info.path!).existsSync()) {
      print('[VideoCompressionService] ❌ Compressed file does not exist');
      return false;
    }

    return true;
  }

  Future<void> cancelCompression() async {
    try {
      print('[VideoCompressionService] 🛑 Cancelling compression...');
      await VideoCompress.cancelCompression();
      await _cleanupProgress();
      print('[VideoCompressionService] ✅ Compression cancelled');
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
    }
  }

  void _setupProgressMonitoring(void Function(double)? onProgress) {
    _progressSubscription?.unsubscribe();
    _progressSubscription = VideoCompress.compressProgress$.subscribe((progress) {
      // Ensure progress is between 0 and 100
      final normalizedProgress = progress.clamp(0.0, 1.0);
      print('[VideoCompressionService] Progress: ${(normalizedProgress * 100).toStringAsFixed(1)}%');
      onProgress?.call(normalizedProgress);
    });
  }

  Future<void> _cleanupProgress() async {
    try {
      _progressSubscription?.unsubscribe();
      _progressSubscription = null;
    } catch (e) {
      print('[VideoCompressionService] Error cleaning up progress subscription: $e');
    }
  }

  VideoQuality _determineCompressionQuality(int fileSize) {
    // Size thresholds in bytes
    const int highQualityThreshold = 50 * 1024 * 1024; // 50MB
    const int mediumQualityThreshold = 100 * 1024 * 1024; // 100MB

    if (fileSize < highQualityThreshold) {
      return VideoQuality.MediumQuality;
    } else if (fileSize < mediumQualityThreshold) {
      return VideoQuality.LowQuality;
    } else {
      // Always use medium quality for better compatibility
      return VideoQuality.MediumQuality;
    }
  }

  Future<String> _generateOutputPath(String inputPath) async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final originalFileName = path.basename(inputPath);
    final extension = path.extension(originalFileName);
    return path.join(dir.path, 'compressed_${timestamp}$extension');
  }

  void _logVideoInfo(String stage, MediaInfo info) {
    print('[$stage]');
    print('  - Path: ${info.path}');
    print('  - File size: ${_formatFileSize(info.filesize ?? 0)}');
    print('  - Duration: ${(info.duration ?? 0) / 1000.0} seconds');
    print('  - Width: ${info.width}');
    print('  - Height: ${info.height}');
    if (info.author != null) print('  - Author: ${info.author}');
    if (info.title != null) print('  - Title: ${info.title}');
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _logError(dynamic error, StackTrace stackTrace) {
    print('[VideoCompressionService] ❌ Error during compression:');
    print('  - Error: $error');
    print('  - Stack trace: $stackTrace');
  }
} 