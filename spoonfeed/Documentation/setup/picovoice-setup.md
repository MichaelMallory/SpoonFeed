# Picovoice Setup Guide

## Overview
This guide explains how to set up Picovoice wake word detection for the "Chef" wake word in SpoonFeed.

## Steps

### 1. Get Picovoice API Key
1. Go to [Picovoice Console](https://console.picovoice.ai/)
2. Create a free account
3. Create a new access key
4. Copy the access key
5. Paste it in `.env` file:
   ```
   PICOVOICE_API_KEY=your_key_here
   ```

### 2. Create Wake Word Model
1. Go to [Picovoice Console](https://console.picovoice.ai/)
2. Navigate to "Wake Word" section
3. Click "Create Wake Word"
4. Enter "Chef" as the wake word
5. Select "Android" platform
6. Download the generated .ppn file
7. Place it in `assets/keywords/chef_android.ppn`

### 3. Create Context Model (Optional)
1. Go to [Picovoice Console](https://console.picovoice.ai/)
2. Navigate to "Speech-to-Intent" section
3. Create a new context for cooking commands
4. Download the .rhn file
5. Place it in `assets/contexts/chef_android.rhn`

### 4. Update Android Permissions
The following permissions are required and already added to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

### 5. Testing
1. Build and run the app
2. Enable voice control
3. Say "Chef" to trigger wake word detection
4. Watch the logs for:
   - "Wake word detection initialized successfully"
   - "Wake word 'Chef' detected!"

### Troubleshooting
1. If wake word detection fails:
   - Check API key in .env
   - Verify model files are in correct locations
   - Check Android permissions
   - Look for error messages in the logs

2. If audio levels are too low:
   - Check microphone permissions
   - Verify microphone isn't being used by another app
   - Check device audio settings 