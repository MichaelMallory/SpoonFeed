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
  static const int maxCacheSize = 500 * 1024 * 1024; // 500MB cache limit

  // Cache management
  final Map<String, String> _videoCache = {};
  int _currentCacheSize = 0;

  Future<String> _getCachedVideoPath(String videoUrl) async {
    if (_videoCache.containsKey(videoUrl)) {
      final cachedPath = _videoCache[videoUrl]!;
      final file = File(cachedPath);
      if (await file.exists()) {
        print('Cache hit: $videoUrl');
        return cachedPath;
      }
      // Cache file doesn't exist, remove from cache
      _videoCache.remove(videoUrl);
      _currentCacheSize -= await file.length();
    }

    // Download and cache the video
    final bytes = await http.readBytes(Uri.parse(videoUrl));
    final cacheDir = await getTemporaryDirectory();
    final fileName = md5.convert(utf8.encode(videoUrl)).toString();
    final filePath = '${cacheDir.path}/$fileName.mp4';
    
    // Check if we need to clear some cache
    while (_currentCacheSize + bytes.length > maxCacheSize && _videoCache.isNotEmpty) {
      final oldestUrl = _videoCache.keys.first;
      await _removeCachedVideo(oldestUrl);
    }
    
    // Save to cache
    await File(filePath).writeAsBytes(bytes);
    _videoCache[videoUrl] = filePath;
    _currentCacheSize += bytes.length;
    print('Cached video: $videoUrl');
    print('Current cache size: ${_currentCacheSize / (1024 * 1024)}MB');
    
    return filePath;
  }

  Future<void> _removeCachedVideo(String videoUrl) async {
    final cachedPath = _videoCache.remove(videoUrl);
    if (cachedPath != null) {
      final file = File(cachedPath);
      if (await file.exists()) {
        _currentCacheSize -= await file.length();
        await file.delete();
        print('Removed from cache: $videoUrl');
      }
    }
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

  Future<File?> _compressVideo(File videoFile) async {
    try {
      // Get original video info
      final MediaInfo? originalInfo = await VideoCompress.getMediaInfo(videoFile.path);
      if (originalInfo == null) return null;
      
      print('Original video size: ${(originalInfo.filesize ?? 0) / (1024 * 1024)}MB');
      print('Original video duration: ${originalInfo.duration}s');
      
      // Calculate target bitrate based on video duration
      // Aim for ~1MB per minute of video, with a minimum of 2MB
      final double durationInMinutes = (originalInfo.duration ?? 0) / 60;
      final int targetSize = max(2, (durationInMinutes * 1).round()) * 1024 * 1024; // in bytes
      final int targetBitrate = (targetSize * 8) ~/ (originalInfo.duration ?? 1); // in bits per second

      // Compress video with calculated bitrate
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        videoFile.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 30,
        bitrate: targetBitrate,
      );
      
      if (mediaInfo?.file == null) return null;

      // Log compression results
      final double compressionRatio = (originalInfo.filesize ?? 1) / (mediaInfo?.filesize ?? 1);
      print('Compressed video size: ${(mediaInfo?.filesize ?? 0) / (1024 * 1024)}MB');
      print('Compression ratio: ${compressionRatio.toStringAsFixed(2)}x');
      
      // If compression didn't help much, return original
      if (compressionRatio < 1.2) {
        print('Compression not effective enough, using original file');
        return null;
      }

      return mediaInfo?.file;
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
      return null;
    }
  }

  Future<String> uploadVideo({
    required File videoFile,
    required String title,
    required String description,
    ProgressCallback? onProgress,
  }) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to upload videos');
    }

    try {
      // Compress video before uploading
      final File? compressedVideo = await _compressVideo(videoFile);
      final File fileToUpload = compressedVideo ?? videoFile;
      
      // Generate a unique filename
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(fileToUpload.path)}';
      final String userId = _auth.currentUser!.uid;
      
      // Create storage reference
      final Reference storageRef = _storage.ref().child('videos/$userId/$fileName');
      
      // Generate thumbnail before uploading video
      final String? thumbnailUrl = await _generateThumbnail(fileToUpload.path);
      
      // Upload video file with metadata and progress monitoring
      final UploadTask uploadTask = storageRef.putFile(
        fileToUpload,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'userId': userId,
            'originalName': path.basename(videoFile.path),
            'isCompressed': (compressedVideo != null).toString(),
          },
        ),
      );

      // Monitor upload progress
      uploadTask.snapshotEvents.listen(
        (TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          onProgress?.call(progress);
        },
        onError: (error) {
          print('Upload error: $error');
          throw error;
        },
      );

      // Wait for upload to complete with retry logic
      TaskSnapshot snapshot;
      int retryCount = 0;
      while (true) {
        try {
          snapshot = await uploadTask;
          break;
        } catch (e) {
          if (retryCount >= maxRetries) rethrow;
          retryCount++;
          await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
          continue;
        }
      }

      final String downloadUrl = await snapshot.ref.getDownloadURL();

      // Create video document in Firestore
      final DocumentReference videoDoc = await _firestore.collection('videos').add({
        'userId': userId,
        'title': title,
        'description': description,
        'videoUrl': downloadUrl,
        'thumbnailUrl': thumbnailUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'fileName': fileName,
        'fileSize': await fileToUpload.length(),
        'originalSize': await videoFile.length(),
        'isCompressed': compressedVideo != null,
        'duration': 0, // TODO: Add video duration
      });

      // Clean up compressed file if it was created
      if (compressedVideo != null && compressedVideo.existsSync()) {
        await compressedVideo.delete();
      }

      return videoDoc.id;
    } catch (e) {
      print('Error in uploadVideo: $e');
      throw Exception('Failed to upload video: ${e.toString()}');
    }
  }

  Future<String> uploadVideoWeb({
    required Uint8List videoBytes,
    required String fileName,
    required String title,
    required String description,
    ProgressCallback? onProgress,
  }) async {
    if (_auth.currentUser == null) {
      throw Exception('User must be logged in to upload videos');
    }

    try {
      // Compress video bytes for web
      final Uint8List? compressedBytes = await _compressVideoWeb(videoBytes);
      final bytesToUpload = compressedBytes ?? videoBytes;
      
      // Generate a unique filename
      final String uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final String userId = _auth.currentUser!.uid;
      
      // Create storage reference with resumable upload
      final Reference storageRef = _storage.ref().child('videos/$userId/$uniqueFileName');
      
      // Upload video file with metadata and progress monitoring
      final UploadTask uploadTask = storageRef.putData(
        bytesToUpload,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'userId': userId,
            'originalName': fileName,
            'isCompressed': (compressedBytes != null).toString(),
          },
        ),
      );

      // Monitor upload progress with error handling
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

      // Wait for upload to complete with retry logic
      TaskSnapshot snapshot;
      int retryCount = 0;
      while (true) {
        try {
          snapshot = await uploadTask;
          break;
        } catch (e) {
          if (retryCount >= maxRetries) rethrow;
          retryCount++;
          await Future.delayed(Duration(seconds: retryCount * 2)); // Exponential backoff
          continue;
        }
      }

      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Generate thumbnail from the uploaded video URL
      final String? thumbnailUrl = await _generateThumbnail(downloadUrl, isWeb: true);

      // Create video document in Firestore
      final DocumentReference videoDoc = await _firestore.collection('videos').add({
        'userId': userId,
        'title': title,
        'description': description,
        'videoUrl': downloadUrl,
        'thumbnailUrl': thumbnailUrl ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'fileName': uniqueFileName,
        'fileSize': bytesToUpload.length,
        'originalSize': videoBytes.length,
        'isCompressed': compressedBytes != null,
        'duration': 0, // TODO: Add video duration
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

  bool get hasMoreVideos => _hasMoreVideos;
} 