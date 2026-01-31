# CCHookInstaller - Agent Instructions

## Project Overview

CCHookInstaller is a shared Swift library that provides a unified mechanism for installing and managing Claude Code hooks. It's used by CCLangTutor and CCPlanView to integrate with Claude Code's hook system.

## Build Commands

```bash
# Build
swift build

# Run tests
swift test
```

## Key Files

- `Sources/CCHookInstaller/HookConfiguration.swift` - Hook type and configuration
- `Sources/CCHookInstaller/HookManager.swift` - Main hook management logic
- `Sources/CCHookInstaller/HookManagerError.swift` - Error types

## Usage

This package is used as a local dependency by:
- CCLangTutor (XcodeGen project)
- CCPlanView (XcodeGen project)

Both projects reference it via relative path in their `project.yml`:
```yaml
packages:
  CCHookInstaller:
    path: ../CCHookInstaller
```

## API Overview

```swift
// UserPromptSubmit hook (e.g., CCLangTutor)
let manager = HookManager(
    configuration: .userPromptSubmit(
        appName: "MyApp",
        hookIdentifiers: ["MyApp.app/Contents/MacOS/notifier"]
    )
)

// PreToolUse hook with matcher (e.g., CCPlanView)
let manager = HookManager(
    configuration: .preToolUse(
        appName: "MyApp",
        hookIdentifiers: ["MyApp.app/Contents/MacOS/notifier"],
        matcher: "ExitPlanMode",
        timeout: 10
    )
)

// Common operations
manager.isClaudeCodeInstalled()     // Check if .claude dir exists
manager.validateSettings()          // Check for settings.json errors
manager.isHookConfigured()          // Check if hook is installed
manager.needsHookUpdate()           // Check if cleanup needed
try manager.installHook()           // Install hook
try manager.removeHook()            // Remove hook
try manager.cleanupAndInstallHook() // Remove all and reinstall
```
