import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';

import 'video_compression_service.dart';
import 'video_thumbnail_service.dart';
import 'video_storage_service.dart';
import 'video_cache_service.dart';
import 'video_metadata_service.dart';

class VideoService {
  // Singleton instance
  static final VideoService _instance = VideoService._internal();
  factory VideoService() => _instance;
  VideoService._internal();

  // Service instances
  final _compressionService = VideoCompressionService();
  final _thumbnailService = VideoThumbnailService();
  final _storageService = VideoStorageService();
  final _cacheService = VideoCacheService();
  final _metadataService = VideoMetadataService();

  // Firebase instances
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<String?> uploadVideo(
    String videoPath,
    String title,
    String description, {
    void Function(double)? onProgress,
    bool isWeb = false,
  }) async {
    try {
      print('[VideoService] 🎬 Starting video upload process...');
      print('  - Video path: $videoPath');
      print('  - Title: $title');

      // Step 1: Compress video
      print('\n[VideoService] Step 1: Compressing video...');
      final compressedVideo = await _compressionService.compressVideo(
        videoPath,
        onProgress: onProgress,
        isWeb: isWeb,
      );

      if (compressedVideo == null) {
        print('[VideoService] ❌ Video compression failed');
        return null;
      }

      // Step 2: Generate thumbnail
      print('\n[VideoService] Step 2: Generating thumbnail...');
      final thumbnailUrl = await _thumbnailService.generateAndUploadThumbnail(
        compressedVideo.path,
        isWeb: isWeb,
      );

      if (thumbnailUrl == null) {
        print('[VideoService] ❌ Thumbnail generation failed');
        return null;
      }

      // Step 3: Upload video
      print('\n[VideoService] Step 3: Uploading video...');
      final videoUrl = await _storageService.uploadVideo(
        compressedVideo.path,
        onProgress: onProgress,
        isWeb: isWeb,
      );

      if (videoUrl == null) {
        print('[VideoService] ❌ Video upload failed');
        return null;
      }

      print('[VideoService] Video URL after upload: $videoUrl');

      // Step 4: Save metadata
      print('\n[VideoService] Step 4: Saving metadata...');
      final videoId = await _metadataService.saveVideoMetadata(
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        title: title,
        description: description,
        duration: 0, // Will be updated after processing
        fileSize: await compressedVideo.length(),
      );

      if (videoId == null) {
        print('[VideoService] ❌ Metadata save failed');
        return null;
      }

      // Step 5: Cache video locally
      print('\n[VideoService] Step 5: Caching video...');
      await _cacheService.cacheVideo(videoUrl, compressedVideo);

      print('[VideoService] ✅ Video upload process completed successfully');
      print('  - Video ID: $videoId');
      print('  - Video URL: $videoUrl');
      return videoId;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return null;
    }
  }

  Future<String?> uploadVideoWeb(File videoFile, String title, String description) async {
    return uploadVideo(
      videoFile.path,
      title,
      description,
      isWeb: true,
    );
  }

  Future<bool> deleteVideo(String videoId) async {
    try {
      print('[VideoService] 🗑️ Starting video deletion process...');
      print('  - Video ID: $videoId');

      // Step 1: Get video metadata
      final metadata = await _metadataService.getVideoMetadata(videoId);
      if (metadata == null) {
        print('[VideoService] ❌ Video metadata not found');
        return false;
      }

      // Step 2: Delete from storage
      final videoDeleted = await _storageService.deleteVideo(metadata['videoUrl']);
      if (!videoDeleted) {
        print('[VideoService] ❌ Failed to delete video from storage');
        return false;
      }

      // Step 3: Delete metadata
      final metadataDeleted = await _metadataService.deleteVideoMetadata(videoId);
      if (!metadataDeleted) {
        print('[VideoService] ❌ Failed to delete video metadata');
        return false;
      }

      // Step 4: Clear from cache
      await _cacheService.clearCache();

      print('[VideoService] ✅ Video deletion completed successfully');
      return true;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return false;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getUserVideos(String userId) async {
    return _firestore
        .collection('videos')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getVideoStream({
    int limit = 10,
    DocumentSnapshot? startAfter,
    String? status,
  }) {
    var query = _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    if (status != null) {
      query = query.where('status', isEqualTo: status);
    }

    return query.snapshots();
  }

  Future<String?> getCachedVideoPath(String videoUrl) async {
    return _cacheService.getCachedVideoPath(videoUrl);
  }

  Future<String?> getVideoUrl(String videoUrl) async {
    try {
      if (videoUrl.isEmpty) {
        print('[VideoService] ❌ Empty video URL provided');
        return null;
      }

      // If it's already a full URL, validate and return it
      if (videoUrl.startsWith('http')) {
        try {
          final uri = Uri.parse(videoUrl);
          if (uri.host.contains('firebasestorage.googleapis.com')) {
            print('[VideoService] ✅ Valid Firebase Storage URL: $videoUrl');
            return videoUrl;
          }
        } catch (e) {
          print('[VideoService] ❌ Invalid URL format: $e');
          return null;
        }
      }

      // Get the download URL from Firebase Storage
      try {
        final ref = FirebaseStorage.instance.ref().child(videoUrl);
        final url = await ref.getDownloadURL();
        print('[VideoService] ✅ Retrieved download URL: $url');
        return url;
      } catch (e) {
        print('[VideoService] ❌ Error getting download URL: $e');
        return null;
      }
    } catch (e) {
      print('[VideoService] ❌ Error in getVideoUrl: $e');
      return null;
    }
  }

  Future<bool> isVideoLikedByUser(String videoId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('likes')
          .doc(user.uid)
          .get();

      return doc.exists;
    } catch (e) {
      print('[VideoService] Error checking video like status: $e');
      return false;
    }
  }

  Future<void> likeVideo(String videoId, bool liked) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final videoRef = _firestore.collection('videos').doc(videoId);
      final likeRef = videoRef.collection('likes').doc(user.uid);

      await _firestore.runTransaction((transaction) async {
        final videoDoc = await transaction.get(videoRef);
        
        if (!videoDoc.exists) {
          throw Exception('Video not found');
        }

        final currentLikes = videoDoc.data()?['likes'] ?? 0;

        if (liked) {
          transaction.set(likeRef, {
            'userId': user.uid,
            'timestamp': FieldValue.serverTimestamp(),
          });
          transaction.update(videoRef, {'likes': currentLikes + 1});
        } else {
          transaction.delete(likeRef);
          transaction.update(videoRef, {'likes': currentLikes - 1});
        }
      });
    } catch (e) {
      print('[VideoService] Error updating video like: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getVideoComments(String videoId) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('[VideoService] Error getting video comments: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> addComment(
    String videoId,
    String text,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final commentRef = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final comment = await commentRef.get();
      return {
        'id': comment.id,
        ...comment.data()!,
      };
    } catch (e) {
      print('[VideoService] Error adding comment: $e');
      return null;
    }
  }

  Future<bool> deleteComment(
    String videoId,
    String commentId,
  ) async {
    try {
      await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId)
          .delete();
      return true;
    } catch (e) {
      print('[VideoService] Error deleting comment: $e');
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> loadMoreVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('[VideoService] Error loading more videos: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDiscoverFeedVideos() async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'active')
          .orderBy('views', descending: true)
          .limit(20)
          .get();

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('[VideoService] Error getting discover feed videos: $e');
      return [];
    }
  }

  Future<void> updateUserVideoCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .count()
          .get();

      await _firestore
          .collection('users')
          .doc(userId)
          .update({'videoCount': snapshot.count});
    } catch (e) {
      print('[VideoService] Error updating user video count: $e');
    }
  }

  void _logError(dynamic error, StackTrace stackTrace) {
    print('[VideoService] ❌ Error in video operation:');
    print('  - Error: $error');
    print('  - Stack trace: $stackTrace');
  }
} 