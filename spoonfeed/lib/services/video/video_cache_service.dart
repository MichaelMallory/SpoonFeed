import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

class VideoCacheService {
  // Singleton instance
  static final VideoCacheService _instance = VideoCacheService._internal();
  factory VideoCacheService() => _instance;
  VideoCacheService._internal() {
    _initializeCache();
  }

  static const int _maxCacheSize = 500 * 1024 * 1024; // 500MB
  static const int _minCacheSize = 200 * 1024 * 1024; // 200MB
  static const String _cacheDirName = 'video_cache';
  static const String _cacheInfoKey = 'video_cache_info';
  static const Duration _maxCacheAge = Duration(days: 7);

  // Cache state
  final Map<String, String> _videoCache = {};
  final Map<String, DateTime> _lastAccessTime = {};
  final Map<String, String> _fileHashes = {};
  int _currentCacheSize = 0;
  bool _isInitialized = false;

  Future<void> _initializeCache() async {
    if (_isInitialized) return;

    try {
      print('[VideoCacheService] 🔄 Initializing cache...');
      
      // Create cache directory if it doesn't exist
      final cacheDir = Directory(await _cacheDir);
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // Restore cache info from persistent storage
      await _restoreCache();

      // Validate cache integrity
      await _validateCacheIntegrity();

      _isInitialized = true;
      print('[VideoCacheService] ✅ Cache initialized successfully');
      _logCacheStats();
    } catch (e, stackTrace) {
      print('[VideoCacheService] ❌ Error initializing cache:');
      print('  - Error: $e');
      print('  - Stack trace: $stackTrace');
    }
  }

  Future<String> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, _cacheDirName);
  }

  Future<String?> getCachedVideoPath(String videoUrl) async {
    try {
      if (kIsWeb) {
        print('[VideoCacheService] Web platform detected, caching not supported');
        return null;
      }

      await _initializeCache();

      final fileName = _generateCacheFileName(videoUrl);
      final cachePath = path.join(await _cacheDir, fileName);
      final cacheFile = File(cachePath);

      print('[VideoCacheService] 🔍 Checking cache...');
      print('  - Video URL: $videoUrl');
      print('  - Cache path: $cachePath');

      if (await cacheFile.exists()) {
        // Validate file integrity
        if (!await _validateFileIntegrity(videoUrl, cacheFile)) {
          print('[VideoCacheService] ❌ Cache file integrity check failed');
          await _removeCachedVideo(videoUrl);
          return null;
        }

        print('[VideoCacheService] ✅ Video found in cache');
        print('  - File size: ${await cacheFile.length()} bytes');
        
        // Update access time
        _lastAccessTime[videoUrl] = DateTime.now();
        await _persistCache();
        
        return cachePath;
      }

      print('[VideoCacheService] ❌ Video not found in cache');
      return null;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return null;
    }
  }

  Future<String?> cacheVideo(String videoUrl, File videoFile) async {
    try {
      if (kIsWeb) {
        print('[VideoCacheService] Web platform detected, caching not supported');
        return null;
      }

      await _initializeCache();

      final fileName = _generateCacheFileName(videoUrl);
      final cachePath = path.join(await _cacheDir, fileName);
      final cacheFile = File(cachePath);

      print('[VideoCacheService] 💾 Caching video...');
      print('  - Video URL: $videoUrl');
      print('  - Cache path: $cachePath');

      // Calculate file hash before copying
      final fileHash = await _calculateFileHash(videoFile);
      
      // Ensure we have enough cache space
      await _ensureCacheSpace(await videoFile.length());

      // Copy file to cache
      await videoFile.copy(cachePath);

      // Verify copied file integrity
      final cachedFileHash = await _calculateFileHash(cacheFile);
      if (fileHash != cachedFileHash) {
        print('[VideoCacheService] ❌ Cache file integrity verification failed');
        await cacheFile.delete();
        return null;
      }

      // Update cache state
      _videoCache[videoUrl] = cachePath;
      _lastAccessTime[videoUrl] = DateTime.now();
      _fileHashes[videoUrl] = fileHash;
      _currentCacheSize += await cacheFile.length();

      // Persist cache info
      await _persistCache();

      print('[VideoCacheService] ✅ Video cached successfully');
      print('  - File size: ${await cacheFile.length()} bytes');
      print('  - File hash: $fileHash');

      return cachePath;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return null;
    }
  }

  Future<bool> clearCache() async {
    try {
      print('[VideoCacheService] 🧹 Clearing cache...');
      
      final cacheDirectory = Directory(await _cacheDir);
      if (await cacheDirectory.exists()) {
        await cacheDirectory.delete(recursive: true);
        await cacheDirectory.create();
        
        // Reset cache state
        _videoCache.clear();
        _lastAccessTime.clear();
        _fileHashes.clear();
        _currentCacheSize = 0;
        
        // Persist empty cache state
        await _persistCache();
        
        print('[VideoCacheService] ✅ Cache cleared successfully');
        return true;
      }
      
      print('[VideoCacheService] Cache directory does not exist');
      return false;
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
      return false;
    }
  }

  Future<void> _ensureCacheSpace(int newFileSize) async {
    try {
      final cacheDirectory = Directory(await _cacheDir);
      if (!await cacheDirectory.exists()) return;

      print('[VideoCacheService] 📊 Checking cache size...');
      print('  - Current cache size: ${_formatSize(_currentCacheSize)}');
      print('  - New file size: ${_formatSize(newFileSize)}');
      print('  - Max cache size: ${_formatSize(_maxCacheSize)}');

      // Remove expired cache entries first
      await _removeExpiredEntries();

      // If still need more space, remove old entries
      if (_currentCacheSize + newFileSize > _maxCacheSize) {
        await _removeOldEntries(newFileSize);
      }

      print('[VideoCacheService] ✅ Cache space ensured');
      _logCacheStats();
    } catch (e, stackTrace) {
      _logError(e, stackTrace);
    }
  }

  Future<void> _removeExpiredEntries() async {
    final now = DateTime.now();
    final expiredUrls = _lastAccessTime.entries
        .where((entry) => now.difference(entry.value) > _maxCacheAge)
        .map((entry) => entry.key)
        .toList();

    for (final url in expiredUrls) {
      await _removeCachedVideo(url);
      print('  - Removed expired: $url');
    }
  }

  Future<void> _removeOldEntries(int requiredSpace) async {
    final entries = _lastAccessTime.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (final entry in entries) {
      if (_currentCacheSize <= _minCacheSize || 
          _currentCacheSize + requiredSpace <= _maxCacheSize) {
        break;
      }
      await _removeCachedVideo(entry.key);
      print('  - Removed old: ${entry.key}');
    }
  }

  Future<void> _removeCachedVideo(String videoUrl) async {
    if (_videoCache.containsKey(videoUrl)) {
      final cachePath = _videoCache[videoUrl]!;
      final file = File(cachePath);
      if (await file.exists()) {
        _currentCacheSize -= await file.length();
        await file.delete();
      }
      _videoCache.remove(videoUrl);
      _lastAccessTime.remove(videoUrl);
      _fileHashes.remove(videoUrl);
      await _persistCache();
    }
  }

  Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheInfo = {
        'videos': _videoCache,
        'accessTimes': _lastAccessTime.map(
          (key, value) => MapEntry(key, value.toIso8601String())
        ),
        'hashes': _fileHashes,
        'size': _currentCacheSize,
      };
      await prefs.setString(_cacheInfoKey, jsonEncode(cacheInfo));
    } catch (e) {
      print('[VideoCacheService] Error persisting cache: $e');
    }
  }

  Future<void> _restoreCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheInfoString = prefs.getString(_cacheInfoKey);
      
      if (cacheInfoString != null) {
        final cacheInfo = jsonDecode(cacheInfoString) as Map<String, dynamic>;
        
        _videoCache.clear();
        _videoCache.addAll(Map<String, String>.from(cacheInfo['videos'] as Map));
        
        _lastAccessTime.clear();
        (cacheInfo['accessTimes'] as Map).forEach((key, value) {
          _lastAccessTime[key as String] = DateTime.parse(value as String);
        });
        
        _fileHashes.clear();
        _fileHashes.addAll(Map<String, String>.from(cacheInfo['hashes'] as Map));
        
        _currentCacheSize = cacheInfo['size'] as int;
      }
    } catch (e) {
      print('[VideoCacheService] Error restoring cache: $e');
      // Reset cache state on error
      _videoCache.clear();
      _lastAccessTime.clear();
      _fileHashes.clear();
      _currentCacheSize = 0;
    }
  }

  Future<void> _validateCacheIntegrity() async {
    print('[VideoCacheService] 🔍 Validating cache integrity...');
    
    final invalidUrls = <String>[];
    
    for (final entry in _videoCache.entries) {
      final file = File(entry.value);
      if (!await file.exists()) {
        invalidUrls.add(entry.key);
        continue;
      }

      if (!await _validateFileIntegrity(entry.key, file)) {
        invalidUrls.add(entry.key);
      }
    }

    // Remove invalid entries
    for (final url in invalidUrls) {
      await _removeCachedVideo(url);
      print('  - Removed invalid: $url');
    }

    // Recalculate total cache size
    _currentCacheSize = 0;
    for (final cachePath in _videoCache.values) {
      final file = File(cachePath);
      if (await file.exists()) {
        _currentCacheSize += await file.length();
      }
    }
  }

  Future<bool> _validateFileIntegrity(String videoUrl, File file) async {
    if (!_fileHashes.containsKey(videoUrl)) {
      return false;
    }

    final storedHash = _fileHashes[videoUrl];
    final currentHash = await _calculateFileHash(file);
    return storedHash == currentHash;
  }

  Future<String> _calculateFileHash(File file) async {
    try {
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (e) {
      print('[VideoCacheService] Error calculating file hash: $e');
      rethrow;
    }
  }

  String _generateCacheFileName(String videoUrl) {
    final urlHash = sha256.convert(utf8.encode(videoUrl)).toString().substring(0, 16);
    return 'video_$urlHash.mp4';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _logCacheStats() {
    print('\n[VideoCacheService] 📊 Cache Statistics:');
    print('  - Total size: ${_formatSize(_currentCacheSize)}');
    print('  - Cached videos: ${_videoCache.length}');
    print('  - Space available: ${_formatSize(_maxCacheSize - _currentCacheSize)}');
    print('  - Utilization: ${(_currentCacheSize / _maxCacheSize * 100).toStringAsFixed(1)}%\n');
  }

  void _logError(dynamic error, StackTrace stackTrace) {
    print('[VideoCacheService] ❌ Error in cache operation:');
    print('  - Error: $error');
    print('  - Stack trace: $stackTrace');
  }
} 