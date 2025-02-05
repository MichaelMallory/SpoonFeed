import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';

class FirebaseConfig {
  static final Logger _logger = Logger();
  static bool _useEmulator = false;

  static Future<void> configureEmulators() async {
    try {
      const String localhost = 'localhost';
      const bool shouldUseEmulator = false; // Set to true for local development

      if (shouldUseEmulator) {
        await FirebaseAuth.instance.useAuthEmulator(localhost, 9099);
        FirebaseFirestore.instance.useFirestoreEmulator(localhost, 8080);
        await FirebaseStorage.instance.useStorageEmulator(localhost, 9199);
        
        _useEmulator = true;
        _logger.i('Firebase emulators configured successfully');
      } else {
        _logger.i('Using production Firebase instance');
      }
    } catch (e) {
      _logger.e('Error configuring Firebase emulators: $e');
    }
  }

  static bool get isUsingEmulator => _useEmulator;
} 