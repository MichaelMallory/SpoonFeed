import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import 'video_compression_service.dart';
import 'video_thumbnail_service.dart';
import 'video_storage_service.dart';
import 'video_cache_service.dart';
import 'video_metadata_service.dart';
import '../auth_service.dart';

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

  static const int MAX_CACHE_SIZE_MB = 500; // 500MB max cache
  static const int MAX_CACHE_AGE_HOURS = 24; // Clear cache entries older than 24 hours

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

      // Step 3: Create initial metadata document
      print('\n[VideoService] Step 3: Creating initial metadata...');
      print('  - Duration: ${duration}ms');
      print('  - File size: ${await compressedVideo.length()} bytes');
      
      // Prepare metadata
      final metadata = {
        'videoUrl': '', // Will be updated after upload
        'thumbnailUrl': thumbnailUrl ?? '',
        'title': title,
        'description': description,
        'duration': duration,
        'fileSize': await compressedVideo.length(),
        'status': 'uploading', // Mark as uploading initially
        'userId': _auth.currentUser?.uid ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'views': 0,
        'likes': 0,
        'shares': 0,
        'comments': 0,
        'resolution': '${videoInfo.width}x${videoInfo.height}',
      };

      print('[VideoService] 📝 Prepared metadata:');
      metadata.forEach((key, value) {
        print('  - $key: $value');
      });

      // Validate required fields
      final userId = metadata['userId'] as String?;
      if (userId == null || userId.isEmpty) {
        print('[VideoService] ❌ No user ID available');
        return null;
      }

      // Create initial document
      String? videoId;
      int retryCount = 0;
      while (retryCount < 3) {
        try {
          print('[VideoService] 🔄 Attempt ${retryCount + 1} to save metadata');
          print('[VideoService] 📤 Sending to metadata service:');
          print('  - videoUrl: ${metadata['videoUrl']}');
          print('  - thumbnailUrl: ${metadata['thumbnailUrl']}');
          print('  - title: ${metadata['title']}');
          print('  - description: ${metadata['description']}');
          print('  - duration: ${metadata['duration']}');
          print('  - fileSize: ${metadata['fileSize']}');
          print('  Additional metadata:');
          print('    - status: ${metadata['status']}');
          print('    - userId: ${metadata['userId']}');
          print('    - createdAt: ${metadata['createdAt']}');
          print('    - updatedAt: ${metadata['updatedAt']}');
          print('    - views: ${metadata['views']}');
          print('    - likes: ${metadata['likes']}');
          print('    - shares: ${metadata['shares']}');
          print('    - comments: ${metadata['comments']}');
          print('    - resolution: ${metadata['resolution']}');

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
            },
          );
          if (videoId != null) break;
        } catch (e, stackTrace) {
          print('[VideoService] ⚠️ Metadata save attempt ${retryCount + 1} failed:');
          print('  Error: $e');
          print('  Stack trace: $stackTrace');
        }
        retryCount++;
        if (retryCount < 3) await Future.delayed(Duration(seconds: retryCount));
      }

      if (videoId == null) {
        print('[VideoService] ❌ Metadata save failed after $retryCount attempts');
        return null;
      }

      print('[VideoService] ✅ Initial metadata saved successfully');
      print('  - Video ID: $videoId');

      // Step 4: Upload video
      print('\n[VideoService] Step 4: Uploading video...');
      final videoUrl = await _storageService.uploadVideo(
        compressedVideo.path,
        onProgress: onProgress,
        isWeb: isWeb,
      );

      if (videoUrl == null) {
        print('[VideoService] ❌ Video upload failed');
        // Update status to failed
        await _metadataService.updateVideoMetadata(videoId, {
          'status': 'failed',
          'error': 'Video upload failed'
        });
        return null;
      }

      print('[VideoService] Video URL after upload: $videoUrl');

      // Step 5: Update metadata with video URL
      print('\n[VideoService] Step 5: Updating metadata with video URL...');
      final updated = await _metadataService.updateVideoMetadata(videoId, {
        'videoUrl': videoUrl,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!updated) {
        print('[VideoService] ❌ Failed to update metadata with video URL');
        return null;
      }

      // Step 6: Cache video locally
      print('\n[VideoService] Step 6: Caching video...');
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
    try {
      final cacheDir = await _getCacheDirectory();
      final videoHash = _generateVideoHash(videoUrl);
      final cachedFile = File(path.join(cacheDir.path, '$videoHash.mp4'));
      
      if (await cachedFile.exists()) {
        // Check if cache is too old
        final stat = await cachedFile.stat();
        final age = DateTime.now().difference(stat.modified);
        
        if (age.inHours > MAX_CACHE_AGE_HOURS) {
          print('[VideoService] 🧹 Removing old cached video: $videoHash');
          await cachedFile.delete();
          return null;
        }
        
        return cachedFile.path;
      }
      
      // If not cached, download and cache
      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode == 200) {
        // Check cache size before writing
        await _ensureCacheSize(cacheDir);
        
        await cachedFile.writeAsBytes(response.bodyBytes);
        print('[VideoService] ✅ Video cached successfully: $videoHash');
        return cachedFile.path;
      }
      
      return null;
    } catch (e) {
      print('[VideoService] ❌ Error caching video: $e');
      return null;
    }
  }

  Future<String?> getVideoUrl(String videoPath, {String quality = 'high'}) async {
    try {
      // Get the video document from Firestore
      final videoRef = _firestore.doc(videoPath);
      final videoDoc = await videoRef.get();
      
      if (!videoDoc.exists) {
        print('[VideoService] ❌ Video document not found: $videoPath');
        return null;
      }
      
      // Get the appropriate quality URL
      final urls = videoDoc.data()?['urls'] as Map<String, dynamic>?;
      if (urls == null) {
        print('[VideoService] ❌ No URLs found for video: $videoPath');
        return null;
      }
      
      // Try to get requested quality, fallback to available quality
      String? url = urls[quality] as String?;
      if (url == null && quality == 'high') {
        print('[VideoService] ⚠️ High quality not available, falling back to low');
        url = urls['low'] as String?;
      } else if (url == null && quality == 'low') {
        print('[VideoService] ⚠️ Low quality not available, falling back to high');
        url = urls['high'] as String?;
      }
      
      return url;
    } catch (e) {
      print('[VideoService] ❌ Error getting video URL: $e');
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

  Future<QuerySnapshot<Map<String, dynamic>>> loadMoreVideos({
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

      return snapshot;
    } catch (e) {
      print('[VideoService] ❌ Error loading more videos: $e');
      throw e;
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

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(path.join(appDir.path, 'video_cache'));
    
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    
    return cacheDir;
  }

  Future<void> _ensureCacheSize(Directory cacheDir) async {
    final files = cacheDir.listSync();
    int totalSize = 0;
    
    // Calculate current cache size
    for (var file in files) {
      if (file is File) {
        totalSize += file.lengthSync();
      }
    }
    
    // If we're over the limit, remove old files
    if (totalSize > MAX_CACHE_SIZE_MB * 1024 * 1024) {
      print('[VideoService] ⚠️ Cache size exceeded, cleaning up...');
      await clearOldCache();
    }
  }

  String _generateVideoHash(String url) {
    // Simple hash function for video URLs
    var hash = 0;
    for (var i = 0; i < url.length; i++) {
      hash = ((hash << 5) - hash) + url.codeUnitAt(i);
      hash &= hash; // Convert to 32-bit integer
    }
    return hash.abs().toString();
  }

  Future<void> clearOldCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      final files = cacheDir.listSync();
      
      // Sort files by last modified time
      files.sort((a, b) {
        final aTime = (a as File).lastModifiedSync();
        final bTime = (b as File).lastModifiedSync();
        return aTime.compareTo(bTime);
      });
      
      // Calculate total cache size
      int totalSize = 0;
      for (var file in files) {
        if (file is File) {
          totalSize += file.lengthSync();
        }
      }
      
      // Remove old files until we're under the limit
      for (var file in files) {
        if (file is File) {
          final age = DateTime.now().difference(file.lastModifiedSync());
          final size = file.lengthSync();
          
          if (age.inHours > MAX_CACHE_AGE_HOURS || 
              totalSize > MAX_CACHE_SIZE_MB * 1024 * 1024) {
            print('[VideoService] 🧹 Removing cached file: ${file.path}');
            await file.delete();
            totalSize -= size;
          }
          
          if (totalSize <= MAX_CACHE_SIZE_MB * 1024 * 1024) {
            break;
          }
        }
      }
    } catch (e) {
      print('[VideoService] ❌ Error clearing cache: $e');
    }
  }

  void _logError(dynamic error, StackTrace stackTrace) {
    print('[VideoService] ❌ Error in video operation:');
    print('  - Error: $error');
    print('  - Stack trace: $stackTrace');
  }
} 