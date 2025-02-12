# Voice Control Implementation Guide

## Pre-Implementation Requirements
- [x] Review and understand [voice-controlled-video-navigation.md](../features/voice-controlled-video-navigation.md)
- [x] Ensure access to Whisper API and Firebase services
  - Successfully tested API key access through Firebase Functions
  - Confirmed access to whisper-1 model via test function
- [ ] Verify Flutter environment is set up correctly
- [ ] Review existing Cook Mode implementation
- [x] Review existing gesture control implementation
  - Existing functionality includes pause/play and reverse seeking (0-10 seconds)
  - Implementation available in gesture_recognition_service.dart
  - Already integrated with video player controls

## 1. Initial Setup & Configuration

### 1.1 Development Environment
- [x] Set up Whisper API access
  - [x] Create OpenAI account if needed
  - [x] Generate and secure API keys
  - [x] Set up environment variables for API keys
    - Successfully configured as Firebase secret
    - Verified access in test function
- [~] Configure Firebase project
  - [x] Enable necessary Firebase services
  - [x] Set up Cloud Functions environment
    - Configured Node.js 20 runtime
    - Set up basic TypeScript environment
    - Added OpenAI npm package
    - Created and tested processVoiceCommand function
    - Implemented audio processing pipeline
  - [ ] Configure Firestore indexes
  - [ ] Set up full production environment
- [~] Update Flutter dependencies
  - [x] Add audio capture packages (record: ^5.0.4)
  - [x] Add Firebase Functions package (cloud_functions: ^4.6.5)
  - [ ] Update remaining Firebase packages if needed

### 1.2 Project Structure
- [~] Create new directories and initial files:
  ```
  functions/
  ├── src/
  │   └── index.ts         # Implemented voice processing function
  ├── package.json         # Added OpenAI and Firebase dependencies
  └── tsconfig.json        # Basic TypeScript configuration
  ```
- [~] Create Flutter directories:
  ```
  lib/
  ├── services/
  │   ├── whisper_service.dart
  │   ├── voice_command_service.dart     # Implemented
  │   └── transcript_service.dart
  ├── models/
  │   ├── video_transcript.dart
  │   └── voice_command.dart             # Implemented
  ├── providers/
  │   └── voice_control_provider.dart    # Basic implementation done
  └── components/
      └── cook_mode/
          ├── voice_control_overlay.dart
          └── voice_feedback_widget.dart
  ```

## 2. Backend Implementation

### 2.1 Video Transcription Service
- [x] Create Cloud Functions structure
  - [x] Set up basic TypeScript environment
  - [x] Configure basic deployment scripts
  - [x] Create test functions for OpenAI connectivity
    - [x] Successfully integrated OpenAI API with secret key
    - [x] Implemented proper error handling and validation
  - [x] Successfully migrated to Firebase Functions v2
    - [x] Configured optimal memory (2GiB) and timeout (540s)
    - [x] Set up maxInstances (10) for cost control
    - [x] Enabled automatic retries for reliability
    - [x] Deployed with proper service account configuration
  - [x] Implement audio processing pipeline
    - [x] Video download and temporary storage
    - [x] FFmpeg audio extraction (16kHz WAV)
    - [x] Whisper API integration with word-level timestamps
  - [x] Set up proper error handling
    - [x] Added comprehensive error catching
    - [x] Added error state in Firestore
    - [x] Added error timestamps and metadata
  - [x] Add comprehensive logging
    - [x] Added emoji-based progress logging
    - [x] Added FFmpeg progress tracking
    - [x] Added detailed validation warnings
  - [~] Configure proper security rules (Nice-to-have: Can be added before production)
- [x] Implement video processing function
  - [x] Create video download handler with signed URLs
  - [x] Implement audio extraction with proper settings
  - [x] Set up Whisper API integration with word timestamps
  - [x] Add automatic trigger on video upload
- [x] Create transcript storage service
  - [x] Design Firestore schema with word-level timing
  - [x] Implement CRUD operations
  - [x] Add processing status tracking
  - [x] Add detailed metadata (word count, segment count)
  - [~] Add indexing for efficient queries (Nice-to-have: For performance optimization)

### 2.2 Voice Command Processing
- [~] Implement audio capture service
  - [x] Set up audio recording (using record package)
  - [x] Configure audio format settings (16kHz WAV)
  - [x] Add noise reduction/filtering (implemented via silence detection)
  - [x] Add wake word detection ("Chef" using Porcupine)
  - [x] Configure recording timeouts:
    - 1.5s silence detection
    - 10s maximum duration
    - Amplitude monitoring (-50dB threshold)
- [~] Create command transcription service
  - [x] Implement Whisper API integration via Firebase Function
  - [x] Add basic error handling and logging
  - [x] Set up retry logic
  - [x] Add detailed emoji logging for debugging
  - [ ] Add comprehensive error recovery (Nice-to-have: Basic error handling exists)
- [~] Build command parsing system
  - [x] Implement wake word detection with Porcupine
  - [x] Create command intent parser
    - [x] Define core command intents (play, pause, seek, etc.)
    - [x] Extract timestamps and context from natural language
    - [x] Map transcribed text to video control actions
  - [~] Implement context-aware command processing
    - [x] Track video state (playing, paused, current position)
    - [x] Handle relative time references ("go back a bit")
    - [ ] Support content-based navigation ("show me the onions part")
  - [ ] Implement hybrid command parsing approach (Nice-to-have: For advanced queries)
    - [ ] Enhance basic pattern matcher
      - [ ] Add more command variations
      - [ ] Improve time parsing
      - [ ] Add cooking-specific terms
    - [ ] Add LLM integration for complex queries
      - [ ] Set up OpenAI GPT integration
      - [ ] Create prompt template for cooking queries
      - [ ] Implement context injection (timestamp, transcript)
      - [ ] Add response parsing
    - [ ] Create command router
      - [ ] Implement command complexity detection
      - [ ] Add performance monitoring
      - [ ] Create fallback mechanisms
    - [ ] Add query caching
      - [ ] Cache common queries
      - [ ] Store successful LLM responses
      - [ ] Implement cache invalidation

## 3. Frontend Implementation

### 3.1 Cook Mode Enhancement
- [~] Update Cook Mode provider
  - [x] Add voice control state management
  - [x] Add service initialization
  - [ ] Implement settings persistence (Nice-to-have: Can use defaults initially)
  - [ ] Create voice/gesture toggle logic
- [ ] Create voice control overlay
  - [ ] Design activation UI
  - [ ] Add status indicators for:
    - Wake word listening
    - Command recording
    - Processing state
    - Error feedback
  - [ ] Implement feedback animations (Nice-to-have: Basic text feedback is sufficient)

### 3.2 Video Player Integration
- [~] Enhance video player
  - [x] Add basic seek command handler
  - [ ] Implement advanced command parsing (Nice-to-have: Basic commands work)
  - [ ] Add visual feedback for seeks (Nice-to-have: Basic seeking works)
  - [ ] Ensure compatibility with existing gesture control system
  - [ ] Implement priority/interrupt handling between voice and gesture controls (Nice-to-have: Can be sequential initially)
- [ ] Create transcript navigation
  - [ ] Implement timestamp matching
  - [ ] Add seek preview (Nice-to-have: Direct seeking works)
  - [ ] Create error handling UI

## 4. Testing & Validation

### 4.1 Unit Tests (Nice-to-have: Manual testing sufficient for MVP)
- [ ] Backend services
  - [ ] Test transcription service
  - [ ] Test command processing
  - [ ] Test storage operations
- [ ] Frontend components
  - [ ] Test UI components
  - [ ] Test state management
  - [ ] Test video player integration

### 4.2 Integration Tests
- [ ] End-to-end flow testing
  - [ ] Test video upload to transcription
  - [ ] Test voice command to seek
  - [ ] Test error scenarios
- [ ] Performance testing (Nice-to-have: Can be done post-MVP)
  - [ ] Measure response times
  - [ ] Test under load
  - [ ] Verify resource usage

### 4.3 User Testing (Nice-to-have: Can be done post-MVP)
- [ ] Internal testing
  - [ ] Team testing phase
  - [ ] Bug tracking setup
  - [ ] Performance monitoring
- [ ] Beta testing
  - [ ] Select test group
  - [ ] Collect feedback
  - [ ] Track usage metrics

## 5. Documentation & Deployment

### 5.1 Technical Documentation
- [ ] API documentation
  - [ ] Document Whisper integration
  - [ ] Document Firebase structure
  - [ ] Create API reference
- [ ] Implementation guides
  - [ ] Create setup guide
  - [ ] Document configuration
  - [ ] Add troubleshooting guide

### 5.2 User Documentation
- [ ] Feature documentation
  - [ ] Create user guide
  - [ ] Add tutorial content
  - [ ] Document settings
- [ ] Support documentation
  - [ ] Create FAQ
  - [ ] Add troubleshooting guide
  - [ ] Document known limitations

### 5.3 Deployment
- [ ] Staging deployment
  - [ ] Deploy to test environment
  - [ ] Verify all integrations
  - [ ] Test production config
- [ ] Production deployment
  - [ ] Create rollout plan
  - [ ] Set up monitoring
  - [ ] Configure alerts

## 6. Post-Launch

### 6.1 Monitoring
- [ ] Set up analytics
  - [ ] Track usage metrics
  - [ ] Monitor error rates
  - [ ] Track performance
- [ ] Configure alerts
  - [ ] Set up error alerts
  - [ ] Configure performance alerts
  - [ ] Set up cost monitoring

### 6.2 Optimization
- [ ] Performance optimization
  - [ ] Analyze bottlenecks
  - [ ] Optimize queries
  - [ ] Improve response times
- [ ] Cost optimization
  - [ ] Monitor API usage
  - [ ] Optimize storage
  - [ ] Review resource allocation

## Implementation Decisions

### 1. Voice Input Method
- **Activation Approach**: Continuous listening while Cook Mode is active
  - Automatically starts when Cook Mode is enabled with voice control setting on
  - No manual activation needed (hands-free operation)
  - Video playback automatically pauses when voice input is detected
  
- **Background Noise Handling**:
  - Implement voice activity detection (VAD) with these parameters:
    - Initial detection threshold: -20dB to -25dB (adjustable based on testing)
    - Minimum voice duration: 300ms
    - Noise reduction using Flutter's noise suppression capabilities
  - Add ambient noise calibration on Cook Mode start
  - Include user feedback indicator when voice is detected

### 2. Storage & Retention
- **Transcript Storage**:
  - Retain transcripts permanently while associated video exists
  - Store in Firestore with video reference
  - Implement efficient storage format:
    ```json
    {
      "videoId": "string",
      "segments": [
        {
          "start": number,
          "end": number,
          "text": "string",
          "keywords": ["string"]  // Extracted key terms for faster searching
        }
      ],
      "metadata": {
        "language": "string",
        "lastAccessed": timestamp,
        "version": number
      }
    }
    ```
  - Estimated storage per hour of video: ~100KB-200KB (text only)
  - No backup requirements for demo phase

### 3. Command Processing
- **Command Format**:
  - Keyword activation: "Chef" as wake word
  - Example commands:
    - "Chef, show me the part with the onions"
    - "Chef, go back to where you added salt"
    - "Chef, take me to the mixing step"
  
- **Accuracy & Matching**:
  - Implement multi-stage matching:
    1. First pass: Direct keyword matching
    2. Second pass: Semantic similarity matching
    3. If multiple matches, prefer:
       - Segments with more keyword matches
       - Segments with actions (cutting, mixing, adding)
       - Earlier segments if still ambiguous

- **Hybrid Command Parsing**:
  - Two-tier processing approach:
    1. Basic Pattern Matcher (First Pass)
       - Handles common commands instantly
       - No API calls needed
       - Supports:
         - Play/pause controls
         - Basic seeking (forward/backward)
         - Simple time references
         - Volume controls
    2. LLM Processing (Complex Queries)
       - Handles cooking-specific questions
       - Processes natural language queries
       - Supports:
         - Cooking duration questions
         - Temperature inquiries
         - Ingredient questions
         - Step-specific navigation
  
  - Command Routing Logic:
    1. Try basic pattern matching first
    2. If no match, check for complexity indicators:
       - Question words (how, what, when)
       - Cooking terms (temperature, time, ingredients)
       - Complex phrases
    3. Route complex queries to LLM with context:
       - Current video position
       - Recent transcript
       - Video metadata
    4. Cache successful responses for similar queries
  
  - Performance Targets:
    - Basic commands: < 100ms response
    - Complex queries: < 2s total processing
    - Cache hits: < 200ms response
  
  - Cost Optimization:
    - Only use LLM for complex queries
    - Cache common questions
    - Batch similar queries
    - Monitor API usage

- **Feedback & Fallbacks**:
  - Visual feedback:
    - Blue pulse: Voice detected
    - Green pulse: Command recognized
    - Yellow pulse: Multiple matches (showing first match)
    - Red pulse: Command not understood
    - Purple pulse: Processing complex query
  - Audio feedback:
    - Subtle tone for command recognition
    - Error tone for failed recognition
    - Processing tone for complex queries
  - For multiple matches:
    - Show quick preview thumbnails
    - Allow follow-up refinement ("No, the next one")
  - Fallback mechanisms:
    - Offer manual controls
    - Show related commands
    - Provide help suggestions

### 4. Performance Specifications
- **Response Times**:
  - Voice detection: < 100ms
  - Command recognition: < 1s
  - Video seeking: < 500ms
  - Total response time: < 2s from voice to video seek
  
- **Resource Usage**:
  - Audio sampling: 16kHz, 16-bit mono
  - Memory usage: < 50MB additional for Cook Mode
  - CPU usage: < 10% increase during voice detection
  
- **Initial Scale Target**:
  - Single user per session
  - No concurrent user limits for MVP
  - Monitor API usage for cost optimization

- **Cost Control Measures**:
  - Functions configured with optimal settings:
    - 2GiB memory (balanced for performance/cost)
    - 540s timeout (sufficient for processing)
    - 10 max instances (prevents cost spikes)
  - Automatic retries enabled with safeguards:
    - Idempotent operations
    - Processing state tracking
    - Duplicate prevention
  - Storage optimization:
    - Temporary file cleanup
    - Efficient transcript storage
    - Proper error state handling
  
### Additional Implementation Notes:
1. **Voice Detection Optimization**:
   - Implement adaptive noise threshold based on environment
   - Add manual sensitivity adjustment in settings
   - Cache recent command history for quick corrections

2. **Transcript Processing**:
   - Pre-process transcripts to extract and index key cooking terms
   - Generate timestamps for all identified cooking actions
   - Store common cooking terms in a dedicated lookup table

3. **User Experience**:
   - Add visual timeline markers for key cooking steps
   - Show transcript preview on hover
   - Allow manual transcript correction for improved accuracy

4. **Error Handling**:
   - Implement automatic retry for failed API calls
   - Cache last successful command for quick recovery
   - Provide manual fallback controls

These decisions will be reflected in the implementation tasks above. The implementation guide's task list remains valid, but will be executed with these specific parameters and requirements in mind.

## Open Questions Requiring Answers

1. Voice Input Method:
   - [x] Choose between continuous listening or push-to-talk
     - Decision: Continuous listening while Cook Mode is active
     - No manual activation needed for hands-free operation
   - [x] Define activation mechanism
     - Automatically starts with Cook Mode
     - Video playback pauses when voice input detected
   - [x] Set background noise thresholds
     - Initial detection threshold: -20dB to -25dB
     - Minimum voice duration: 300ms
     - Using Flutter's noise suppression
     - Ambient noise calibration on Cook Mode start

2. Storage Requirements:
   - [x] Define transcript retention period
     - Decision: Permanent retention while associated video exists
   - [x] Set storage limits
     - Estimated ~100KB-200KB per hour of video
     - Text-only storage for transcripts
   - [x] Determine backup requirements
     - No backup requirements for demo phase
     - Using Firestore's built-in redundancy

3. Command Processing:
   - [x] Define supported command formats
     - Using "Chef" as wake word
     - Defined example commands:
       - "Chef, show me the part with the onions"
       - "Chef, go back to where you added salt"
       - "Chef, take me to the mixing step"
   - [x] Set accuracy thresholds
     - Multi-stage matching approach:
       1. Direct keyword matching
       2. Semantic similarity matching
       3. Prioritize segments with more keyword matches
   - [x] Define fallback behaviors
     - Visual feedback system (color-coded pulses)
     - Audio feedback for recognition/errors
     - Manual refinement for multiple matches
     - Preview thumbnails for disambiguation

4. Performance Targets:
   - [x] Set maximum response time
     - Voice detection: < 100ms
     - Command recognition: < 1s
     - Video seeking: < 500ms
     - Total response time: < 2s end-to-end
   - [x] Define concurrent user limits
     - Single user per session for MVP
     - No concurrent user limits initially
   - [x] Set resource usage bounds
     - Audio: 16kHz, 16-bit mono
     - Memory: < 50MB additional for Cook Mode
     - CPU: < 10% increase during voice detection

All key decisions have been made and documented. Implementation can proceed based on these specifications. 

### Current Implementation Details:
- [x] Wake Word Detection:
  - Using Porcupine for local processing
  - Wake word: "Chef"
  - < 100ms response time
  - Environment variable configuration

- [x] Audio Recording:
  - Format: 16kHz WAV (Whisper requirement)
  - Bitrate: 128000
  - Smart recording termination:
    - Silence detection (1.5s of < -50dB)
    - Maximum duration (10s)
    - Manual cancellation support

- [x] Command Processing Pipeline:
  1. Wake word detection (local)
  2. Audio recording with silence detection
  3. Audio to base64 conversion
  4. Firebase Function call to Whisper
  5. Command parsing and execution

- [x] Error Handling & Logging:
  - Detailed emoji logging
  - State management
  - Error propagation
  - Clean temporary file management

### Next Steps:
1. Implement the LLM command parser
2. Create the visual feedback system
3. Integrate with existing gesture control
4. Add settings and persistence
5. Implement comprehensive testing 