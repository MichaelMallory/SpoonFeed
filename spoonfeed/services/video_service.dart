import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;

typedef ProgressCallback = void Function(double progress);

class VideoService {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  DocumentSnapshot? _lastDocument;
  bool _hasMoreVideos = true;
  static const int _pageSize = 10;
  static const int maxRetries = 3;

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
      // Generate a unique filename
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(videoFile.path)}';
      final String userId = _auth.currentUser!.uid;
      
      // Create storage reference
      final Reference storageRef = _storage.ref().child('videos/$userId/$fileName');
      
      // Upload video file with metadata and progress monitoring
      final UploadTask uploadTask = storageRef.putFile(
        videoFile,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'userId': userId,
            'originalName': path.basename(videoFile.path),
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
        'thumbnailUrl': '', // TODO: Generate thumbnail
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'fileName': fileName,
        'fileSize': await videoFile.length(),
        'duration': 0, // TODO: Add video duration
      });

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
      // Generate a unique filename
      final String uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final String userId = _auth.currentUser!.uid;
      
      // Create storage reference with resumable upload
      final Reference storageRef = _storage.ref().child('videos/$userId/$uniqueFileName');
      
      // Upload video file with metadata and progress monitoring
      final UploadTask uploadTask = storageRef.putData(
        videoBytes,
        SettableMetadata(
          contentType: 'video/mp4',
          customMetadata: {
            'userId': userId,
            'originalName': fileName,
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

      // Create video document in Firestore
      final DocumentReference videoDoc = await _firestore.collection('videos').add({
        'userId': userId,
        'title': title,
        'description': description,
        'videoUrl': downloadUrl,
        'thumbnailUrl': '', // TODO: Generate thumbnail
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
        'shares': 0,
        'fileName': uniqueFileName,
        'fileSize': videoBytes.length,
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

  Future<void> likeVideo(String videoId) async {
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

    return _firestore.runTransaction((transaction) async {
      final DocumentSnapshot likeDoc = await transaction.get(likeRef);

      if (likeDoc.exists) {
        // Unlike
        transaction.delete(likeRef);
        transaction.update(videoRef, {'likes': FieldValue.increment(-1)});
      } else {
        // Like
        transaction.set(likeRef, {'timestamp': FieldValue.serverTimestamp()});
        transaction.update(videoRef, {'likes': FieldValue.increment(1)});
      }
    });
  }

  bool get hasMoreVideos => _hasMoreVideos;
} 