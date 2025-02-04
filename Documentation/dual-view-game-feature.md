# Dual-View Game Feature Design Document

## Overview
This feature will implement a unique "Game Mode" where users can simultaneously watch cooking videos in the top half of the screen while playing a simple, food-themed game in the bottom half. This creates an engaging, multi-tasking experience that could increase user retention and create viral appeal.

## Game Concepts

### Option 1: Food Ninja
- Similar to Fruit Ninja but with cooking ingredients
- Players slice flying ingredients with swipe gestures
- Themed around food prep and cooking
- Simpler to implement due to 2D nature
- More casual, pick-up-and-play friendly

### Option 2: Kitchen Runner
- Endless runner style game with chef character
- Collect ingredients while avoiding obstacles
- More complex but potentially more engaging
- Could tie into recipe themes

## Technical Implementation Checklist

### Core Architecture Requirements
- [ ] Implement split-screen container widget
  - Top half: Video feed component
  - Bottom half: Game canvas
- [ ] Set up game loop system using Flutter's animation framework
- [ ] Create gesture detection system that doesn't interfere with video feed
- [ ] Implement pause mechanism when video feed is scrolled

### Game Engine Integration
- [ ] Evaluate and integrate Flame game engine (Flutter's official game engine)
  - Handles sprite rendering
  - Physics calculations
  - Collision detection
  - Animation management
- [ ] Set up game viewport constraints
- [ ] Implement frame rate management

### Video Integration
- [ ] Modify existing video player to work in constrained viewport
- [ ] Ensure video playback performance isn't affected by game
- [ ] Handle state management between game and video components
- [ ] Implement smooth transitions when toggling game mode

### UI/UX Requirements
- [ ] Design game mode toggle button
- [ ] Create game UI elements (score, pause button, etc.)
- [ ] Implement smooth animations for transitioning between normal/game modes
- [ ] Design game assets (sprites, backgrounds)
- [ ] Create food-themed game elements

### Performance Optimization
- [ ] Implement efficient rendering techniques
- [ ] Optimize asset loading and management
- [ ] Handle device rotation and different screen sizes
- [ ] Ensure smooth frame rates on various devices

### Data Management
- [ ] Store high scores
- [ ] Track game statistics
- [ ] Implement achievement system
- [ ] Save game state when interrupted

## Technical Dependencies
1. Flame game engine (`flame: ^1.8.0`)
2. Custom sprite assets
3. Sound effects library
4. State management solution (already using Provider)

## Implementation Phases

### Phase 1: Foundation
- Set up basic split-screen architecture
- Implement game engine integration
- Create basic game loop

### Phase 2: Core Game
- Implement basic game mechanics
- Add collision detection
- Create scoring system
- Design and integrate basic sprites

### Phase 3: Integration
- Connect with video player
- Implement state management
- Add transition animations
- Test performance

### Phase 4: Polish
- Add sound effects
- Implement achievements
- Create tutorial
- Polish UI/UX
- Optimize performance

## Estimated Timeline
- Foundation: 1 week
- Core Game: 2 weeks
- Integration: 1 week
- Polish: 1 week

## Technical Considerations
1. Memory management will be crucial with both video and game running
2. Need to handle app lifecycle changes gracefully
3. Must maintain smooth performance on mid-range devices
4. Consider battery impact of running both systems

## Success Metrics
- User engagement time increases
- Share/viral metrics
- Game session length
- Video watch-through rate while gaming
- User retention improvement

## Next Steps
1. Choose between Food Ninja or Kitchen Runner concept
2. Set up Flame game engine integration
3. Create basic prototype of split-screen functionality
4. Design initial game assets
5. Implement basic game mechanics 