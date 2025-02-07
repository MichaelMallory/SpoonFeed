# Dual-View Game Feature Design Document

## Overview
This feature will implement a unique "Game Mode" where users can simultaneously watch cooking videos in the top half of the screen while playing a simple, food-themed game in the bottom half. This creates an engaging, multi-tasking experience that could increase user retention and create viral appeal.

## Game Concepts

### Implemented: Food Ninja Style Game ✅
- Similar to Fruit Ninja but with cooking ingredients
- Players slice flying ingredients with swipe gestures
- Themed around food prep and cooking
- Simple and intuitive gameplay
- Colorful food emojis with glowing effects
- Parabolic motion physics for realistic food tossing

### Option 2: Kitchen Runner
- Endless runner style game with chef character
- Collect ingredients while avoiding obstacles
- More complex but potentially more engaging
- Could tie into recipe themes

## Technical Implementation Checklist

### Core Architecture Requirements
- [x] Implement split-screen container widget
  - [x] Top half: Video feed component
  - [x] Bottom half: Game canvas
- [x] Set up game loop system using Flame game engine
- [x] Create gesture detection system that doesn't interfere with video feed
  - [x] Implemented scroll prevention during game mode
  - [x] Maintained swipe detection for food slicing
- [x] Implement pause mechanism when game mode is toggled

### Game Engine Integration
- [x] Integrate Flame game engine
  - [x] Sprite rendering using emojis
  - [x] Physics calculations for parabolic motion
  - [x] Collision detection for slicing
  - [x] Trail effects for food items
- [x] Set up game viewport constraints
- [x] Implement frame rate management
- [x] Add visual effects (glowing, trails)

### Video Integration
- [x] Modify video player to work in constrained viewport
- [x] Ensure video playback performance isn't affected by game
- [x] Handle state management between game and video components
- [x] Implement smooth transitions when toggling game mode
- [x] Added video looping functionality

### UI/UX Requirements
- [x] Design game mode toggle button
  - [x] Added to three-dot menu
  - [x] Clear enable/disable options
- [x] Create game UI elements
  - [x] Score display
  - [x] High score tracking
  - [x] Heart-based lives system
  - [x] Grid background for depth perception
  - [x] Gradient background for game area
- [x] Implement smooth animations for transitioning between modes
- [x] Design game assets
  - [x] Colorful food emojis
  - [x] Color-matched glow effects
  - [x] Motion trails
- [x] Game over screen
  - [x] Score display
  - [x] High score tracking
  - [x] Play again option
  - [x] Close game option
  - [x] Kitchen-themed icons (🔪🍴)

### Performance Optimization
- [x] Implement efficient rendering techniques
- [x] Optimize asset loading (using emojis)
- [x] Handle different screen sizes
- [x] Ensure smooth frame rates

### Data Management
- [x] Store high scores
- [x] Track current game score
- [x] Save game state when disabled
- [x] Persist high scores between sessions

## Game Mechanics
- [x] Food spawning system
  - [x] Random food selection
  - [x] Varied spawn positions
  - [x] Configurable spawn rates
- [x] Physics system
  - [x] Gravity effects
  - [x] Parabolic trajectories
  - [x] Randomized initial velocities
- [x] Scoring system
  - [x] Point tracking
  - [x] High score updates
- [x] Lives system
  - [x] Three hearts
  - [x] Visual heart updates
  - [x] Game over on three misses

## Visual Effects
- [x] Food items
  - [x] Colorful emoji graphics
  - [x] Color-matched glow effects
  - [x] Motion trails
- [x] Background
  - [x] Gradient colors
  - [x] Grid pattern overlay
- [x] UI elements
  - [x] Glowing text
  - [x] Transparent overlays
  - [x] Responsive buttons

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
1. Add sound effects for:
   - Slicing food
   - Missing food
   - Game over
2. Add particle effects for successful slices
3. Implement combo system for consecutive hits
4. Add power-ups or special food items
5. Create achievement system
6. Choose between Food Ninja or Kitchen Runner concept
7. Set up Flame game engine integration
8. Create basic prototype of split-screen functionality
9. Design initial game assets
10. Implement basic game mechanics 