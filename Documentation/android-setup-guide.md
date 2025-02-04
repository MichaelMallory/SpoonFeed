# Android Setup Guide for SpoonFeed

## Prerequisites
- [ ] Working web implementation of Firebase Auth
- [ ] Android Studio installed
- [ ] Flutter SDK configured for Android development

## Firebase Configuration Steps
1. [ ] Get SHA-1 Debug Certificate:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   - Copy the SHA-1 value from the debug variant

2. [ ] Add Android App to Firebase:
   - [ ] Go to Firebase Console > Project Settings
   - [ ] Add Android App
   - [ ] Use package name from `android/app/build.gradle`
   - [ ] Add SHA-1 fingerprint
   - [ ] Download `google-services.json`

3. [ ] Configure Android Files:
   - [ ] Place `google-services.json` in `android/app/`
   - [ ] Update `android/build.gradle`:
     ```gradle
     buildscript {
         dependencies {
             classpath 'com.google.gms:google-services:4.3.15'
         }
     }
     ```
   - [ ] Update `android/app/build.gradle`:
     ```gradle
     apply plugin: 'com.google.gms.google-services'
     
     android {
         defaultConfig {
             minSdkVersion 21
         }
     }
     ```

## Google Sign-In Configuration
1. [ ] Update Android Manifest:
   - [ ] Add to `android/app/src/main/AndroidManifest.xml`:
     ```xml
     <uses-permission android:name="android.permission.INTERNET"/>
     ```

2. [ ] Configure OAuth Client:
   - [ ] Go to Google Cloud Console > APIs & Services > Credentials
   - [ ] Find the Android OAuth client
   - [ ] Add package name and SHA-1

## Testing Steps
1. [ ] Build and Run:
   ```bash
   flutter run
   ```
   - [ ] Test on Android emulator
   - [ ] Test on physical Android device

2. [ ] Verify Authentication:
   - [ ] Test Google Sign-In
   - [ ] Verify user data in Firebase Console
   - [ ] Check token persistence
   - [ ] Test sign-out functionality

## Common Issues and Solutions
- SHA-1 mismatch: Verify debug vs release SHA-1
- Google Play Services: Ensure emulator has Google Play Services installed
- Version conflicts: Check gradle and google-services plugin versions
- Minimum SDK: Ensure minimum SDK version is 21 or higher

## Additional Resources
- [Firebase Android Setup](https://firebase.google.com/docs/android/setup)
- [Google Sign-In for Android](https://developers.google.com/identity/sign-in/android)
- [Flutter Firebase Auth](https://firebase.flutter.dev/docs/auth/overview)

## Notes
- Keep debug and release SHA-1 fingerprints separate
- Consider setting up different Firebase projects for development and production
- Remember to update ProGuard rules if using code obfuscation 