import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_compress/video_compress.dart';

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
      String? thumbnailUrl;
      try {
        thumbnailUrl = await _thumbnailService.generateAndUploadThumbnail(
          compressedVideo.path,
          isWeb: isWeb,
        );
      } catch (e) {
        print('[VideoService] ⚠️ Thumbnail generation failed: $e');
        // Continue without thumbnail
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

      // Get video duration and metadata
      final videoInfo = await VideoCompress.getMediaInfo(compressedVideo.path);
      var duration = (videoInfo.duration ?? 0).toInt();
      
      if (duration <= 0) {
        print('[VideoService] ⚠️ Invalid duration, attempting to get from original file');
        final originalInfo = await VideoCompress.getMediaInfo(videoPath);
        duration = (originalInfo.duration ?? 0).toInt();
      }

      // Ensure we have a valid duration
      if (duration <= 0) {
        print('[VideoService] ❌ Could not determine video duration');
        return null;
      }

      // Step 4: Save metadata
      print('\n[VideoService] Step 4: Saving metadata...');
      print('  - Duration: ${duration}ms');
      print('  - File size: ${await compressedVideo.length()} bytes');
      
      // Prepare metadata
      final metadata = {
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl ?? '',
        'title': title,
        'description': description,
        'duration': duration,
        'fileSize': await compressedVideo.length(),
        'status': 'active',
        'userId': _auth.currentUser?.uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'views': 0,
        'likes': 0,
        'shares': 0,
        'comments': 0,
        'resolution': '${videoInfo.width}x${videoInfo.height}',
        'originalFileName': path.basename(videoPath),
      };

      // Validate required fields
      final userId = metadata['userId'] as String?;
      if (userId == null || userId.isEmpty) {
        print('[VideoService] ❌ No user ID available');
        return null;
      }

      // Try to save metadata with retry
      String? videoId;
      int retryCount = 0;
      while (retryCount < 3) {
        try {
          videoId = await _metadataService.saveVideoMetadata(
            videoUrl: metadata['videoUrl'] as String,
            thumbnailUrl: metadata['thumbnailUrl'] as String,
            title: metadata['title'] as String,
            description: metadata['description'] as String,
            duration: metadata['duration'] as int,
            fileSize: metadata['fileSize'] as int,
            additionalMetadata: {
              'status': metadata['status'],
              'userId': metadata['userId'],
              'createdAt': metadata['createdAt'],
              'updatedAt': metadata['updatedAt'],
              'views': metadata['views'],
              'likes': metadata['likes'],
              'shares': metadata['shares'],
              'comments': metadata['comments'],
              'resolution': metadata['resolution'],
              'originalFileName': metadata['originalFileName'],
            },
          );
          if (videoId != null) break;
        } catch (e) {
          print('[VideoService] ⚠️ Metadata save attempt ${retryCount + 1} failed: $e');
        }
        retryCount++;
        if (retryCount < 3) await Future.delayed(Duration(seconds: retryCount));
      }

      if (videoId == null) {
        print('[VideoService] ❌ Metadata save failed after $retryCount attempts');
        return null;
      }

      print('[VideoService] ✅ Metadata saved successfully');
      print('  - Video ID: $videoId');

      // Step 5: Cache video locally
      print('\n[VideoService] Step 5: Caching video...');
      try {
        await _cacheService.cacheVideo(videoUrl, compressedVideo);
      } catch (e) {
        print('[VideoService] ⚠️ Cache operation failed: $e');
        // Continue even if caching fails
      }

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

        // Get actual like count from subcollection
        final likesCount = await videoRef
            .collection('likes')
            .count()
            .get()
            .then((value) => value.count);

        if (liked) {
          // Only add like if it doesn't exist
          final likeDoc = await transaction.get(likeRef);
          if (!likeDoc.exists) {
            transaction.set(likeRef, {
              'userId': user.uid,
              'timestamp': FieldValue.serverTimestamp(),
            });
            transaction.update(videoRef, {
              'likes': (likesCount ?? 0) + 1,
              'lastLikeSync': FieldValue.serverTimestamp(),
            });
          }
        } else {
          // Only remove like if it exists
          final likeDoc = await transaction.get(likeRef);
          if (likeDoc.exists) {
            transaction.delete(likeRef);
            transaction.update(videoRef, {
              'likes': (likesCount ?? 0) - 1,
              'lastLikeSync': FieldValue.serverTimestamp(),
            });
          }
        }
      });
    } catch (e) {
      print('[VideoService] ❌ Error updating video like: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getVideoComments(String videoId) async {
    try {
      print('[VideoService] 📝 Getting comments for video: $videoId');
      final snapshot = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();

      final comments = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
      
      print('[VideoService] ✅ Retrieved ${comments.length} comments');
      return comments;
    } catch (e) {
      print('[VideoService] ❌ Error getting video comments: $e');
      print('  - Error details: $e');
      return [];
    }
  }

  // Add new method for streaming comments
  Stream<List<Map<String, dynamic>>> streamVideoComments(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList());
  }

  // Add method to stream video metadata (for comment count)
  Stream<DocumentSnapshot<Map<String, dynamic>>> streamVideoMetadata(String videoId) {
    return _firestore
        .collection('videos')
        .doc(videoId)
        .snapshots();
  }

  Future<Map<String, dynamic>?> addComment(
    String videoId,
    String text,
  ) async {
    try {
      print('[VideoService] 💬 Adding comment to video: $videoId');
      final user = _auth.currentUser;
      if (user == null) {
        print('[VideoService] ❌ No authenticated user');
        return null;
      }

      print('[VideoService] 👤 User info:');
      print('  - User ID: ${user.uid}');
      print('  - Email: ${user.email}');
      print('  - Display Name: ${user.displayName}');
      print('  - Photo URL: ${user.photoURL}');
      print('  - Provider ID: ${user.providerData.map((e) => e.providerId).join(", ")}');

      // Get user data to include in comment
      final userData = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      print('[VideoService] 📄 Firestore user data:');
      print('  - Exists: ${userData.exists}');
      if (userData.exists) {
        print('  - Data: ${userData.data()}');
      }

      // Create default display name from email if no display name is available
      String displayName = userData.data()?['displayName'] ?? 
                          user.displayName ?? 
                          user.email?.split('@')[0] ?? 
                          'Anonymous';

      // Create default photo URL
      String photoUrl = userData.data()?['photoUrl'] ?? 
                       user.photoURL ?? 
                       '';

      print('[VideoService] 📝 Creating comment with:');
      print('  - Display Name: $displayName');
      print('  - Photo URL: $photoUrl');

      final batch = _firestore.batch();
      
      // Create the comment document
      final commentRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc();

      final commentData = {
        'id': commentRef.id,
        'videoId': videoId,
        'userId': user.uid,
        'userDisplayName': displayName,
        'userPhotoUrl': photoUrl,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'replies': [],
      };

      batch.set(commentRef, commentData);

      // Update video comment count
      final videoRef = _firestore.collection('videos').doc(videoId);
      batch.update(videoRef, {
        'comments': FieldValue.increment(1),
        'lastCommentAt': FieldValue.serverTimestamp(),
      });

      // Commit both operations
      await batch.commit();

      print('[VideoService] ✅ Comment added successfully');
      
      // Return immediate data for UI update
      return {
        ...commentData,
        'createdAt': Timestamp.now(), // Use current time for immediate display
      };
    } catch (e, stackTrace) {
      print('[VideoService] ❌ Error adding comment:');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
      rethrow; // Rethrow to handle in UI
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

  Future<List<Map<String, dynamic>>> loadMoreVideos({
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      print('[VideoService] 📥 Loading more videos...');
      print('  - Last document: ${lastDocument?.id}');

      var query = _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(10);

      // Add pagination if we have a last document
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      final snapshot = await query.get();
      
      print('[VideoService] ✅ Loaded ${snapshot.docs.length} videos');

      return snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();
    } catch (e) {
      print('[VideoService] ❌ Error loading more videos: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getDiscoverFeedVideos() async {
    try {
      print('[VideoService] 🔍 Fetching discover feed videos...');
      
      // First get all active videos
      final snapshot = await _firestore
          .collection('videos')
          .where('status', isEqualTo: 'active')
          .limit(50)  // Increased limit since we'll filter some out
          .get();

      print('[VideoService] 📥 Retrieved ${snapshot.docs.length} videos from Firestore');
      
      final videos = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                ...doc.data(),
              })
          .toList();

      // Sort by views in memory
      videos.sort((a, b) => (b['views'] ?? 0).compareTo(a['views'] ?? 0));

      // Filter out videos with empty thumbnails
      final validVideos = <Map<String, dynamic>>[];
      for (final video in videos) {
        final thumbnailUrl = video['thumbnailUrl'] as String? ?? '';
        if (thumbnailUrl.isNotEmpty) {
          try {
            if (await _isValidUrl(thumbnailUrl)) {
              validVideos.add(video);
              if (validVideos.length >= 20) break; // Stop once we have enough valid videos
            } else {
              print('[VideoService] ⚠️ Invalid thumbnail URL found: $thumbnailUrl');
              // Update the video status to indicate thumbnail issue
              await _firestore
                  .collection('videos')
                  .doc(video['id'])
                  .update({
                    'status': 'thumbnail_error',
                    'lastError': 'Invalid thumbnail URL',
                    'lastErrorTimestamp': FieldValue.serverTimestamp(),
                  });
            }
          } catch (e) {
            print('[VideoService] ⚠️ Error validating thumbnail URL: $e');
          }
        }
      }

      print('[VideoService] ✅ Found ${validVideos.length} valid videos for discover feed');
      return validVideos;
    } catch (e) {
      print('[VideoService] ❌ Error getting discover feed videos: $e');
      return [];
    }
  }

  Future<bool> _isValidUrl(String url) async {
    if (url.isEmpty) return false;
    
    try {
      if (url.startsWith('http')) {
        final uri = Uri.parse(url);
        if (!uri.host.contains('firebasestorage.googleapis.com')) {
          return false;
        }
        // Try to get the download URL to validate it exists
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.getDownloadURL();
        return true;
      }
      return false;
    } catch (e) {
      print('[VideoService] URL validation failed: $e');
      return false;
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