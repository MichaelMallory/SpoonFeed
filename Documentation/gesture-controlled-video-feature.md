# Gesture-Controlled Video Feature

## Overview
This document outlines the implementation plan for adding gesture-based video control to the SpoonFeed app. This feature will allow users to control video playback using hand gestures captured by the device camera, primarily focused on a simple pause/play functionality for hands-free cooking scenarios.

## Technology Stack
- **MediaPipe Hands** - Primary hand tracking and landmark detection
- **Flutter** - UI and video player integration

## Architecture Components

### 1. Camera Module
- Camera activation in "Cook Mode"
- Basic frame capture system
- Camera permission handling
- Resource optimization (frame rate, resolution)

### 2. Gesture Recognition Engine
- MediaPipe Hands integration
- Simple hand presence detection
- Event dispatch system for recognized gestures

### 3. Video Control Interface
- Video player state management
- Single gesture-to-action mapping (pause/play with auto-rewind)
- Minimal visual feedback system
- "Cook Mode" activation widget

## Implementation Considerations

### Performance & Optimization
- Basic resource usage monitoring
- Camera active only during "Cook Mode"
- Device compatibility requirements
- Optimization for kitchen lighting conditions

### User Experience
- Simple "Cook Mode" activation button/widget
- Minimal visual feedback for gesture recognition
- Auto-rewind feature (5 seconds) when resuming from pause
- Designed for flat phone placement with overhead hand motion

### Security & Privacy
- Camera permission handling
- User consent for "Cook Mode"
- Clear camera usage messaging

### Testing Requirements
- Basic functionality testing
- Kitchen environment testing
- Integration testing with video player

## Gesture Definitions
1. **Pause/Play with Auto-Rewind**
   - Simple hand-over-camera detection
   - When resuming play, automatically rewind 5 seconds
   - Single gesture handles both pause and play
   - Designed for food-covered hands during cooking

## Implementation Decisions (Addressing Previous Questions)

### Gesture Implementation
1. ✓ **Gesture Mapping**: Single gesture (hand over camera) for pause/play
   - Simplified approach focusing on most needed function
   - Auto-rewind feature (5 seconds) when resuming play
   - No need for complex gesture recognition

2. ✓ **Confirmation Step**: Not needed
   - Direct action on gesture recognition
   - Immediate feedback through video state change

3. ✓ **Gesture Customization**: Not needed
   - Single, simple gesture approach
   - Focus on reliability over flexibility

### User Experience
4. ✓ **Activation Method**: Explicit "Cook Mode" activation
   - Dedicated button/widget to enter gesture control mode
   - Camera only active during "Cook Mode"
   - User-initiated activation for battery efficiency

5. ✓ **False Positive Handling**: Minimal concern
   - Phone expected to be flat on table
   - Deliberate overhead hand motion required
   - Kitchen environment assumptions

6. ✓ **Visual Feedback**: Minimal
   - Small gesture recognition indicator
   - Primary feedback through video state changes
   - Non-intrusive design

### Technical Implementation
7. ✓ **Flutter Integration**: MediaPipe Hands primary choice
   - Further investigation needed for specific Flutter camera API requirements

8. ✓ **Environmental Handling**: Kitchen-focused
   - Assumption of well-lit kitchen environments
   - No special handling for variable lighting needed

9. ✓ **Calibration**: Not needed
   - Simple gesture recognition
   - Standard kitchen lighting assumptions

### Testing & Quality
- Focus on basic functionality testing
- Kitchen environment testing
- User experience validation
- No complex metrics tracking needed

## Technical Dependencies
- **Flutter Packages**
  - `video_player: ^2.8.1` (existing)
  - `camera: ^0.10.5+9` (for camera access)
  - `google_mlkit_hands: ^0.6.0` (for hand detection)
  - `provider: ^6.1.1` (for state management)

## State Management
### Cook Mode State
- Provider-based state management
- Tracks:
  - Cook Mode active status
  - Camera initialization state
  - Current gesture recognition state
  - Error states

### Integration with Video Player
- Extends existing VideoPlayerController state
- Manages:
  - Auto-rewind buffer
  - Gesture recognition active state
  - Camera controller lifecycle

### State Persistence
- Cook Mode preference persistence
- Per-video settings retention
- Session state management

## Error Handling & Recovery

### Permission Handling
- Camera permission request flow
- Permission denied handling
- Settings redirect for manual permission grant

### Technical Failures
- MediaPipe initialization failures
- Camera access errors
- Memory management issues
- Device compatibility checks

### User Recovery Flows
- Clear error messaging
- Automatic retry logic
- Manual retry options
- Fallback to standard controls

## Integration Points

### VideoPlayerFullscreen Integration
- Extension of existing player controls
- Gesture recognition overlay
- Cook Mode activation widget placement
- Visual feedback integration

### Existing Control Integration
- Coordination with tap-to-pause
- Prevention of control conflicts
- Gesture priority handling

## Next Steps
1. [x] Review and answer open questions
2. [x] Define gesture mapping
3. [ ] Create technical implementation plan
4. [ ] Design "Cook Mode" UI
5. [ ] Implement prototype
6. [ ] Basic functionality testing
7. [ ] Kitchen environment testing
8. [ ] Integration testing with existing video player
9. [ ] Error handling implementation
10. [ ] State management implementation

## References
- [UI Rules](ui-rules.md)
- [Tech Stack Rules](tech-stack-rules.md)
- [Codebase Best Practices](codebase-best-practices.md)

## Kitchen Use Cases

### Messy Hands Scenarios
- Making meatballs or kneading dough with completely covered hands
- Breading station work (wet hand/dry hand technique)
- Working with sticky dough (cinnamon rolls, bread, pastries)
- Handling raw meat while following recipe steps
- Mixing ingredients by hand (meatloaf, cookie dough)

### Timing-Critical Operations
- Monitoring oil temperature for frying
- Candy making and sugar work
- Sauce preparation and reduction
- Tempering chocolate
- Precise cooking times for eggs or pasta
- Caramel or toffee making

### Multi-Step Processes
- Fresh pasta making (rolling, cutting, shaping)
- Complex plating instructions
- Multi-component dish assembly
- Layered dishes (lasagna, layer cakes)
- Meal prep with multiple concurrent recipes
- Batch cooking operations

### Safety-Critical Moments
- Handling hot pans and checking next steps
- Knife skill techniques requiring focus
- Deep frying operations
- Pressure cooker setup and monitoring
- Hot oil or sugar work
- Using mandolines or sharp tools

### Environmental Considerations
- Steam from pots affecting camera visibility
- Varying kitchen lighting conditions
  - Natural light changes
  - Evening/night cooking
  - Under-cabinet lighting
- Limited counter space scenarios
- Splatter protection requirements
- Kitchen humidity levels
- Heat from nearby cooking

### Multi-Tasking Situations
- Answering door/phone while cooking
- Supervising children while following recipe
- Managing multiple dishes simultaneously
- Coordinating timing between different recipes
- Handling unexpected interruptions
- Kitchen cleanup while following next steps

### Special Considerations
- Different counter heights and phone placement
- Varying gesture detection distances needed
- Kitchen ventilation affecting steam levels
- Splash zones near sinks or cooking areas
- Heat zones near stoves or ovens
- Lighting variations throughout kitchen
- Space constraints in smaller kitchens

These use cases should be considered during:
- Gesture sensitivity calibration
- Camera positioning recommendations
- User interface design
- Error handling and recovery
- Performance optimization
- Safety feature implementation 