# AGENTS.md

This file provides guidance to Qoder (qoder.com) when working with code in this repository.

## Project Overview

PromptHub is a powerful macOS application built with SwiftUI for managing and organizing prompts. The app supports creating, editing, deleting, searching, and testing prompts across multiple AI models. It features multi-model testing capabilities, real-time streaming responses, and comprehensive comparison tools.

## Tech Stack

- **Language**: Swift 5.0+
- **Framework**: SwiftUI, SwiftData (for persistence)
- **Architecture**: MVVM with Observable objects and EnvironmentObjects
- **Build System**: Xcode project with Swift Package Manager for dependencies
- **Platform**: macOS 14.6+ (native macOS application)

## Key Dependencies

- **GenKit**: Core AI integration library
- **SwiftUI**: Native UI framework
- **SwiftData**: Data persistence framework
- **KeyboardShortcuts**: Global keyboard shortcut management
- **LaunchAtLogin**: Auto-launch functionality
- **AlertToast**: In-app notifications
- **WhatsNewKit**: "What's New" feature announcements
- **DifferenceKit**: Diff algorithm for comparing prompt versions
- Various AI service libraries: swift-openai, swift-anthropic, swift-ollama, swift-mistral, swift-perplexity, swift-elevenlabs, swift-fal, swift-llama

## Architecture

### Core Components
- **Models**: SwiftData models for prompts, history, and external sources
- **Views**: SwiftUI views organized in subdirectories (HomeViews, SettingViews, SharedViews, etc.)
- **Managers**: Business logic managers (DeepLinkManager, ServicesManager, CloudKit sync)
- **Utilities**: Helper functions and extensions
- **Extensions**: Swift and SwiftUI extensions

### Data Flow
- SwiftData managed object models for persistence
- Observable classes for state management (ServicesManager, AppSettings)
- EnvironmentObjects for passing state through view hierarchy
- Deep linking support for import/export functionality

### Key Features
- Prompt creation, editing, and management
- Multi-model AI testing with side-by-side comparisons
- Real-time streaming responses
- Global search functionality with keyboard shortcuts
- Import/export capabilities
- CloudKit synchronization
- Internationalization support (Chinese & English)

## Common Development Commands

### Building
```bash
# Build the project in Xcode
xcodebuild -project prompthub.xcodeproj -scheme prompthub -configuration Debug build

# Or use xcodebuild for release
xcodebuild -project prompthub.xcodeproj -scheme prompthub -configuration Release build
```

### Testing
```bash
# Run unit tests
xcodebuild -project prompthub.xcodeproj -scheme prompthubTests -destination 'platform=macOS' test

# Run UI tests
xcodebuild -project prompthub.xcodeproj -scheme prompthubUITests -destination 'platform=macOS' test
```

### Development Workflow
1. Open `prompthub.xcodeproj` in Xcode
2. Select the `prompthub` scheme
3. Build and run with Cmd+R or Product → Run
4. For debugging, use Xcode's built-in debugger

### Clean Build
```bash
xcodebuild -project prompthub.xcodeproj -scheme prompthub clean
```

## Important Files and Directories

- `prompthubApp.swift`: Main application entry point
- `ContentView.swift`: Root navigation structure
- `Models/`: SwiftData models (Prompt, PromptHistory, etc.)
- `Views/`: SwiftUI views organized by feature
- `Managers/`: Application logic managers
- `Assets.xcassets/`: App icons and assets
- `Localizable.xcstrings`: Internationalization strings

## Key Patterns

- Use `@Observable` for observable state management
- Use `@Model` for SwiftData entities
- Use `@EnvironmentObject` for shared app state
- Use `@State` for local view state
- Follow MVVM pattern with clear separation of concerns
- Leverage SwiftData for persistence with proper relationships
- Use keyboard shortcuts for enhanced UX
- Implement proper error handling with user-friendly alerts

## Testing Notes

- Unit tests are in `prompthubTests/`
- UI tests are in `prompthubUITests/`
- Use Xcode's testing infrastructure for both types
- Mock external dependencies when testing business logic