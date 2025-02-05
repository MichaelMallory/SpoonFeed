import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_compress/video_compress.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/comment_model.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

typedef ProgressCallback = void Function(double progress);
typedef LikeCallback = void Function(bool isLiked, int newCount);
typedef CommentCallback = void Function(int newCount);

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  DocumentSnapshot? _lastDocument;
  bool _hasMoreVideos = true;
  static const int _pageSize = 10;
  static const int maxRetries = 3;
  static const int maxCacheSize = 2000 * 1024 * 1024; // Increased to 2GB cache limit
  static const int minCacheSizeAfterCleanup = 1000 * 1024 * 1024; // 1GB minimum after cleanup

  // Cache management
  final Map<String, String> _videoCache = {};
  final Map<String, DateTime> _lastAccessTime = {};
  int _currentCacheSize = 0;

  Future<String> _getCachedVideoPath(String videoUrl) async {
    if (_videoCache.containsKey(videoUrl)) {
      final cachedPath = _videoCache[videoUrl]!;
      final file = File(cachedPath);
      if (await file.exists()) {
        print('Cache hit: $videoUrl');
        _lastAccessTime[videoUrl] = DateTime.now(); // Update last access time
        return cachedPath;
      }
      // Cache file doesn't exist, remove from cache
      _videoCache.remove(videoUrl);
      _lastAccessTime.remove(videoUrl);
      _currentCacheSize -= await file.length();
    }

    // Download and cache the video
    final bytes = await http.readBytes(Uri.parse(videoUrl));
    final cacheDir = await getTemporaryDirectory();
    final fileName = md5.convert(utf8.encode(videoUrl)).toString();
    final filePath = '${cacheDir.path}/$fileName.mp4';
    
    // Check if we need to clear some cache
    if (_currentCacheSize + bytes.length > maxCacheSize) {
      await _cleanupCache(bytes.length);
    }
    
    // Save to cache
    await File(filePath).writeAsBytes(bytes);
    _videoCache[videoUrl] = filePath;
    _lastAccessTime[videoUrl] = DateTime.now();
    _currentCacheSize += bytes.length;
    print('Cached video: $videoUrl');
    print('Current cache size: ${_currentCacheSize / (1024 * 1024)}MB');
    
    return filePath;
  }

  Future<void> _cleanupCache(int requiredSpace) async {
    // Sort videos by last access time
    final sortedVideos = _videoCache.keys.toList()
      ..sort((a, b) => _lastAccessTime[a]!.compareTo(_lastAccessTime[b]!));
    
    int freedSpace = 0;
    for (final videoUrl in sortedVideos) {
      if (_currentCacheSize - freedSpace <= minCacheSizeAfterCleanup) break;
      
      final cachedPath = _videoCache[videoUrl]!;
      final file = File(cachedPath);
      if (await file.exists()) {
        freedSpace += await file.length();
        await file.delete();
      }
      
      _videoCache.remove(videoUrl);
      _lastAccessTime.remove(videoUrl);
      print('Removed from cache: $videoUrl');
      
      if (freedSpace >= requiredSpace) break;
    }
    
    _currentCacheSize -= freedSpace;
    print('Cache cleanup complete. New size: ${_currentCacheSize / (1024 * 1024)}MB');
  }

  Future<void> clearCache() async {
    for (final videoUrl in _videoCache.keys.toList()) {
      await _removeCachedVideo(videoUrl);
    }
    print('Cache cleared');
  }

  // Add this method to VideoPlayerFullscreen
  Future<String> getVideoUrl(String videoUrl) async {
    if (kIsWeb) return videoUrl;
    return await _getCachedVideoPath(videoUrl);
  }

  Future<MediaInfo?> compressVideo(String videoPath) async {
    if (kIsWeb) {
      print('Video compression not supported on web platform');
      return null;
    }

    try {
      // Check if there's an ongoing compression
      await VideoCompress.cancelCompression();
      
      final info = await VideoCompress.compressVideo(
        videoPath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      return info;
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  Future<Uint8List?> _compressVideoWeb(Uint8List videoBytes) async {
    try {
      // For web, we'll use FFmpeg.wasm for compression
      // This is a placeholder for the actual implementation
      // TODO: Implement web video compression using FFmpeg.wasm or similar
      print('Web video compression not implemented yet');
      print('Original video size: ${videoBytes.length / (1024 * 1024)}MB');
      return videoBytes;
    } catch (e) {
      print('Error compressing video for web: $e');
      return null;
    }
  }

  Future<String?> _generateThumbnail(String videoPath, {bool isWeb = false}) async {
    try {
      if (kIsWeb) {
        // For web, we'll use a default thumbnail for now
        // In a production app, you might want to use a server-side solution
        print('Web platform detected, using default thumbnail');
        return '';
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_thumb.jpg';
      final thumbnailBytes = await VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 75,
      );
      
      if (thumbnailBytes == null) return null;
      
      final userId = _auth.currentUser!.uid;
      final storageRef = _storage.ref().child('thumbnails/$userId/$fileName');
      
      // Upload thumbnail to Firebase Storage
      final uploadTask = storageRef.putData(
        thumbnailBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print('Error generating thumbnail: $e');
      return '';  // Return empty string instead of null for better error handling
    }
  }

  Future<String> uploadVideo(File videoFile, String userId, ProgressCallback onProgress) async {
    if (kIsWeb) {
      throw UnsupportedError('Direct file upload not supported on web. Use uploadVideoWeb instead.');
    }

    try {
      // Compress video before uploading
      final MediaInfo? compressedInfo = await compressVideo(videoFile.path);
      final File fileToUpload = compressedInfo?.file ?? videoFile;
      
      // Generate thumbnail
      final String? thumbnailUrl = await _generateThumbnail(fileToUpload.path);
      
      // Generate a unique filename
      final String filename = '${userId}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final Reference ref = _storage.ref().child('videos/$filename');

      // Upload the video
      final UploadTask uploadTask = ref.putFile(
        fileToUpload,
        SettableMetadata(contentType: 'video/mp4'),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress(progress);
      });

      // Wait for upload to complete
      await uploadTask;

      // Get download URL
      final String downloadUrl = await ref.getDownloadURL();

      // Create video document in Firestore
      final docRef = await _firestore.collection('videos').add({
        'userId': userId,
        'videoUrl': downloadUrl,
        'thumbnailUrl': thumbnailUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'fileName': filename,
      });

      // Update user's video count
      await _firestore.collection('users').doc(userId).update({
        'videoCount': FieldValue.increment(1),
      });

      return docRef.id;
    } catch (e) {
      print('Error uploading video: $e');
      rethrow;
    }
  }

  Future<String> uploadVideoWeb({
    required Uint8List videoBytes,
    required String fileName,
    required String title,
    required String description,
    ProgressCallback? onProgress,
  }) async {
    if (!kIsWeb) {
      throw UnsupportedError('Web upload method called on non-web platform. Use uploadVideo instead.');
    }

    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to upload videos');
    }

    try {
      print('Starting web video upload. Size: ${videoBytes.length / (1024 * 1024)}MB');
      
      final String userId = _auth.currentUser!.uid;
      final String uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      // Create storage reference
      final Reference storageRef = _storage.ref().child('videos/$userId/$uniqueFileName');
      
      // Upload video file with metadata
      final UploadTask uploadTask = storageRef.putData(
        videoBytes,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'userId': userId,
            'originalName': fileName,
            'title': title,
            'description': description,
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);
          print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        },
        onError: (error) {
          print('Upload error: $error');
          throw error;
        },
      );

      // Wait for upload to complete
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Generate thumbnail URL (we'll update this later when possible)
      String thumbnailUrl = '';
      try {
        thumbnailUrl = await _generateThumbnail(downloadUrl, isWeb: true) ?? '';
      } catch (e) {
        print('Error generating thumbnail: $e');
      }
      
      // Create video document in Firestore
      final DocumentReference videoDoc = await _firestore.collection('videos').add({
        'userId': userId,
        'title': title,
        'description': description,
        'videoUrl': downloadUrl,
        'thumbnailUrl': thumbnailUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'fileName': uniqueFileName,
        'fileSize': videoBytes.length,
      });

      // Update user's video count
      await _firestore.collection('users').doc(userId).update({
        'videoCount': FieldValue.increment(1),
      });

      return videoDoc.id;
    } catch (e) {
      print('Error in uploadVideoWeb: $e');
      throw Exception('Failed to upload video: ${e.toString()}');
    }
  }

  Stream<QuerySnapshot> getVideoFeed() {
    return _firestore
        .collection('videos')
        .orderBy('createdAt', descending: true)
        .limit(_pageSize)
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot>> loadMoreVideos() async {
    if (!_hasMoreVideos) return [];

    try {
      Query query = _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final QuerySnapshot snapshot = await query.get();
      
      if (snapshot.docs.length < _pageSize) {
        _hasMoreVideos = false;
      }

      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }

      return snapshot.docs;
    } catch (e) {
      print('Error loading more videos: $e');
      return [];
    }
  }

  // Get user's videos
  Future<List<QueryDocumentSnapshot>> getUserVideos(String userId) async {
    try {
      print('[VideoService] Fetching videos for user: $userId');
      final QuerySnapshot snapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      print('[VideoService] Found ${snapshot.docs.length} videos for user');
      return snapshot.docs;
    } catch (e) {
      print('[VideoService] Error getting user videos: $e');
      rethrow;
    }
  }

  // New method to get discover feed videos (random selection)
  Future<List<QueryDocumentSnapshot>> getDiscoverFeedVideos() async {
    try {
      // Get a larger batch of recent videos
      final QuerySnapshot snapshot = await _firestore
          .collection('videos')
          .orderBy('createdAt', descending: true)
          .limit(50)  // Get more videos to randomize from
          .get();

      final List<QueryDocumentSnapshot> docs = snapshot.docs;
      if (docs.isEmpty) return [];

      // Shuffle the videos for randomization
      docs.shuffle();

      // Return first _pageSize videos
      return docs.take(_pageSize).toList();
    } catch (e) {
      print('Error getting discover feed videos: $e');
      return [];
    }
  }

  void resetPagination() {
    _lastDocument = null;
    _hasMoreVideos = true;
  }

  Future<bool> isVideoLikedByUser(String videoId) async {
    if (_auth.currentUser == null) return false;
    
    final likeDoc = await _firestore
        .collection('videos')
        .doc(videoId)
        .collection('likes')
        .doc(_auth.currentUser!.uid)
        .get();
        
    return likeDoc.exists;
  }

  Future<void> likeVideo(String videoId, {LikeCallback? onLikeUpdated}) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to like videos');
    }

    final String userId = _auth.currentUser!.uid;
    final DocumentReference videoRef = _firestore.collection('videos').doc(videoId);
    final DocumentReference likeRef = _firestore
        .collection('videos')
        .doc(videoId)
        .collection('likes')
        .doc(userId);

    try {
      bool isLiked = false;
      int newCount = 0;
      
      await _firestore.runTransaction((transaction) async {
        final DocumentSnapshot likeDoc = await transaction.get(likeRef);
        final DocumentSnapshot videoDoc = await transaction.get(videoRef);
        
        if (likeDoc.exists) {
          // Unlike
          transaction.delete(likeRef);
          transaction.update(videoRef, {'likes': FieldValue.increment(-1)});
          isLiked = false;
          newCount = (videoDoc.data() as Map<String, dynamic>)['likes'] - 1;
        } else {
          // Like
          transaction.set(likeRef, {'timestamp': FieldValue.serverTimestamp()});
          transaction.update(videoRef, {'likes': FieldValue.increment(1)});
          isLiked = true;
          newCount = (videoDoc.data() as Map<String, dynamic>)['likes'] + 1;
        }
      });
      
      onLikeUpdated?.call(isLiked, newCount);
    } catch (e) {
      print('Error updating like: $e');
      rethrow;
    }
  }

  Future<List<CommentModel>> getVideoComments(String videoId) async {
    try {
      final QuerySnapshot commentsSnapshot = await _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .get();

      return commentsSnapshot.docs
          .map((doc) => CommentModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting comments: $e');
      return [];
    }
  }

  Future<CommentModel> addComment(String videoId, String text, {CommentCallback? onCommentAdded}) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to comment');
    }

    try {
      final user = _auth.currentUser!;
      final videoRef = _firestore.collection('videos').doc(videoId);
      final commentsRef = videoRef.collection('comments');

      // Create the comment document
      final commentDoc = await commentsRef.add({
        'videoId': videoId,
        'userId': user.uid,
        'userDisplayName': user.displayName ?? 'Anonymous',
        'userPhotoUrl': user.photoURL ?? '',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'likedBy': [],
        'replies': [],
      });

      // Update comment count on video
      await _firestore.runTransaction((transaction) async {
        final videoDoc = await transaction.get(videoRef);
        final currentComments = (videoDoc.data() as Map<String, dynamic>)['comments'] ?? 0;
        transaction.update(videoRef, {'comments': currentComments + 1});
        onCommentAdded?.call(currentComments + 1);
      });

      // Get the created comment
      final commentSnapshot = await commentDoc.get();
      return CommentModel.fromFirestore(commentSnapshot);
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  Future<void> deleteComment(String videoId, String commentId, {CommentCallback? onCommentDeleted}) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to delete comments');
    }

    try {
      final videoRef = _firestore.collection('videos').doc(videoId);
      final commentRef = videoRef.collection('comments').doc(commentId);

      // Verify comment ownership
      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) return;
      
      final commentData = commentDoc.data() as Map<String, dynamic>;
      if (commentData['userId'] != _auth.currentUser!.uid) {
        throw Exception('You can only delete your own comments');
      }

      // Delete comment and update count
      await _firestore.runTransaction((transaction) async {
        transaction.delete(commentRef);
        
        final videoDoc = await transaction.get(videoRef);
        final currentComments = (videoDoc.data() as Map<String, dynamic>)['comments'] ?? 0;
        if (currentComments > 0) {
          transaction.update(videoRef, {'comments': currentComments - 1});
          onCommentDeleted?.call(currentComments - 1);
        }
      });
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }

  Future<void> likeComment(String videoId, String commentId) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to like comments');
    }

    try {
      final commentRef = _firestore
          .collection('videos')
          .doc(videoId)
          .collection('comments')
          .doc(commentId);

      await _firestore.runTransaction((transaction) async {
        final commentDoc = await transaction.get(commentRef);
        if (!commentDoc.exists) return;

        final userId = _auth.currentUser!.uid;
        final data = commentDoc.data() as Map<String, dynamic>;
        final likedBy = List<String>.from(data['likedBy'] ?? []);

        if (likedBy.contains(userId)) {
          // Unlike
          likedBy.remove(userId);
          transaction.update(commentRef, {
            'likes': FieldValue.increment(-1),
            'likedBy': likedBy,
          });
        } else {
          // Like
          likedBy.add(userId);
          transaction.update(commentRef, {
            'likes': FieldValue.increment(1),
            'likedBy': likedBy,
          });
        }
      });
    } catch (e) {
      print('Error liking comment: $e');
      rethrow;
    }
  }

  Future<void> updateShareCount(String videoId, {required int newCount}) async {
    try {
      final videoRef = _firestore.collection('videos').doc(videoId);
      await videoRef.update({'shares': newCount});
    } catch (e) {
      print('Error updating share count: $e');
      rethrow;
    }
  }

  Future<void> _removeCachedVideo(String videoUrl) async {
    if (_videoCache.containsKey(videoUrl)) {
      final cachedPath = _videoCache[videoUrl]!;
      final file = File(cachedPath);
      if (await file.exists()) {
        _currentCacheSize -= await file.length();
        await file.delete();
      }
      _videoCache.remove(videoUrl);
      _lastAccessTime.remove(videoUrl);
    }
  }

  bool get hasMoreVideos => _hasMoreVideos;

  // Update user's video count
  Future<void> updateUserVideoCount(String userId) async {
    try {
      // Get the actual count of user's videos
      final QuerySnapshot videoSnapshot = await _firestore
          .collection('videos')
          .where('userId', isEqualTo: userId)
          .get();

      // Update the user document with the accurate count
      await _firestore.collection('users').doc(userId).update({
        'videoCount': videoSnapshot.docs.length,
      });
    } catch (e) {
      print('[VideoService] Error updating video count: $e');
      rethrow;
    }
  }
} 