import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConfigService {
  static Future<void> initialize() async {
    await dotenv.load(fileName: '.env');
  }

  static String get googleCloudApiKey => dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? '';
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  
  // Firebase config getters
  static String get firebaseIosApiKey => dotenv.env['FIREBASE_IOS_API_KEY'] ?? '';
  static String get firebaseAndroidApiKey => dotenv.env['FIREBASE_ANDROID_API_KEY'] ?? '';
  static String get firebaseBrowserApiKey => dotenv.env['FIREBASE_BROWSER_API_KEY'] ?? '';
  static String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';
  static String get firebaseMessagingSenderId => 
      dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  static String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  static String get firebaseStorageBucket => 
      dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '';
  
  // Client IDs
  static String get firebaseAndroidClientId => 
      dotenv.env['FIREBASE_ANDROID_CLIENT_ID'] ?? '';
  static String get firebaseIosClientId => 
      dotenv.env['FIREBASE_IOS_CLIENT_ID'] ?? '';
  static String get firebaseWebClientId => dotenv.env['FIREBASE_WEB_CLIENT_ID'] ?? '';
  static String get firebaseIosBundleId => 
      dotenv.env['FIREBASE_IOS_BUNDLE_ID'] ?? '';
} 