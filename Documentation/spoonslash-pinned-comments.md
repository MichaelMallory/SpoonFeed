# SpoonSlash Pinned Comments Feature

## Implementation Checklist

### Database Changes
- [x] Add `highestGameScore` and `pinnedCommentId` fields to video documents
  - Added to VideoModel with proper null handling
  - Integrated into fromFirestore/toMap/copyWith methods
- [x] Add `gameScore`, `wasPinned`, `isPinned` fields to comment documents
  - Added to CommentModel with appropriate defaults
  - Full integration in model methods
- [x] Create Firestore indexes for new fields
  - Added composite index for videoId + isPinned + createdAt
  - Supports chronological ordering with pinned priority
- [x] Update security rules to handle pinned comment operations
  - Added validation for pinned comment fields
  - Added rules for high score updates
  - Protected pinned status modifications

### Game Service (`game_service.dart`)
- [x] Add current video context tracking
  - Added `currentVideoId`, `currentVideoHighScore`, and `currentVideo` fields
  - Added `setCurrentVideo` method to update context
  - Added getters for video context fields
- [x] Add method to update current video on swipe
  - Integrated with FeedScreen's `onPageChanged`
  - Added initial video context setting
- [x] Modify score comparison to use current video's high score
  - Added video high score tracking in GameService
  - Added transaction-based high score updates
  - Added local state management for video context
- [x] Add method to validate and update video high scores
  - Added `_updateVideoHighScore` method with transaction support
  - Added error handling and logging
  - Added local state updates
- [x] Connect game end state to comment creation flow
  - [x] Add method to create pinned comment
  - [x] Add method to unpin previous comment
  - [x] Add transaction support for comment state changes
  - [x] Add error handling for comment operations

### Comment System
- [x] Modify comment model to include new fields
  - [x] Added fields to model class
  - [x] Add methods for pinned state transitions
  - [x] Add validation methods
- [x] Add pinned comment management methods
  - [x] Add method to pin comment
  - [x] Add method to unpin comment
  - [x] Add method to handle chronological reordering
  - [x] Add transaction support for state changes
- [x] Add comment retrieval and sorting methods
  - [x] Add method to get comments excluding pinned
  - [x] Add method to stream pinned comment
  - [x] Add method to get chronologically sorted comments
- [x] Add comment validation and utilities
  - [x] Add reusable comment validation
  - [x] Add comment text sanitization
  - [x] Add character limit validation
- [x] Implement pinned/unpinned transition logic
  - [x] Add transition state management
  - [x] Add animation controllers
  - [x] Add position calculation logic

### UI Updates
#### Comments Sheet (`comments_sheet.dart`)
- [x] Add pinned comment section at top
  - [x] Create pinned comment component
  - [x] Add high score display
  - [x] Add visual distinction for pinned state
- [x] Modify comment list to exclude pinned comment from main feed
  - [x] Update comment query to filter pinned
  - [x] Add proper ordering by timestamp
  - [x] Handle empty states
- [x] Add visual styling for pinned comments
  - [x] Add highlight/badge for high score
  - [x] Add transition animations
  - [x] Add proper spacing and layout
- [x] Implement smooth transitions for pinned status changes
  - [x] Add enter/exit animations
  - [x] Handle position changes smoothly
  - [x] Add loading states

#### Game Widget (`spoon_slash_game_widget.dart`)
- [x] Add high score achievement dialog
  - [x] Added dialog with score display
  - [x] Added pinned comment notification
  - [x] Added state management to prevent dialog spam
  - [x] Add comment entry form to dialog
  - [x] Add comment validation
  - [x] Add error handling for comment creation
- [x] Create comment entry UI for high scores
  - [x] Design comment entry form
  - [x] Add character limit validation
  - [x] Add submit button with loading state
  - [x] Add error handling and feedback
- [x] Connect game end state to comment creation
  - [x] Integrate with GameService comment methods
  - [x] Handle successful comment creation
  - [x] Handle failed comment creation
  - [x] Add loading states during comment creation
- [x] Handle video context changes during gameplay
  - Added GameService integration
  - Added current video tracking
  - Added high score comparison logic

#### Feed Screen (`feed_screen.dart`)
- [x] Update video swipe logic to notify game service
  - Added GameService context updates in `onPageChanged`
  - Added initial video context setting
  - Added Provider integration
- [x] Ensure game overlay persists during video transitions
  - Maintained game state during swipes
  - Added proper video context tracking
- [x] Maintain game state during video swipes
  - Added state persistence in GameService
  - Added proper cleanup and initialization

### Testing Requirements
- [ ] Unit tests for score comparison
- [ ] Unit tests for comment transitions
- [ ] Integration tests for game-comment flow
- [ ] Integration tests for video transitions
- [ ] UI tests for comment display
- [ ] Performance tests for comment reordering

## Overview
A gamification feature that allows users to compete for the top comment spot on videos by achieving the highest SpoonSlash game score while watching that video.

## Core Concept
- Each video has exactly one possible pinned comment slot
- The pinned comment displays both:
  - The user's comment text
  - Their SpoonSlash high score achieved while watching that video
- Pinned status is dynamic and can change when a higher score is achieved
- Score is always compared against the currently visible video's high score, even if video changes during gameplay

## Behavior Specifications

### Video Context
- Game score applies to the currently visible video when the game ends
- If user swipes to different videos during gameplay, the final score will be compared to the last viewed video's high score
- No need to display current video's high score during gameplay since video context can change

### Comment System
- A user can have multiple pinned comments across different videos
- Each video can only have one pinned comment at a time
- When a comment loses pinned status:
  - It returns to the regular comment feed
  - Appears in its original chronological position
  - `wasPinned` field tracks its history
- Regular comments are sorted by timestamp
- No cooldown between high score attempts

### Game & Video Interaction
- Video continues playing during gameplay (no auto-pause)
- Game overlay appears in designated area
- Video swipes remain active during gameplay

### High Score Achievement
- When high score is achieved:
  - User must enter comment immediately as part of game over process
  - Comment follows standard character limits
  - No special formatting, but visually distinguished from regular comments
  - Comment becomes pinned immediately
  - Previous pinned comment (if exists) returns to regular feed

## Data Model Changes

### Video Document
```firestore
{
  // ... existing fields ...
  highestGameScore: number,
  pinnedCommentId: string | null  // reference to current pinned comment
}
```

### Comment Document
```firestore
{
  // ... existing fields ...
  gameScore: number | null,  // only populated for comments that were/are pinned
  wasPinned: boolean,        // historical tracking
  isPinned: boolean,         // current status
  videoId: string,          // reference to parent video
  timestamp: timestamp      // for chronological sorting when unpinned
}
```

## User Flows

### Viewing Experience
1. User opens/swipes to a video
2. If exists, pinned comment appears at top of comment section
3. Regular comments appear below in chronological order
4. Game toggle button is visible

### Gaming Experience
1. User activates SpoonSlash game while video plays
2. Video continues playing and can be swiped
3. Game tracks score as normal
4. Score will be compared against currently visible video's high score

### High Score Achievement
1. When game ends, system compares score with current video's high score
2. If higher:
   - User is immediately prompted to create a comment
   - Comment entry is required to claim high score
   - Previous pinned comment (if exists) returns to chronological feed position
   - New comment becomes pinned with the new high score
3. If lower:
   - Normal game end experience
   - Option to post regular comment

## Implementation Plan

### 1. Database Updates
- Modify Firestore schema
- Create necessary indexes
- Update security rules
- Ensure proper video-comment relationships

### 2. Backend Logic
- Create pinned comment management methods
- Implement per-video high score tracking
- Handle pinned comment transitions
- Track current video context for score comparison

### 3. Game Service Updates
- Track current video context
- Update video context on swipes
- Compare scores against current video at game end
- Handle video transitions during gameplay

### 4. UI Components
- Design pinned comment visual distinction
- Create high score comment entry dialog
- Update comment list for pinned/unpinned transitions
- Ensure smooth chronological reordering
- Handle video context changes

### 5. Comment System Updates
- Maintain chronological order for regular comments
- Handle pinned/unpinned transitions
- Update comment rendering for visual distinction
- Manage comment position changes

## Technical Considerations

### Concurrency
- Handle multiple simultaneous players
- Ensure accurate high score tracking
- Handle race conditions in updates

### Performance
- Efficient comment reordering
- Smooth state transitions
- Optimize video playback with game

### Data Integrity
- Validate game scores
- Prevent manipulation
- Track comment timestamps accurately

### User Experience
- Clear high score feedback
- Smooth comment transitions
- Intuitive game activation
- Clear pinned comment distinction

## Testing Plan

### Unit Tests
- Score comparison logic
- Comment state transitions
- Video context management

### Integration Tests
- Game-comment interaction
- Video playback with game
- High score achievement flow
- Video transition handling

### User Testing
- Comment section usability
- Game activation experience
- High score achievement flow
- Mobile compatibility
- Video transition experience 