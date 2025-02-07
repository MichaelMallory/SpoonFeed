import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

class VideoStorageService {
  // Singleton instance
  static final VideoStorageService _instance = VideoStorageService._internal();
  factory VideoStorageService() => _instance;
  VideoStorageService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constants for upload configuration
  static const int maxRetries = 3;
  static const int chunkSize = 1024 * 1024; // 1MB chunks
  static const Duration retryDelay = Duration(seconds: 3);

  Reference ref() => _storage.ref();

  Future<String?> uploadVideo(
    String videoPath, {
    void Function(double)? onProgress,
    bool isWeb = false,
    bool enableResume = true,
  }) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        print('[VideoStorageService] ❌ User validation failed');
        return null;
      }

      print('[VideoStorageService] 📤 Starting video upload...');
      print('  - Video path: $videoPath');
      print('  - Video file exists: ${await File(videoPath).exists()}');
      print('  - User ID: ${user!.uid}');

      // Validate video file
      if (!await _validateVideoFile(videoPath)) {
        print('[VideoStorageService] ❌ Video file validation failed');
        return null;
      }

      final fileName = await _generateUniqueFileName(videoPath);
      print('  - Target filename: $fileName');

      final storageRef = _storage.ref()
          .child('videos')
          .child(user.uid)
          .child('uploads')
          .child(fileName);

      print('  - Storage path: ${storageRef.fullPath}');
      print('  - Storage bucket: ${_storage.bucket}');

      final metadata = await _generateMetadata(videoPath, user.uid);
      
      int retryCount = 0;
      UploadTask? uploadTask;
      String? downloadUrl;

      while (retryCount < maxRetries && downloadUrl == null) {
        try {
          if (retryCount > 0) {
            print('\n[VideoStorageService] 🔄 Retry attempt ${retryCount + 1}/$maxRetries');
            await Future.delayed(retryDelay * retryCount);
          }

          uploadTask = await _createUploadTask(
            videoPath,
            storageRef,
            metadata,
            isWeb: isWeb,
          );

          // Monitor upload progress
          final completer = Completer<String?>();
          
          uploadTask.snapshotEvents.listen(
            (TaskSnapshot snapshot) {
              final progress = snapshot.bytesTransferred / snapshot.totalBytes;
              _logUploadProgress(snapshot);
              onProgress?.call(progress);
            },
            onError: (error) {
              _logUploadError(error);
              if (!completer.isCompleted) {
                completer.completeError(error);
              }
            },
            onDone: () async {
              if (!completer.isCompleted) {
                try {
                  // Get the download URL immediately after upload
                  downloadUrl = await uploadTask!.snapshot.ref.getDownloadURL();
                  print('[VideoStorageService] ✅ Got download URL: $downloadUrl');
                  completer.complete(downloadUrl);
                } catch (e) {
                  print('[VideoStorageService] ❌ Error getting download URL: $e');
                  completer.completeError(e);
                }
              }
            },
            cancelOnError: true,
          );

          // Wait for upload completion or error
          downloadUrl = await completer.future;
        } catch (e) {
          _logUploadError(e);
          retryCount++;
          
          if (retryCount >= maxRetries) {
            print('[VideoStorageService] ❌ Max retries reached');
            rethrow;
          }
          
          // Cancel current upload task before retrying
          await uploadTask?.cancel();
        }
      }

      if (downloadUrl != null) {
        print('[VideoStorageService] ✅ Video uploaded successfully');
        print('  - Download URL: $downloadUrl');
        return downloadUrl;
      }

      print('[VideoStorageService] ❌ Upload failed to produce download URL');
      return null;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return null;
    }
  }

  Future<bool> _validateVideoFile(String videoPath) async {
    final file = File(videoPath);
    if (!await file.exists()) {
      print('[VideoStorageService] ❌ Video file does not exist');
      return false;
    }

    final size = await file.length();
    if (size <= 0) {
      print('[VideoStorageService] ❌ Video file is empty');
      return false;
    }

    // Check file extension
    final extension = path.extension(videoPath).toLowerCase();
    if (!['.mp4', '.mov', '.avi', '.mkv', '.wmv'].contains(extension)) {
      print('[VideoStorageService] ❌ Unsupported video format: $extension');
      return false;
    }

    return true;
  }

  Future<String> _generateUniqueFileName(String videoPath) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final originalName = path.basenameWithoutExtension(videoPath);
    final extension = path.extension(videoPath);
    final hash = await _computeFileHash(videoPath);
    return '${timestamp}_${originalName}_${hash.substring(0, 8)}$extension';
  }

  Future<String> _computeFileHash(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return bytes.fold<int>(0, (prev, byte) => prev + byte).toRadixString(16);
    } catch (e) {
      print('[VideoStorageService] Error computing file hash: $e');
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  Future<SettableMetadata> _generateMetadata(String videoPath, String userId) async {
    final file = File(videoPath);
    final fileStats = await file.stat();
    
    return SettableMetadata(
      contentType: 'video/mp4',
      customMetadata: {
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'originalFileName': path.basename(videoPath),
        'fileSize': '${await file.length()}',
        'lastModified': fileStats.modified.toIso8601String(),
        'uploadTime': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<UploadTask> _createUploadTask(
    String videoPath,
    Reference storageRef,
    SettableMetadata metadata, {
    bool isWeb = false,
  }) async {
    if (isWeb) {
      final videoFile = File(videoPath);
      final bytes = await videoFile.readAsBytes();
      return storageRef.putData(bytes, metadata);
    } else {
      return storageRef.putFile(File(videoPath), metadata);
    }
  }

  void _logUploadProgress(TaskSnapshot snapshot) {
    final progress = snapshot.bytesTransferred / snapshot.totalBytes;
    print('[VideoStorageService] Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
    print('  - State: ${snapshot.state}');
    print('  - Bytes transferred: ${_formatBytes(snapshot.bytesTransferred)}');
    print('  - Total bytes: ${_formatBytes(snapshot.totalBytes)}');
    print('  - Transfer rate: ${_calculateTransferRate(snapshot)}');
  }

  String _calculateTransferRate(TaskSnapshot snapshot) {
    if (snapshot.bytesTransferred == 0) return '0 B/s';
    final bytes = snapshot.bytesTransferred;
    final timeDiff = DateTime.now().difference(snapshot.metadata?.timeCreated ?? DateTime.now());
    final seconds = timeDiff.inSeconds;
    if (seconds == 0) return 'Calculating...';
    final bytesPerSecond = bytes / seconds;
    return '${_formatBytes(bytesPerSecond.round())}/s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _logUploadError(dynamic error) {
    print('[VideoStorageService] ❌ Upload error: $error');
    if (error is FirebaseException) {
      print('  - Error code: ${error.code}');
      print('  - Error message: ${error.message}');
      print('  - Error details: ${error.stackTrace}');
    }
  }

  Future<bool> deleteVideo(String videoUrl) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return false;
      }

      print('[VideoStorageService] 🗑️ Deleting video...');
      print('  - Video URL: $videoUrl');

      final ref = _storage.refFromURL(videoUrl);
      await ref.delete();

      print('[VideoStorageService] ✅ Video deleted successfully');
      return true;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return false;
    }
  }

  bool _validateUser(User? user) {
    print('[VideoStorageService] 🔑 Checking authentication:');
    print('  - User authenticated: ${user != null}');
    if (user == null) {
      print('  - Error: User is not logged in');
      return false;
    }

    print('  - User ID: ${user.uid}');
    return true;
  }

  void _logError(dynamic error, StackTrace stackTrace) {
    print('[VideoStorageService] ❌ Error in storage operation:');
    print('  - Error: $error');
    print('  - Stack trace: $stackTrace');
  }
} 