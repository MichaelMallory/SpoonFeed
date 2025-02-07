import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class VideoThumbnailService {
  // Singleton instance
  static final VideoThumbnailService _instance = VideoThumbnailService._internal();
  factory VideoThumbnailService() => _instance;
  VideoThumbnailService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Default thumbnail settings
  static const int defaultMaxWidth = 512;
  static const int defaultQuality = 75;
  static const int maxRetries = 3;
  static const int maxThumbnailSize = 2 * 1024 * 1024; // 2MB limit

  Future<String?> generateAndUploadThumbnail(
    String videoPath, {
    bool isWeb = false,
    int maxWidth = defaultMaxWidth,
    int quality = defaultQuality,
    ImageFormat format = ImageFormat.JPEG,
    int timeMs = 0,
  }) async {
    try {
      if (isWeb) {
        print('[VideoThumbnailService] Web platform detected, using default thumbnail');
        return '';
      }

      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return null;
      }

      print('[VideoThumbnailService] 🖼️ Generating thumbnail...');
      print('  - Video path: $videoPath');
      print('  - Video file exists: ${await File(videoPath).exists()}');
      print('  - User ID: ${user!.uid}');
      print('  - Settings:');
      print('    • Max width: $maxWidth');
      print('    • Quality: $quality');
      print('    • Format: $format');
      print('    • Time position: ${timeMs}ms');

      // Validate video file
      if (!await _validateVideoFile(videoPath)) {
        return null;
      }

      int retryCount = 0;
      Uint8List? thumbnailBytes;
      Exception? lastError;

      while (retryCount < maxRetries && thumbnailBytes == null) {
        try {
          if (retryCount > 0) {
            print('\n[VideoThumbnailService] 🔄 Retry attempt ${retryCount + 1}/$maxRetries');
            await Future.delayed(Duration(seconds: retryCount));
          }

          thumbnailBytes = await _generateThumbnail(
            videoPath,
            maxWidth: maxWidth,
            quality: quality,
            format: format,
            timeMs: timeMs,
          );
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          print('[VideoThumbnailService] Error generating thumbnail: $e');
          retryCount++;

          if (retryCount >= maxRetries) {
            print('[VideoThumbnailService] ❌ Max retries reached');
            print('  - Last error: $lastError');
          }
        }
      }

      if (thumbnailBytes == null) {
        return null;
      }

      // Validate thumbnail size
      if (!_validateThumbnailSize(thumbnailBytes)) {
        return null;
      }

      // Generate unique filename with timestamp and format extension
      final fileName = await _generateThumbnailFileName(format);
      print('  - Target filename: $fileName');
      
      return await _uploadThumbnail(thumbnailBytes, fileName, user.uid);
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return null;
    }
  }

  Future<bool> _validateVideoFile(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      print('[VideoThumbnailService] ❌ Video file does not exist');
      return false;
    }

    final size = await file.length();
    if (size <= 0) {
      print('[VideoThumbnailService] ❌ Video file is empty');
      return false;
    }

    final extension = path.extension(videoPath).toLowerCase();
    if (!['.mp4', '.mov', '.avi', '.mkv', '.wmv'].contains(extension)) {
      print('[VideoThumbnailService] ❌ Unsupported video format: $extension');
      return false;
    }

    return true;
  }

  bool _validateThumbnailSize(Uint8List thumbnailBytes) {
    final size = thumbnailBytes.length;
    if (size > maxThumbnailSize) {
      print('[VideoThumbnailService] ❌ Thumbnail too large: ${size / 1024}KB');
      print('  - Maximum allowed: ${maxThumbnailSize / 1024}KB');
      return false;
    }
    return true;
  }

  Future<String> _generateThumbnailFileName(ImageFormat format) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = format == ImageFormat.JPEG ? '.jpg' : '.png';
    return '${timestamp}_thumb$extension';
  }

  bool _validateUser(User? user) {
    print('[VideoThumbnailService] 🔑 Checking authentication:');
    print('  - User authenticated: ${user != null}');
    print('  - User ID: ${user?.uid}');
    print('  - Email verified: ${user?.emailVerified}');
    print('  - Provider ID: ${user?.providerData.map((e) => e.providerId).join(", ")}');
    
    if (user == null) {
      print('[VideoThumbnailService] ❌ User must be logged in to generate thumbnails');
      return false;
    }
    return true;
  }

  Future<Uint8List?> _generateThumbnail(
    String videoPath, {
    required int maxWidth,
    required int quality,
    required ImageFormat format,
    required int timeMs,
  }) async {
    final thumbnailBytes = await VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: format,
      maxWidth: maxWidth,
      quality: quality,
      timeMs: timeMs,
    );
    
    if (thumbnailBytes == null) {
      print('[VideoThumbnailService] ❌ Failed to generate thumbnail data');
      return null;
    }
    
    print('[VideoThumbnailService] ✅ Thumbnail generated successfully');
    print('  - Size: ${thumbnailBytes.length / 1024}KB');
    print('  - Format: $format');
    return thumbnailBytes;
  }

  Future<String?> _uploadThumbnail(Uint8List thumbnailBytes, String fileName, String userId) async {
    try {
      final storageRef = _storage.ref()
          .child('videos')
          .child(userId)
          .child('thumbnails')
          .child(fileName);
      
      print('[VideoThumbnailService] 📤 Uploading thumbnail...');
      print('  - Storage path: ${storageRef.fullPath}');
      print('  - Storage bucket: ${_storage.bucket}');
      
      final metadata = SettableMetadata(
        contentType: fileName.endsWith('.png') ? 'image/png' : 'image/jpeg',
        customMetadata: {
          'userId': userId,
          'timestamp': DateTime.now().toIso8601String(),
          'size': '${thumbnailBytes.length}',
        },
      );
      
      final uploadTask = storageRef.putData(thumbnailBytes, metadata);
      
      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print('[VideoThumbnailService] Thumbnail upload progress: ${(progress * 100).toStringAsFixed(1)}%');
          print('  - State: ${snapshot.state}');
          print('  - Bytes transferred: ${snapshot.bytesTransferred}');
          print('  - Total bytes: ${snapshot.totalBytes}');
        },
        onError: (error) {
          print('[VideoThumbnailService] ❌ Thumbnail upload error: $error');
          if (error is FirebaseException) {
            print('  - Error code: ${error.code}');
            print('  - Error message: ${error.message}');
            print('  - Error details: ${error.stackTrace}');
          }
        },
      );

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('[VideoThumbnailService] ✅ Thumbnail uploaded successfully');
      print('  - Download URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('[VideoThumbnailService] Error uploading thumbnail: $e');
      return null;
    }
  }

  void _logError(dynamic error, StackTrace stackTrace) {
    print('[VideoThumbnailService] ❌ Error generating thumbnail:');
    print('  - Error: $error');
    print('  - Stack trace: $stackTrace');
  }
} 