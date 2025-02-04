import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // For development purposes only - replace these with your actual Firebase configuration
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAgUhHU8wSJgO5MVNy95tMT07NEjzMOfz0',
    authDomain: 'react-native-market-30349.firebaseapp.com',
    projectId: 'react-native-market-30349',
    storageBucket: 'react-native-market-30349.appspot.com',
    messagingSenderId: '878215933200',
    appId: '1:878215933200:web:a0830da0b3f1daa1c79304',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAgUhHU8wSJgO5MVNy95tMT07NEjzMOfz0',
    appId: '1:878215933200:android:a0830da0b3f1daa1c79304',
    messagingSenderId: '878215933200',
    projectId: 'react-native-market-30349',
    storageBucket: 'react-native-market-30349.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAgUhHU8wSJgO5MVNy95tMT07NEjzMOfz0',
    appId: '1:878215933200:ios:a0830da0b3f1daa1c79304',
    messagingSenderId: '878215933200',
    projectId: 'react-native-market-30349',
    storageBucket: 'react-native-market-30349.appspot.com',
    iosClientId: '878215933200-b3p5j5pbf6egtlj5gj2s0dl2mp0is103.apps.googleusercontent.com',
    iosBundleId: 'com.example.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAgUhHU8wSJgO5MVNy95tMT07NEjzMOfz0',
    appId: '1:878215933200:macos:a0830da0b3f1daa1c79304',
    messagingSenderId: '878215933200',
    projectId: 'react-native-market-30349',
    storageBucket: 'react-native-market-30349.appspot.com',
    iosClientId: '878215933200-b3p5j5pbf6egtlj5gj2s0dl2mp0is103.apps.googleusercontent.com',
    iosBundleId: 'com.example.app',
  );
} 