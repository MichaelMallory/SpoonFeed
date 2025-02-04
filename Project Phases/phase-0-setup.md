# Phase 0: Project Setup & Environment Configuration

## Introduction
This document outlines the initial setup and configuration required to get the SpoonFeed project up and running. It is aimed particularly at developers who are new to building applications. Follow this detailed checklist to install dependencies, configure development tools, and set up your environment properly before moving on to feature development. 

## Progress Tracking
### Completed Steps:
#### System Requirements & Installation
- ✅ Installed development tools and dependencies (git, curl, etc.)
- ✅ Installed Node.js v18.19.1 and npm 9.2.0
- ✅ Installed Flutter SDK
- ✅ Created initial Flutter project structure with `flutter create`

#### Firebase Setup
- ✅ Installed Firebase CLI
- ✅ Logged into Firebase (`firebase login`)
- ✅ Created Firebase project (spoonfeed-78597)
- ✅ Set up Firestore database in Firebase Console
- ✅ Initialized Firebase in project with:
  - Firestore (with security rules and indexes)
  - Cloud Functions (with TypeScript)
  - Hosting (with public directory)
  - Storage (with security rules)
  - Emulators for local development
- ✅ Set up Flutter-Firebase integration
- ✅ Configure Firebase Authentication
- ✅ Set up proper security rules for Firestore and Storage
- ✅ Test Firebase Emulators

### Next Steps:
- [ ] Configure CI/CD (optional at this stage)

## Objectives
- Install and configure all necessary development tools and dependencies.
- Set up the development environment for both frontend (Flutter) and backend (Firebase, Cloud Functions).
- Verify the configuration with initial testing and troubleshooting.

## Checklist

### 1. System Requirements & Installation
- [Frontend] Install the Flutter SDK. Follow the instructions at [Flutter Installation](https://flutter.dev/docs/get-started/install).
- [Frontend] Install an IDE such as Visual Studio Code or Android Studio for Flutter development.
- [Backend] Install Node.js (preferably the latest LTS version) to support Firebase Cloud Functions development.
- [Backend] Install the Firebase CLI globally using npm:
  ```bash
  npm install -g firebase-tools
  ```
- [Frontend] Run `flutter doctor` to verify that your environment is correctly set up.

### 2. Clone Repository & Setup Local Environment
- [Frontend/General] Clone the project repository from GitHub:
  ```bash
  git clone <repository-url>
  ```
- [Frontend] Open the repository in your preferred IDE (e.g., VS Code, Android Studio).
- [Frontend] Run `flutter pub get` in the project directory to install all Flutter dependencies.

### 3. Firebase Project Setup
- [Backend] Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
- [Backend] Configure Firebase services such as Authentication, Firestore, and Cloud Storage as outlined in [Tech Stack](tech-stack.md) and [Tech Stack Rules](tech-stack-rules.md).
- [Backend] Download the `google-services.json` file (for Android) and place it in the appropriate directory as instructed by the Firebase setup guide.
- [Backend] Optionally, set up the Firebase Emulator Suite for local testing of authentication, Firestore, and Cloud Functions.

### 4. Custom Project Configuration
- [General] Review the [Codebase Best Practices](codebase-best-practices.md) document to understand the file structure and coding conventions.
- [General] Familiarize yourself with the project's overall architecture and technology stack by reviewing the [Project Overview](project-overview.md), [Cooking Niche](cooking-niche.md), and [User Flow](user-flow.md) documents.

### 5. Initial Testing & Running the Application
- [Frontend] Run the application using the command:
  ```bash
  flutter run
  ```
- [Frontend] Verify that the onboarding screens appear as expected (see [Phase 1: Onboarding & Authentication](phase-01-onboarding-and-auth.md)).
- [Backend] Test Firebase authentication flows using the Firebase Emulator to ensure that users can register and log in successfully.

### 6. Development Tools & CI/CD Setup (Optional at this Stage)
- [General] Optionally, set up GitHub Actions as described in [Phase 6: Deployment, Continuous Integration & Monitoring](phase-06-deployment-and-ci.md) for automated testing and deployment workflows.
- [Backend] Ensure logging and monitoring via Firebase Analytics and Crashlytics are configured for later stages.

### 7. References & Further Reading
- [Phase 1: Onboarding & Authentication](phase-01-onboarding-and-auth.md)
- [Phase 2: Video Upload & Feed](phase-02-video-upload-and-feed.md)
- [Phase 3: In-App Video Editing](phase-03-in-app-editing.md)
- [Phase 4: AI-Enhanced Features Integration](phase-04-ai-enhanced-features.md)
- [Phase 5: Content Sharing, Engagement & Analytics](phase-05-content-sharing-and-engagement.md)
- [Phase 6: Deployment, Continuous Integration & Monitoring](phase-06-deployment-and-ci.md)
- [Project Overview](project-overview.md)
- [Cooking Niche](cooking-niche.md)
- [User Flow](user-flow.md)
- [Tech Stack](tech-stack.md)
- [Tech Stack Rules](tech-stack-rules.md)
- [UI Rules](ui-rules.md)
- [Theme Rules](theme-rules.md)
- [Codebase Best Practices](codebase-best-practices.md)

### 8. Troubleshooting & Assistance
- As a beginner, you may encounter issues during setup. Please document any errors and check the official documentation or community forums for help.
- Feel free to reach out for further assistance if you need help with any of these setup steps.

## Conclusion
Completing this setup checklist properly will ensure a smooth start for further development of the SpoonFeed application. Keep this document handy as a reference throughout your development process. 