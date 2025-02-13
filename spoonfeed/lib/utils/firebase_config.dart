import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'package:flutter/foundation.dart';

class FirebaseConfig {
  static final Logger _logger = Logger();
  static bool _useEmulator = false;

  static Future<void> configureEmulators() async {
    try {
      // Use 10.0.2.2 for Android emulator, localhost for other platforms
      const String host = kIsWeb ? 'localhost' : '10.0.2.2';
      
      _logger.i('Configuring Firebase emulators with host: $host');
      _logger.i('Debug mode: ${kDebugMode}');
      
      // Only use emulators in debug mode
      if (kDebugMode) {
        try {
          _logger.i('Configuring Auth emulator...');
          await FirebaseAuth.instance.useAuthEmulator(host, 9099);
          
          _logger.i('Configuring Firestore emulator...');
          FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
          
          _logger.i('Configuring Storage emulator...');
          await FirebaseStorage.instance.useStorageEmulator(host, 9199);
          
          _useEmulator = true;
          _logger.i('✅ All Firebase emulators configured successfully');
          
          // Verify configuration
          final auth = FirebaseAuth.instance;
          _logger.i('Current auth state - isSignedIn: ${auth.currentUser != null}');
          
        } catch (e) {
          _logger.e('❌ Failed to configure emulators: $e');
          _useEmulator = false;
          rethrow;
        }
      } else {
        _logger.i('Using production Firebase instance (not in debug mode)');
      }
    } catch (e) {
      _logger.e('❌ Error in Firebase configuration: $e');
      rethrow;
    }
  }

  static bool get isUsingEmulator => _useEmulator;
} 