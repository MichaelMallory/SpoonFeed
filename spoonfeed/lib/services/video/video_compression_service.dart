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
  
  // Size thresholds
  static const int _compressionThreshold = 40 * 1024 * 1024; // 40MB
  static const int _maxFileSize = 100 * 1024 * 1024; // 100MB

  Future<File?> compressVideo(
    String videoPath, {
    void Function(double)? onProgress,
    bool isWeb = false,
  }) async {
    if (isWeb) {
      print('[VideoCompressionService] Web platform detected, compression not supported');
      return File(videoPath);
    }

    try {
      print('[VideoCompressionService] 🎬 Starting video process...');
      print('  - Input path: $videoPath');

      // Create temp directory for video processing
      final tempDir = await getTemporaryDirectory();
      
      // Try to clean up space first
      try {
        final processingDir = Directory('${tempDir.path}/video_processing');
        await _cleanupProcessingDir(processingDir);
        await VideoCompress.deleteAllCache();
        
        // Also clean temp directory
        final tempContents = await tempDir.list().toList();
        for (var entity in tempContents) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      } catch (e) {
        print('[VideoCompressionService] Error during cleanup: $e');
      }

      final processingDir = Directory('${tempDir.path}/video_processing');
      if (!await processingDir.exists()) {
        await processingDir.create(recursive: true);
      }

      // Clean up any old files in processing directory
      await _cleanupProcessingDir(processingDir);

      // Validate video format
      final extension = path.extension(videoPath).toLowerCase();
      if (!_validFormats.contains(extension)) {
        print('[VideoCompressionService] ❌ Unsupported video format: $extension');
        print('  - Supported formats: ${_validFormats.join(", ")}');
        return null;
      }

      final inputFile = File(videoPath);
      if (!await inputFile.exists()) {
        print('[VideoCompressionService] ❌ Input file does not exist');
        return null;
      }

      final inputSize = await inputFile.length();
      print('  - Input size: ${_formatFileSize(inputSize)}');

      // Check available storage space
      final storageSpace = await _checkAvailableStorage();
      final requiredSpace = inputSize * 3; // We need about 3x the input size for processing
      
      if (storageSpace < requiredSpace) {
        print('[VideoCompressionService] ❌ Insufficient storage space:');
        print('  - Available: ${_formatFileSize(storageSpace)}');
        print('  - Required: ${_formatFileSize(requiredSpace)}');
        return null;
      }

      // Get video info
      final info = await VideoCompress.getMediaInfo(videoPath);
      if (!_validateVideoProperties(info)) {
        return null;
      }

      // Always compress if resolution is high, regardless of file size
      final shouldCompress = inputSize >= _compressionThreshold || 
                           (info.width != null && info.width! > 1080);

      if (!shouldCompress) {
        print('[VideoCompressionService] ℹ️ File is under compression threshold and has acceptable resolution');
        print('  - Threshold: ${_formatFileSize(_compressionThreshold)}');
        print('  - Resolution: ${info.width}x${info.height}');
        return inputFile;
      }

      // Set up progress monitoring
      _setupProgressMonitoring(onProgress);

      print('[VideoCompressionService] 🔄 Compressing video...');
      print('  - Original resolution: ${info.width}x${info.height}');
      
      // Clear cache before compression
      await VideoCompress.deleteAllCache();
      await _cleanupProgress();

      // Set the output path in our processing directory
      final outputPath = '${processingDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}$extension';
      
      // Determine quality based on resolution and file size
      VideoQuality quality;
      if (info.width! > 1920 || inputSize > 50 * 1024 * 1024) {
        quality = VideoQuality.MediumQuality;
      } else if (info.width! > 1080 || inputSize > 20 * 1024 * 1024) {
        quality = VideoQuality.DefaultQuality;
      } else {
        quality = VideoQuality.HighestQuality;
      }
      
      print('[VideoCompressionService] Using quality setting: $quality');
      
      // Try compression with shorter timeout
      final result = await VideoCompress.compressVideo(
        videoPath,
        quality: quality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
      ).timeout(
        const Duration(seconds: 45),  // Much shorter timeout - fail fast if not working
        onTimeout: () {
          print('[VideoCompressionService] ❌ Compression timed out after 45 seconds');
          throw TimeoutException('Video compression timed out - please try again');
        },
      );

      await _cleanupProgress();

      if (result == null || result.file == null) {
        print('[VideoCompressionService] ❌ Compression failed - no output generated');
        print('  - Falling back to original file');
        return inputFile;
      }

      final outputFile = result.file!;
      if (!await outputFile.exists()) {
        print('[VideoCompressionService] ❌ Output file does not exist');
        return inputFile;
      }

      final outputSize = await outputFile.length();
      
      print('[VideoCompressionService] 📊 Compression results:');
      print('  - Original size: ${_formatFileSize(inputSize)}');
      print('  - Compressed size: ${_formatFileSize(outputSize)}');
      print('  - Reduction: ${((1 - outputSize / inputSize) * 100).toStringAsFixed(1)}%');

      // Use original if compression didn't help or output is too small (likely failed)
      if (outputSize >= inputSize || outputSize < 1024) {
        print('[VideoCompressionService] ⚠️ Compression did not reduce file size or output is too small, using original');
        return inputFile;
      }

      print('[VideoCompressionService] ✅ Video compressed successfully');
      return outputFile;
    } catch (e, stackTrace) {
      print('[VideoCompressionService] ❌ Error during compression:');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      
      // Cancel any ongoing compression on error
      try {
        await VideoCompress.cancelCompression();
      } catch (_) {}
      
      return File(videoPath);  // Return original file on error
    } finally {
      // Clean up
      await _cleanupProgress();
      await VideoCompress.deleteAllCache();
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

  Future<void> cancelCompression() async {
    try {
      print('[VideoCompressionService] 🛑 Cancelling compression...');
      await VideoCompress.cancelCompression();
      await _cleanupProgress();
      print('[VideoCompressionService] ✅ Compression cancelled');
    } catch (e) {
      print('[VideoCompressionService] Error cancelling compression: $e');
    }
  }

  void _setupProgressMonitoring(void Function(double)? onProgress) {
    _progressSubscription?.unsubscribe();
    double lastProgress = 0.0;
    var lastProgressUpdate = DateTime.now();
    int stallCount = 0;
    
    _progressSubscription = VideoCompress.compressProgress$.subscribe((progress) {
      final now = DateTime.now();
      
      // Check for stalled progress
      final stallDuration = now.difference(lastProgressUpdate);
      if (stallDuration.inSeconds > 5 && progress < 0.95) {  // Allow longer at the end
        print('[VideoCompressionService] ⚠️ Progress stalled for ${stallDuration.inSeconds} seconds at ${(progress * 100).toStringAsFixed(1)}%');
        stallCount++;
        
        // If progress is stalled for too long, throw error
        if (stallCount >= 3 || (progress < 0.1 && stallDuration.inSeconds > 10)) {
          throw Exception('Compression appears to be stuck - please try again');
        }
      }
      
      // Only report progress if it has increased
      if (progress > lastProgress) {
        lastProgress = progress;
        lastProgressUpdate = now;
        stallCount = 0;  // Reset stall count when we make progress
        final normalizedProgress = progress.clamp(0.0, 1.0);
        print('[VideoCompressionService] Progress: ${(normalizedProgress * 100).toStringAsFixed(1)}%');
        onProgress?.call(normalizedProgress);
      }
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _cleanupProcessingDir(Directory dir) async {
    try {
      if (await dir.exists()) {
        final entities = await dir.list().toList();
        for (var entity in entities) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
    } catch (e) {
      print('[VideoCompressionService] Error cleaning processing directory: $e');
    }
  }

  Future<int> _checkAvailableStorage() async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      if (Platform.isAndroid) {
        // On Android, we need to use df command to get actual free space
        final result = await Process.run('df', [tempDir.path]);
        if (result.exitCode == 0) {
          // Parse df output to get available space
          final lines = result.stdout.toString().split('\n');
          if (lines.length >= 2) {
            final parts = lines[1].split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
            if (parts.length >= 4) {
              // Available space is in 1K blocks, convert to bytes
              final availableKB = int.tryParse(parts[3]) ?? 0;
              return availableKB * 1024;
            }
          }
        }
        
        // Fallback: try to write a test file to check space
        try {
          final testFile = File('${tempDir.path}/space_test');
          await testFile.writeAsBytes(List.filled(1024 * 1024, 0)); // Try to write 1MB
          final freeSpace = await testFile.length() * 100; // Estimate 100x this as free space
          await testFile.delete();
          return freeSpace;
        } catch (e) {
          print('[VideoCompressionService] Error checking space with test file: $e');
        }
      }
      
      // For other platforms or if Android methods fail, assume we have enough space
      // but log a warning
      print('[VideoCompressionService] ⚠️ Could not accurately determine free space, proceeding with compression');
      return 1024 * 1024 * 1024; // Assume 1GB available
    } catch (e) {
      print('[VideoCompressionService] Error checking storage: $e');
      // If we can't check space, assume we have enough but log it
      print('[VideoCompressionService] ⚠️ Proceeding with compression despite space check failure');
      return 1024 * 1024 * 1024; // Assume 1GB available
    }
  }
} 