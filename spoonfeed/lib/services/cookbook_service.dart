import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cookbook_model.dart';
import '../models/video_model.dart';

class CookbookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get user's cookbooks
  Stream<List<CookbookModel>> getUserCookbooks() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('cookbooks')
        .where('userId', isEqualTo: user.uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CookbookModel.fromFirestore(doc))
            .toList());
  }

  // Create a new cookbook
  Future<CookbookModel?> createCookbook({
    required String name,
    String description = '',
  }) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final docRef = await _firestore.collection('cookbooks').add({
        'userId': user.uid,
        'name': name,
        'description': description,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'videoCount': 0,
      });

      final doc = await docRef.get();
      return CookbookModel.fromFirestore(doc);
    } catch (e) {
      print('[CookbookService] Error creating cookbook: $e');
      return null;
    }
  }

  // Add video to cookbook
  Future<bool> addVideoToCookbook(String cookbookId, VideoModel video) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final batch = _firestore.batch();
      
      // Add video reference to cookbook
      final videoRef = _firestore
          .collection('cookbooks')
          .doc(cookbookId)
          .collection('videos')
          .doc(video.id);

      batch.set(videoRef, {
        'videoId': video.id,
        'addedAt': FieldValue.serverTimestamp(),
      });

      // Update cookbook metadata
      final cookbookRef = _firestore.collection('cookbooks').doc(cookbookId);
      batch.update(cookbookRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'videoCount': FieldValue.increment(1),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('[CookbookService] Error adding video to cookbook: $e');
      return false;
    }
  }

  // Remove video from cookbook
  Future<bool> removeVideoFromCookbook(String cookbookId, String videoId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final batch = _firestore.batch();
      
      // Remove video reference
      final videoRef = _firestore
          .collection('cookbooks')
          .doc(cookbookId)
          .collection('videos')
          .doc(videoId);

      batch.delete(videoRef);

      // Update cookbook metadata
      final cookbookRef = _firestore.collection('cookbooks').doc(cookbookId);
      batch.update(cookbookRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'videoCount': FieldValue.increment(-1),
      });

      await batch.commit();
      return true;
    } catch (e) {
      print('[CookbookService] Error removing video from cookbook: $e');
      return false;
    }
  }

  // Get videos in a cookbook
  Stream<List<VideoModel>> getCookbookVideos(String cookbookId) {
    return _firestore
        .collection('cookbooks')
        .doc(cookbookId)
        .collection('videos')
        .orderBy('addedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          final videoIds = snapshot.docs.map((doc) => doc['videoId'] as String).toList();
          if (videoIds.isEmpty) return [];

          // Get all video documents
          final videoSnapshots = await Future.wait(
            videoIds.map((id) => _firestore.collection('videos').doc(id).get())
          );

          return videoSnapshots
              .where((doc) => doc.exists)
              .map((doc) => VideoModel.fromFirestore(doc))
              .toList();
        });
  }

  // Check if a video is in any cookbook
  Future<List<String>> getVideoCookbooks(String videoId) async {
    final user = _auth.currentUser;
    if (user == null) return [];

    try {
      final cookbooks = await _firestore
          .collection('cookbooks')
          .where('userId', isEqualTo: user.uid)
          .get();

      final cookbookIds = <String>[];
      
      for (final cookbook in cookbooks.docs) {
        final hasVideo = await cookbook.reference
            .collection('videos')
            .doc(videoId)
            .get()
            .then((doc) => doc.exists);

        if (hasVideo) {
          cookbookIds.add(cookbook.id);
        }
      }

      return cookbookIds;
    } catch (e) {
      print('[CookbookService] Error checking video cookbooks: $e');
      return [];
    }
  }

  // Delete a cookbook
  Future<bool> deleteCookbook(String cookbookId) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      // Delete all videos in the cookbook
      final videosSnapshot = await _firestore
          .collection('cookbooks')
          .doc(cookbookId)
          .collection('videos')
          .get();

      final batch = _firestore.batch();
      for (final doc in videosSnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Delete the cookbook document
      batch.delete(_firestore.collection('cookbooks').doc(cookbookId));
      
      await batch.commit();
      return true;
    } catch (e) {
      print('[CookbookService] Error deleting cookbook: $e');
      return false;
    }
  }
} 