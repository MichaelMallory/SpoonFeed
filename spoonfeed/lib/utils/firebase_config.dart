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
      const String localhost = 'localhost';
      
      // Only use emulators in debug mode
      if (kDebugMode) {
        try {
          await FirebaseAuth.instance.useAuthEmulator(localhost, 9099);
          FirebaseFirestore.instance.useFirestoreEmulator(localhost, 8080);
          await FirebaseStorage.instance.useStorageEmulator(localhost, 9199);
          
          _useEmulator = true;
          _logger.i('Firebase emulators configured successfully');
        } catch (e) {
          _logger.w('Failed to configure emulators, falling back to production: $e');
          _useEmulator = false;
        }
      } else {
        _logger.i('Using production Firebase instance (not in debug mode)');
      }
    } catch (e) {
      _logger.e('Error in Firebase configuration: $e');
      rethrow; // Propagate the error to handle it in the app
    }
  }

  static bool get isUsingEmulator => _useEmulator;
} 