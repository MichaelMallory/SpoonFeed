# Codebase Best Practices for SpoonFeed

## Introduction
This document defines the best practices for structuring, naming, and documenting our AI-first codebase. Our goal is to ensure that the project is modular, scalable, and easy to navigate. All files will include a brief explanation of their contents at the top, and each function must be documented using appropriate commenting standards (e.g., JSDoc, TSDoc).

**References:**
- [tech-stack.md](tech-stack.md): Details our technology stack and core technologies.
- [tech-stack-rules.md](tech-stack-rules.md): Outlines the best practices and limitations of our chosen tech stack.
- [ui-rules.md](ui-rules.md): Provides guidelines for building mobile UI components.
- [theme-rules.md](theme-rules.md): Defines the visual theme and design elements for the application.

## 1. Folder Structure
Our project folder structure is designed to separate concerns and maintain high navigability. Below is a recommended file tree:

```
SpoonFeed/
├── docs/                # Documentation (e.g., user-flow.md, tech-stack.md, codebase-best-practices.md)
├── src/                 # Source code for the application
│   ├── assets/          # Static assets (images, fonts, icons)
│   │   ├── icons/
│   │   └── images/
│   ├── components/      # Reusable UI components (Flutter widgets)
│   ├── screens/         # Application screens or pages
│   ├── models/          # Data models and type definitions
│   ├── services/        # Backend integrations (Firebase, AI services, Cloud Functions)
│   └── utils/           # Utility functions and helpers
├── tests/               # Unit and integration tests
├── scripts/             # Automation scripts and CI/CD configurations
└── build/               # Build outputs and artifacts
```

## 2. File Naming Conventions
- **General Files:** Use kebab-case (e.g., `ui-rules.md`, `theme-rules.md`, `codebase-best-practices.md`).
- **Source Code Files:** Use consistent naming; for example, components and utilities should also be in kebab-case, while classes should be in PascalCase and functions in camelCase.
- **File Length:** To ensure readability by Cursor's AI tools, individual files should not exceed 250 lines. If necessary, split large files into smaller, dedicated modules.

## 3. Documentation and Commenting Standards
- **File Headers:** Every file must start with a brief description of its contents and purpose.
- **Function Documentation:** All functions, methods, and classes should include inline documentation (e.g., JSDoc or TSDoc) describing their purpose, parameters, and return values.
- **Comments:** Use clear, concise comments throughout the code to explain complex sections or any non-obvious logic.

## 4. Modular and Scalable Architecture
- **Separation of Concerns:** Structure your code to isolate UI components, business logic, data models, and service integrations. This improves maintainability and scalability.
- **Reusable Components:** Develop reusable UI components and utility functions that can be shared throughout the codebase.
- **Integration with Tech Stack:** Ensure that all frontend code (built using Flutter) integrates smoothly with backend services (Firebase Auth, Firestore, Cloud Storage, and Cloud Functions) and AI-driven features.

## 5. Coding Best Practices
- **Consistency:** Follow consistent coding styles and conventions throughout the project. Utilize linters and formatters to enforce these standards.
- **Readable Code:** Write code that is easy to understand. Prefer clarity over cleverness, and keep functions concise and focused on a single task.
- **AI-First Considerations:** Design abstractions for AI and machine learning integration. Components interfacing with AI should be modular and isolated for ease of testing and future upgrades.

## 6. File Size and Readability
- **Line Limits:** To optimize readability by AI tools, ensure that no file exceeds 250 lines. Refactor or split files when necessary.

## Conclusion
Adhering to these best practices will create a modular, scalable, and maintainable codebase that supports rapid development and integration of AI features. This organized structure not only benefits the current development process but also lays a strong foundation for future growth and collaboration. 