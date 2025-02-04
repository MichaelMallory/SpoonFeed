# SpoonFeed: Reimagining TikTok With AI (Cooking Niche)

## Background
TikTok transformed how we view, share, and edit videos online. Not only did they pioneer short-form video, but they also made content creation more accessible to the masses through CapCut. The algorithm they created made "going viral" easier for even the new creator. You were no longer beholden to followers or subscribers - good content could reach the masses solely based on its quality.

But TikTok emerged in a pre-AI world. What if we could reimagine the platform with today's AI capabilities from the ground up? Instead of users spending hours editing videos, writing captions, or finding trending sounds, AI could transform raw ideas into engaging content. Rather than manually searching for content, AI could understand exactly what entertains each user. Today, we're rebuilding TikTok from an AI-first perspective, where intelligent agents enhance every aspect of creation and consumption.

## Project Overview
This two-week project challenges you to rebuild and reimagine TikTok with AI, while leveraging modern AI tools and capabilities throughout the development process.

### Week 1: Rapid Development (Due February 7 by 6 PM CST)
Use AI-first development tools (Cursor, Lovable, v0, Replit, or Windsurf) to rapidly build a functioning TikTok clone. This week focuses on practicing how AI can accelerate the development of enterprise-scale applications. Your goal is to create a solid foundation that you can enhance in Week 2.

### Week 2: AI Innovation (Due February 14 by 6 PM CST)
Transform your clone by integrating AI features that enhance how users create, consume, and interact with content. With a working application as your foundation, you'll explore how AI can revolutionize the social video experience.

## Submission Guidelines
At the end of each week, you'll need to submit the following to the GauntletAI LMS:
- A link to your project's public GitHub repository
- A link to the brainlift you used to learn, understand, and enhance the application with AI
- A 5-minute walkthrough showcasing what you've built (and, where relevant, how you built it)
- A link to a post on X or LinkedIn showcasing what you've built
- A link to the working deployed application

## Week 1: Rapid Development

### Choose Your Primary User
- **Content Creator:** Users who make and share videos
- **Content Consumer:** Users who discover and engage with content

### Specify Your Niche
Narrow your focus to a specific type of user within your chosen category:

**Creator Examples:**
- Fitness Coach sharing workout routines
- Chef demonstrating recipes
- Educator teaching concepts
- Musician sharing performances
- Beauty expert creating tutorials

**Consumer Examples:**
- Fitness enthusiast looking for workouts
- Home cook seeking new recipes
- Student learning new topics
- Music fan discovering new artists
- Beauty enthusiast learning techniques

### Define User Stories
Create detailed user stories for your specific user. For example:

**Fitness Creator Stories:**
- "As a fitness coach, I want to add exercise timestamps to my workout videos"
- "As a fitness coach, I want to tag videos with difficulty levels"
- "As a fitness coach, I want to categorize videos by muscle group"

**Recipe Consumer Stories:**
- "As a home cook, I want to save recipes by cuisine type"
- "As a home cook, I want to filter videos by cooking time"
- "As a home cook, I want to create collections of weeknight dinner ideas"

### Build Vertically
Build complete features for your specific user type. Each feature should work end-to-end before moving to the next.

**For Creator:**
- ✅ Complete video upload → processing → publishing pipeline
- ❌ Partial implementation of comments, likes, AND sharing

**For Consumer:**
- ✅ Complete video feed → view → interaction flow
- ❌ Partial implementation of profile, search, AND notifications

> Remember: A fully functional app for one user type is more valuable than a partial implementation trying to serve both.

### Week 1 Requirements
To pass week 1, you must:
- Build and deploy a working vertical slice
- Pick either creator or consumer
- Pick a niche within your choice
- Identify 6 user stories you are aiming to ship for the niche
- Showcase your functionality in your video and code
- Highlight your path, niche, and user stories in your walkthrough video
- Show working functionality that matches the 6 user stories you picked earlier
- Build a mobile application natively using Kotlin or Swift

## Week 2: AI Innovation

### Features vs. User Stories
An AI Feature is a major capability that solves a user problem. Each feature enables multiple User Stories - specific ways users interact with that feature to achieve their goals.

### Choose Your AI Features
Select 2 AI features that:
- Address real problems for your chosen user type
- Integrate naturally with your Week 1 implementation
- Create significant value for your niche

### Define User Stories
Create at least 6 user stories across your chosen features. For example:

**Creator Example:**
*Feature: SmartEdit*
- "As a creator, I can say 'remove awkward pause' and AI edits out silence"
- "As a creator, I can say 'zoom on product' and AI adds zoom effects"
- "As a creator, I can say 'enhance lighting' and AI adjusts dark scenes"

*Feature: TrendLens*
- "As a creator, I get AI suggestions for optimal video length"
- "As a creator, I receive trending hashtag recommendations"

**Consumer Example:**
*Feature: SmartScan*
- "As a recipe learner, I can ask 'show sauce-making part' and jump there"
- "As a recipe learner, I can search for specific techniques shown"
- "As a recipe learner, I can find moments where ingredients are listed"

*Feature: PersonalLens*
- "As a recipe learner, I get recommendations based on my skill level"
- "As a recipe learner, I see content matched to my learning pace"

### Week 2 Requirements
To pass Week 2, you must:
- Implement 2 substantial AI Features
- Define at least 6 User Stories across your features
- Show working functionality that matches these user stories in your video

## Technical Architecture

### Important Technical Decisions (ITDs)

1. **Firebase Auth**
   - Purpose: Provide secure user authentication and account management
   - Usage:
     - Enable sign-up, login, and session management
     - Support social logins (Google, Facebook, etc.)

2. **Firebase Cloud Storage**
   - Purpose: Store and serve media assets reliably
   - Usage:
     - Manage video file uploads, thumbnails, and other media
     - Integrate with Cloud Functions for media processing

3. **Firestore**
   - Purpose: Primary NoSQL database for real-time data management
   - Usage:
     - Store metadata (video descriptions, timestamps, comments, etc.)
     - Provide real-time data synchronization

4. **Generative AI in Firebase**
   - Purpose: Integrate advanced AI capabilities
   - Usage:
     - Automate content enhancements
     - Enable AI-driven features

5. **Cloud Functions Firebase**
   - Purpose: Implement serverless backend logic
   - Usage:
     - Handle video processing
     - Integrate with external APIs

6. **Cloud Messaging**
   - Purpose: Provide real-time notifications
   - Usage:
     - Send push notifications
     - Enhance user engagement

7. **App Distribution on Firebase**
   - Purpose: Deploy and host the application
   - Usage:
     - Host mobile components
     - Streamline updates

8. **OpenShot Video Editing API**
   - Purpose: Manage video editing
   - Usage:
     - Process video files programmatically
     - Implement editing features

9. **Native Mobile Development**
   - Purpose: Platform-specific mobile application
   - Usage:
     - Choose Kotlin (Android) or Swift (iOS)
     - Integrate Firebase SDKs

## Test2Pass (T2P) Requirements

### Deliverables
1. **Brainlift**
   - Submit a Brainlift highlighting SpikyPOVs for AI feature selection

2. **Walkthrough Video**
   - 3-5 minute screen share
   - Showcase AI features
   - Highlight feature evaluations

3. **GitHub Repository**
   - Submit project code

4. **Deployed Application**
   - Submit working application link

## Project Timeline

| Completion Date | Project Phase | Description |
|----------------|---------------|-------------|
| Feb 5, 2025 | Video Platform MVP | Working platform with basic features |
| Feb 7, 2025 | TikTok Rebuild Complete | Week 1 submission |
| Feb 9, 2025 | Week 1 Resubmission | Progress showcase |
| Feb 10, 2025 | AI Objectives Start | Begin AI implementation |
| Feb 12, 2025 | Week 2 Check-in | Progress review |
| Feb 14, 2025 | AI Features Complete | Final project submission |

## Resources

### Video Editing Integration
- Cloudinary Image and Video Handling - Cloud-based transformation and compression
- OpenShot AWS Marketplace - Your primary video processing API
- AWS API Gateway Documentation - For integrating with OpenShot API
- AWS SDK Documentation - For handling video uploads and API interactions

### Mobile Development
- Firebase App Distribution - Pre-Release your mobile app
- Firebase documentation - Docs for all features
- Flutter Documentation - Official Flutter documentation
- Flutter Video Player - Video playback in Flutter
- Flutter AWS Integration - AWS Amplify Flutter library
- Material Design Components - UI design system for mobile apps
- Flutter State Management - Managing app state in Flutter

### Backend Development
- Firebase Authentication - Manage user login and signup 
- Firebase Cloud Functions - Serverless architecture
- Supabase Documentation - Backend infrastructure
- Supabase Flutter SDK - Flutter integration
- Edge Functions - Serverless compute
- Row Level Security - Data access control

### Development Tools
- Flutter DevTools - Flutter debugging and profiling
- Postman - API testing and documentation
- Firebase Test Lab - Mobile app testing

## Scope and Deliverables

| Deliverable | Description |
|-------------|-------------|
| Video Platform | Working social video platform that enables, at minimum, video upload, basic editing, playback, and social features (likes, comments, shares) with two types of users (creators and viewers) |
| AI Augmentation - Baseline | Platform automatically processes videos for optimization and provides basic AI-assisted editing features |
| AI Augmentation - Stretch | Enhanced AI experience with features like natural language editing, trend analysis, voice commands, or develop your own innovative AI features! |







