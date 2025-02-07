import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoMetadataService {
  // Singleton instance
  static final VideoMetadataService _instance = VideoMetadataService._internal();
  factory VideoMetadataService() => _instance;
  VideoMetadataService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constants for validation
  static const int maxTitleLength = 100;
  static const int maxDescriptionLength = 5000;
  static const int batchSize = 500;

  Future<String?> saveVideoMetadata({
    required String videoUrl,
    required String thumbnailUrl,
    required String title,
    required String description,
    required int duration,
    required int fileSize,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return null;
      }

      // Validate input data
      if (!_validateMetadata(
        title: title,
        description: description,
        duration: duration,
        fileSize: fileSize,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
      )) {
        return null;
      }

      print('[VideoMetadataService] 💾 Saving video metadata...');
      print('  - Video URL: $videoUrl');
      print('  - Title: $title');
      print('  - User ID: ${user!.uid}');

      final metadata = _createMetadata(
        userId: user.uid,
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        title: title,
        description: description,
        duration: duration,
        fileSize: fileSize,
        additionalMetadata: additionalMetadata,
      );

      final docRef = await _firestore
          .collection('videos')
          .add(metadata);

      print('[VideoMetadataService] ✅ Metadata saved successfully');
      print('  - Document ID: ${docRef.id}');

      return docRef.id;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return null;
    }
  }

  Future<List<String?>> saveVideoMetadataBatch(
    List<Map<String, dynamic>> metadataList,
  ) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return List.filled(metadataList.length, null);
      }

      print('[VideoMetadataService] 💾 Saving batch metadata...');
      print('  - Batch size: ${metadataList.length}');

      final results = <String?>[];
      final batches = <List<Map<String, dynamic>>>[];

      // Split into batches of 500 (Firestore limit)
      for (var i = 0; i < metadataList.length; i += batchSize) {
        batches.add(
          metadataList.sublist(
            i,
            i + batchSize > metadataList.length ? metadataList.length : i + batchSize,
          ),
        );
      }

      print('  - Number of batches: ${batches.length}');

      for (var i = 0; i < batches.length; i++) {
        print('\n[VideoMetadataService] Processing batch ${i + 1}/${batches.length}');
        final batch = _firestore.batch();
        final batchRefs = <DocumentReference>[];

        for (final metadata in batches[i]) {
          // Validate metadata
          if (!_validateMetadata(
            title: metadata['title'],
            description: metadata['description'],
            duration: metadata['duration'],
            fileSize: metadata['fileSize'],
            videoUrl: metadata['videoUrl'],
            thumbnailUrl: metadata['thumbnailUrl'],
          )) {
            results.add(null);
            continue;
          }

          final docRef = _firestore.collection('videos').doc();
          batchRefs.add(docRef);

          final processedMetadata = _createMetadata(
            userId: user!.uid,
            videoUrl: metadata['videoUrl'],
            thumbnailUrl: metadata['thumbnailUrl'],
            title: metadata['title'],
            description: metadata['description'],
            duration: metadata['duration'],
            fileSize: metadata['fileSize'],
            additionalMetadata: metadata['additionalMetadata'],
          );

          batch.set(docRef, processedMetadata);
        }

        // Commit batch
        await batch.commit();
        results.addAll(batchRefs.map((ref) => ref.id));
        
        print('  - Batch ${i + 1} completed: ${batchRefs.length} documents');
      }

      print('[VideoMetadataService] ✅ Batch operation completed');
      print('  - Total successful: ${results.where((id) => id != null).length}');
      print('  - Total failed: ${results.where((id) => id == null).length}');

      return results;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return List.filled(metadataList.length, null);
    }
  }

  Future<Map<String, dynamic>?> getVideoMetadata(String videoId) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return null;
      }

      print('[VideoMetadataService] 🔍 Fetching video metadata...');
      print('  - Video ID: $videoId');

      final docSnapshot = await _firestore
          .collection('videos')
          .doc(videoId)
          .get();

      if (!docSnapshot.exists) {
        print('[VideoMetadataService] ❌ Video metadata not found');
        return null;
      }

      final data = docSnapshot.data()!;
      
      // Validate retrieved data
      if (!_validateMetadata(
        title: data['title'],
        description: data['description'],
        duration: data['duration'],
        fileSize: data['fileSize'],
        videoUrl: data['videoUrl'],
        thumbnailUrl: data['thumbnailUrl'],
      )) {
        print('[VideoMetadataService] ❌ Retrieved metadata is invalid');
        return null;
      }

      print('[VideoMetadataService] ✅ Metadata retrieved successfully');
      return data;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getVideoMetadataBatch(List<String> videoIds) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return [];
      }

      print('[VideoMetadataService] 🔍 Fetching batch metadata...');
      print('  - Batch size: ${videoIds.length}');

      final results = <Map<String, dynamic>>[];
      final batches = <List<String>>[];

      // Split into batches of 10 (Firestore limit for in queries)
      for (var i = 0; i < videoIds.length; i += 10) {
        batches.add(
          videoIds.sublist(
            i,
            i + 10 > videoIds.length ? videoIds.length : i + 10,
          ),
        );
      }

      for (final batch in batches) {
        final querySnapshot = await _firestore
            .collection('videos')
            .where(FieldPath.documentId, whereIn: batch)
            .get();

        for (final doc in querySnapshot.docs) {
          final data = doc.data();
          if (_validateMetadata(
            title: data['title'],
            description: data['description'],
            duration: data['duration'],
            fileSize: data['fileSize'],
            videoUrl: data['videoUrl'],
            thumbnailUrl: data['thumbnailUrl'],
          )) {
            results.add(data);
          }
        }
      }

      print('[VideoMetadataService] ✅ Batch fetch completed');
      print('  - Retrieved: ${results.length}/${videoIds.length}');

      return results;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return [];
    }
  }

  Future<bool> updateVideoMetadata(
    String videoId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return false;
      }

      print('[VideoMetadataService] 📝 Updating video metadata...');
      print('  - Video ID: $videoId');
      print('  - Updates: $updates');

      // Validate updates
      if (updates.containsKey('title') && !_validateTitle(updates['title'])) return false;
      if (updates.containsKey('description') && !_validateDescription(updates['description'])) return false;
      if (updates.containsKey('duration') && !_validateDuration(updates['duration'])) return false;
      if (updates.containsKey('fileSize') && !_validateFileSize(updates['fileSize'])) return false;
      if (updates.containsKey('videoUrl') && !_validateUrl(updates['videoUrl'])) return false;
      if (updates.containsKey('thumbnailUrl') && !_validateUrl(updates['thumbnailUrl'])) return false;

      await _firestore
          .collection('videos')
          .doc(videoId)
          .update({
        ...updates,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('[VideoMetadataService] ✅ Metadata updated successfully');
      return true;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return false;
    }
  }

  Future<Map<String, bool>> updateVideoMetadataBatch(
    Map<String, Map<String, dynamic>> updates,
  ) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return Map.fromIterables(
          updates.keys,
          List.filled(updates.length, false),
        );
      }

      print('[VideoMetadataService] 📝 Updating batch metadata...');
      print('  - Batch size: ${updates.length}');

      final results = <String, bool>{};
      final batch = _firestore.batch();
      var validUpdates = 0;

      for (final entry in updates.entries) {
        final videoId = entry.key;
        final updateData = entry.value;

        // Validate updates
        if (!_validateUpdateData(updateData)) {
          results[videoId] = false;
          continue;
        }

        final docRef = _firestore.collection('videos').doc(videoId);
        batch.update(docRef, {
          ...updateData,
          'updatedAt': FieldValue.serverTimestamp(),
        });

        results[videoId] = true;
        validUpdates++;
      }

      if (validUpdates > 0) {
        await batch.commit();
      }

      print('[VideoMetadataService] ✅ Batch update completed');
      print('  - Successful updates: $validUpdates');
      print('  - Failed updates: ${updates.length - validUpdates}');

      return results;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return Map.fromIterables(
        updates.keys,
        List.filled(updates.length, false),
      );
    }
  }

  Future<bool> deleteVideoMetadata(String videoId) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return false;
      }

      print('[VideoMetadataService] 🗑️ Deleting video metadata...');
      print('  - Video ID: $videoId');

      await _firestore
          .collection('videos')
          .doc(videoId)
          .delete();

      print('[VideoMetadataService] ✅ Metadata deleted successfully');
      return true;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return false;
    }
  }

  Future<Map<String, bool>> deleteVideoMetadataBatch(List<String> videoIds) async {
    try {
      final user = _auth.currentUser;
      if (!_validateUser(user)) {
        return Map.fromIterables(
          videoIds,
          List.filled(videoIds.length, false),
        );
      }

      print('[VideoMetadataService] 🗑️ Deleting batch metadata...');
      print('  - Batch size: ${videoIds.length}');

      final results = <String, bool>{};
      final batch = _firestore.batch();

      for (final videoId in videoIds) {
        final docRef = _firestore.collection('videos').doc(videoId);
        batch.delete(docRef);
        results[videoId] = true;
      }

      await batch.commit();

      print('[VideoMetadataService] ✅ Batch deletion completed');
      print('  - Deleted: ${results.length}');

      return results;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return Map.fromIterables(
        videoIds,
        List.filled(videoIds.length, false),
      );
    }
  }

  Stream<QuerySnapshot> getUserVideos({
    int limit = 10,
    DocumentSnapshot? startAfter,
    String? status,
  }) {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User must be logged in to access videos');
      }

      print('[VideoMetadataService] 📺 Streaming user videos...');
      print('  - User ID: ${user.uid}');
      print('  - Limit: $limit');
      print('  - Status filter: $status');

      var query = _firestore
          .collection('videos')
          .where('userId', isEqualTo: user.uid)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      return query.snapshots();
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      rethrow;
    }
  }

  Map<String, dynamic> _createMetadata({
    required String userId,
    required String videoUrl,
    required String thumbnailUrl,
    required String title,
    required String description,
    required int duration,
    required int fileSize,
    Map<String, dynamic>? additionalMetadata,
  }) {
    return {
      'userId': userId,
      'videoUrl': videoUrl,
      'thumbnailUrl': thumbnailUrl,
      'title': title,
      'description': description,
      'duration': duration,
      'fileSize': fileSize,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'views': 0,
      'likes': 0,
      'status': 'active',
      ...?additionalMetadata,
    };
  }

  bool _validateMetadata({
    required String title,
    required String description,
    required int duration,
    required int fileSize,
    required String videoUrl,
    required String thumbnailUrl,
  }) {
    return _validateTitle(title) &&
           _validateDescription(description) &&
           _validateDuration(duration) &&
           _validateFileSize(fileSize) &&
           _validateUrl(videoUrl) &&
           _validateUrl(thumbnailUrl);
  }

  bool _validateUpdateData(Map<String, dynamic> updates) {
    if (updates.containsKey('title') && !_validateTitle(updates['title'])) return false;
    if (updates.containsKey('description') && !_validateDescription(updates['description'])) return false;
    if (updates.containsKey('duration') && !_validateDuration(updates['duration'])) return false;
    if (updates.containsKey('fileSize') && !_validateFileSize(updates['fileSize'])) return false;
    if (updates.containsKey('videoUrl') && !_validateUrl(updates['videoUrl'])) return false;
    if (updates.containsKey('thumbnailUrl') && !_validateUrl(updates['thumbnailUrl'])) return false;
    return true;
  }

  bool _validateTitle(String title) {
    if (title.isEmpty || title.length > maxTitleLength) {
      print('[VideoMetadataService] ❌ Invalid title length: ${title.length}');
      print('  - Maximum allowed: $maxTitleLength');
      return false;
    }
    return true;
  }

  bool _validateDescription(String description) {
    if (description.length > maxDescriptionLength) {
      print('[VideoMetadataService] ❌ Invalid description length: ${description.length}');
      print('  - Maximum allowed: $maxDescriptionLength');
      return false;
    }
    return true;
  }

  bool _validateDuration(int duration) {
    if (duration <= 0) {
      print('[VideoMetadataService] ❌ Invalid duration: $duration');
      return false;
    }
    return true;
  }

  bool _validateFileSize(int fileSize) {
    if (fileSize <= 0) {
      print('[VideoMetadataService] ❌ Invalid file size: $fileSize');
      return false;
    }
    return true;
  }

  bool _validateUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute;
    } catch (e) {
      print('[VideoMetadataService] ❌ Invalid URL: $url');
      return false;
    }
  }

  bool _validateUser(User? user) {
    print('[VideoMetadataService] 🔑 Checking authentication:');
    print('  - User authenticated: ${user != null}');
    print('  - User ID: ${user?.uid}');
    print('  - Email verified: ${user?.emailVerified}');
    print('  - Provider ID: ${user?.providerData.map((e) => e.providerId).join(", ")}');
    
    if (user == null) {
      print('[VideoMetadataService] ❌ User must be logged in to access metadata');
      return false;
    }
    return true;
  }

  void _logError(dynamic error, StackTrace stackTrace) {
    print('[VideoMetadataService] ❌ Error in metadata operation:');
    print('  - Error: $error');
    print('  - Stack trace: $stackTrace');
  }
} 