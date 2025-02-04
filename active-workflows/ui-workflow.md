# UI Workflow Template

> Strictly adhere to this workflow. Items should be addressed one-by-one, in order. Always reference [UI Rules](../ui-rules.md), [Theme Rules](../theme-rules.md), and [Codebase Best Practices](../codebase-best-practices.md).

## Project State
**Project Phase:** [Phase Number/Name] UI-Focused

## Task Management
- [ ] Identify current UI tasks from the relevant phase file
- [ ] Copy task details to "Primary Feature" section
- [ ] Break down into "Component Features" if needed

## Primary Feature
**Name:** [Feature Name]  
**Description:** [Feature Description]

## Component Features
- [ ] [Component Feature Name]
  - [ ] [UI Task 1]
  - [ ] [UI Task 2]

## Progress Checklist

### Understanding Phase
#### Documentation Review
- [ ] UI guidelines from [UI Rules](../ui-rules.md)
- [ ] Theming guidelines from [Theme Rules](../theme-rules.md)
- [ ] Flutter Material Design components and best practices
- [ ] Animation and transition requirements (using Flutter's animation system)
- [ ] Firebase integration points (if required for the UI)

#### Implementation Plan
- [ ] Widget tree structure
- [ ] State management approach (using Provider/Bloc)
- [ ] Theming and styling approach
- [ ] Accessibility requirements
- [ ] Responsive design considerations
- [ ] Error handling and loading states

**Notes:** [Notes]

### Planning Phase
#### Component Architecture
- [ ] Define widget tree/wireframes
  ```
  [Widget Tree or Wireframe goes here]
  ```
- [ ] List styling requirements
- [ ] Define file structure (per [Codebase Best Practices](../codebase-best-practices.md))
- [ ] Plan Firebase interactions (if needed)
- [ ] PAUSE, Check in with user

**Notes:** [Notes]

### Implementation Phase
#### Setup
- [ ] Verify project structure follows [Codebase Best Practices](../codebase-best-practices.md)
- [ ] Check required Flutter packages are in pubspec.yaml
- [ ] Verify Firebase configuration (if needed for the feature)
- [ ] Set up state management (Provider/Bloc)

**Notes:** [Notes]

#### Development
- [ ] Create/update widget files
- [ ] Implement UI layout and styling
- [ ] Add animations and transitions
- [ ] Implement state management logic
- [ ] Add error handling and loading states
- [ ] Ensure responsive design works on different screen sizes
- [ ] Implement Firebase integration (if required)

**Notes:** [Notes]

### Verification Phase
#### Quality Check
- [ ] Design compliance with [Theme Rules](../theme-rules.md)
- [ ] Animation/transition behavior
- [ ] Responsive design testing
- [ ] Performance testing (especially for lists and animations)
- [ ] Firebase integration testing (if applicable)
- [ ] Accessibility
- [ ] Code organization
- [ ] Documentation
- [ ] Flutter-specific best practices

**Notes:** [Notes]

### Testing
- [ ] Run on Android emulator/device
- [ ] Verify UI renders correctly
- [ ] Test user interactions
- [ ] Verify Firebase integration (if applicable)
- [ ] Check performance on different devices
- [ ] Test error scenarios and loading states

### Completion
- [ ] User sign-off
- [ ] Update task tracking
- [ ] Document learnings
- [ ] Ensure all Firebase security rules are in place (if needed)

## Notes
### Key decisions and learnings:
- [ ]
- [ ]