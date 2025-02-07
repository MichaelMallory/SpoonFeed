#!/bin/bash

echo "Starting Android emulator..."
flutter emulators --launch Medium_Phone_API_35 &

# Wait for emulator to fully start (30 seconds)
echo "Waiting for emulator to start..."
sleep 30

echo "Building and installing the app..."
cd android && ./gradlew installDebug && cd ..

echo "Running the app..."
flutter run --use-application-binary=android/app/build/outputs/apk/debug/app-debug.apk 