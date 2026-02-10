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

## Toast Plan MCP Usage Guide

### 目的
本指南用于说明如何发现、连接并调用 Toast Plan 内置的 MCP 服务，便于复制到任意 AGENTS.md 中复用。

### 前置条件
1. Toast Plan 正在运行。
2. MCP Server 已启动（通过应用内入口或调用 `start-mcp-server` IPC）。

### 发现与端口
- 默认端口为 `42857`，优先尝试该端口。
- 若 `42857` 连接失败，必须主动向用户询问实际端口。

### HTTP 接口
- `GET /api/tools` 返回工具列表与输入 schema。
- `POST /api/call` 调用工具，Body 为 JSON：`{ "name": "<tool>", "arguments": { ... } }`。
- `GET /sse` 与 `POST /messages` 是 MCP SSE 传输通道。

```bash
curl -s http://localhost:42857/api/tools
```

```bash
curl -s -X POST http://localhost:42857/api/call \
  -H 'Content-Type: application/json' \
  -d '{"name":"create_task","arguments":{"title":"Test Task","isAiActive":true}}'
```

### SDK 客户端（推荐）
使用内置 SDK 客户端读取发现文件并调用工具。发现文件路径需由用户提供或确认。

```bash
bun run utils/mcp-client.js create_task '{"title":"Test Task","isAiActive":true}'
```

### 可用工具
- `get_full_context`
- `get_recent_activities`
- `search_tasks_semantic`
- `upsert_task_embedding`
- `reindex_all_tasks`
- `create_outcome`
- `update_outcome`
- `create_task`
- `update_task`

### 行为约定
- `create_task` 在 `isAiActive` 为 `true` 时会自动将 `status` 设为 `doing`。
- `update_task` 接收 `updates` 对象，并内部处理 `status`、`startedAt`、`completedAt` 的联动更新。

### 使用流程要求
1. **首次使用时**：必须询问是否创建对应项目（Project），并将后续任务关联到该项目，或作为通用任务处理。
2. **复杂任务**：优先创建 `Outcome`，并将相关任务关联到该 `Outcome`。
3. **任务流转**：每进行一个任务的第一件事就是 `create_task`；开始执行时更新为 `doing`，完成后更新为 `done`。

### 排错
- 如果 `GET /api/tools` 正常而 `POST /api/call` 失败，检查本地网络权限与 MCP Server 运行状态。
- 端口不确定时，请读取 `mcp-connection.json`，不要假设固定端口。