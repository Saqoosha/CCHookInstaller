# CCHookInstaller

A shared Swift library for managing Claude Code hooks on macOS.

## Overview

CCHookInstaller provides a unified mechanism for installing and managing Claude Code hooks. It's used by:
- [CCLangTutor](https://github.com/Saqoosha/CCLangTutor) - English grammar correction for Claude Code prompts
- [CCPlanView](https://github.com/Saqoosha/CCPlanView) - Plan file viewer for Claude Code

## Features

- Support for `UserPromptSubmit` and `PreToolUse` hook types
- Thread-safe file operations via `NSFileCoordinator`
- Automatic hook detection and cleanup
- Swift 6 concurrency support (`Sendable` conformance)

## Requirements

- macOS 14.0+
- Swift 5.10+

## Installation

Add as a local package dependency in your `project.yml` (XcodeGen):

```yaml
packages:
  CCHookInstaller:
    path: ../CCHookInstaller

targets:
  YourApp:
    dependencies:
      - package: CCHookInstaller
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(path: "../CCHookInstaller"),
]
```

## Usage

### UserPromptSubmit Hook

```swift
import CCHookInstaller

let manager = HookManager(
    configuration: .userPromptSubmit(
        appName: "MyApp",
        hookIdentifiers: ["MyApp.app/Contents/MacOS/notifier"]
    )
)

// Check and install
if manager.isClaudeCodeInstalled() && !manager.isHookConfigured() {
    try manager.installHook()
}
```

### PreToolUse Hook

```swift
import CCHookInstaller

let manager = HookManager(
    configuration: .preToolUse(
        appName: "MyApp",
        hookIdentifiers: ["MyApp.app/Contents/MacOS/notifier"],
        matcher: "ExitPlanMode",
        timeout: 10
    )
)

try manager.installHook()
```

### API

| Method | Description |
|--------|-------------|
| `isClaudeCodeInstalled()` | Check if `.claude` directory exists |
| `validateSettings()` | Check for settings.json errors |
| `isHookConfigured()` | Check if hook is installed |
| `needsHookUpdate()` | Check if cleanup is needed |
| `installHook()` | Install the hook |
| `removeHook()` | Remove the hook |
| `cleanupAndInstallHook()` | Remove all and reinstall |

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - Design and implementation details

## License

MIT License - see [LICENSE](LICENSE) for details.
