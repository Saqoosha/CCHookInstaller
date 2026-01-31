# CCHookInstaller Architecture

## Overview

CCHookInstaller is a shared library that abstracts the common hook installation mechanism used by multiple macOS apps integrating with Claude Code.

## Design Goals

1. **DRY (Don't Repeat Yourself)** - Single source of truth for hook management logic
2. **Flexibility** - Support different hook types (UserPromptSubmit, PreToolUse)
3. **Thread Safety** - Use file coordination to prevent race conditions
4. **Testability** - Dependency injection for testing without touching real settings

## Components

### HookConfiguration

Defines hook parameters with factory methods for common configurations:

```
┌─────────────────────────────────────────────────────────┐
│                   HookConfiguration                      │
├─────────────────────────────────────────────────────────┤
│ hookType: HookType        (.userPromptSubmit/.preToolUse)│
│ hookIdentifiers: [String] (patterns to detect our hook)  │
│ matcher: String?          (PreToolUse only)              │
│ timeout: Int?             (PreToolUse only)              │
│ appName: String           (for error messages)           │
├─────────────────────────────────────────────────────────┤
│ + userPromptSubmit(appName:hookIdentifiers:)            │
│ + preToolUse(appName:hookIdentifiers:matcher:timeout:)  │
└─────────────────────────────────────────────────────────┘
```

### HookManager

Main class handling all hook operations:

```
┌─────────────────────────────────────────────────────────┐
│                     HookManager                          │
├─────────────────────────────────────────────────────────┤
│ configuration: HookConfiguration        (let)            │
│ claudeDir: URL                          (private(set))   │
│ settingsPath: URL                       (computed)       │
├─────────────────────────────────────────────────────────┤
│ + isClaudeCodeInstalled() -> Bool                       │
│ + isHookConfigured() -> Bool                            │
│ + validateSettings() -> HookManagerError?               │
│ + needsHookUpdate() -> Bool                             │
│ + installHook() throws                                  │
│ + removeHook() throws                                   │
│ + cleanupAndInstallHook() throws                        │
└─────────────────────────────────────────────────────────┘
```

### HookManagerError

Error types for hook operations:

- `settingsCorrupted` - JSON parsing failed
- `settingsUnreadable` - File read permission error
- `unexpectedStructure` - settings.json has wrong structure
- `notifierNotFound(appName:)` - App bundle or notifier not found

### HookSetupUI

UI coordinator that handles the entire hook setup flow on app launch:

```
┌─────────────────────────────────────────────────────────┐
│                      HookSetupUI                         │
│                   @MainActor enum                        │
├─────────────────────────────────────────────────────────┤
│ + checkOnLaunch(hookManager:messages:dontAskAgainKey:  │
│                  onConfigurationChanged:)               │
├─────────────────────────────────────────────────────────┤
│ + showError(_:)                                         │
│ + showSuccess(title:message:)                           │
│ + showWarning(title:message:)                           │
│ + showInstallPrompt(title:message:) -> InstallPromptResult│
│ + showUpdatePrompt(title:message:) -> Bool              │
│ + showRemovePrompt(title:message:) -> Bool              │
└─────────────────────────────────────────────────────────┘
```

`checkOnLaunch` handles the complete flow:
1. Check if Claude Code is installed
2. Validate settings.json
3. Prompt for update if path changed or duplicates exist
4. Skip if already configured
5. Respect "Don't Ask Again" preference
6. Show install prompt for new installations

### HookSetupMessages

Customizable messages for the setup flow:

```
┌─────────────────────────────────────────────────────────┐
│                   HookSetupMessages                      │
├─────────────────────────────────────────────────────────┤
│ installPromptTitle: String                              │
│ installPromptMessage: String                            │
│ updatePromptTitle: String                               │
│ updatePromptMessage: String                             │
│ successTitle: String                                    │
│ successMessage: String                                  │
│ updateSuccessTitle: String                              │
│ updateSuccessMessage: String                            │
│ settingsWarningTitle: String                            │
└─────────────────────────────────────────────────────────┘
```

### InstallPromptResult

Enum representing user's response to install prompt:
- `.install` - User chose to install
- `.later` - User chose to defer
- `.dontAskAgain` - User chose to never ask again

## Settings.json Structure

Claude Code stores hooks in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "command": "/path/to/CCLangTutor.app/Contents/MacOS/notifier",
            "type": "command"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "ExitPlanMode",
        "hooks": [
          {
            "command": "/path/to/CCPlanView.app/Contents/MacOS/notifier",
            "type": "command",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

## Thread Safety

All file operations use `NSFileCoordinator` with `.forMerging` option to prevent concurrent read-modify-write issues when multiple apps access settings.json simultaneously.

## Concurrency

All public types conform to `Sendable` for Swift 6 compatibility:
- `HookType: Sendable`
- `HookConfiguration: Sendable`
- `HookManagerError: Sendable`
- `HookManager: @unchecked Sendable`
- `HookSetupMessages: Sendable`
- `InstallPromptResult: Sendable`
- `HookSetupUI: @MainActor enum` (UI operations on main thread)

The `HookManager` class uses `@unchecked Sendable` because:
1. File operations are synchronized via `NSFileCoordinator`
2. `configuration` is immutable (`let`)
3. `claudeDir` is `private(set)` and only set at initialization

## Integration Pattern

Each app creates a thin wrapper around the shared `HookManager` and uses `HookSetupUI` for the setup flow:

```swift
// In CCLangTutor
enum HookManager {
    static let shared = CCHookInstaller.HookManager(
        configuration: .userPromptSubmit(
            appName: "CCLangTutor",
            hookIdentifiers: ["CCLangTutor.app/"]
        )
    )

    static let messages = HookSetupMessages(
        installPromptMessage: "CCLangTutor can notify you...",
        updatePromptMessage: "CCLangTutor's hook configuration needs updating.",
        successMessage: "CCLangTutor will now receive notifications.",
        updateSuccessMessage: "Hook has been updated."
    )

    static func isClaudeCodeInstalled() -> Bool {
        shared.isClaudeCodeInstalled()
    }
    // ... other forwarding methods

    @MainActor
    static func checkOnLaunch() {
        HookSetupUI.checkOnLaunch(
            hookManager: shared,
            messages: messages,
            dontAskAgainKey: "DontAskHookInstall"
        ) {
            // Post notification if needed
            NotificationCenter.default.post(name: .hookConfigurationChanged, object: nil)
        }
    }
}
```

This pattern:
- Maintains the same API as before (no changes to callers)
- Uses shared `HookSetupUI` for consistent UI flow
- App provides only customized messages
- Supports "Don't Ask Again" preference per app

## Testing

Tests use dependency injection to avoid touching real settings:

```swift
let manager = HookManager(
    configuration: .userPromptSubmit(...),
    claudeDir: tempTestDir,
    notifierPathProvider: { "/mock/path/to/notifier" }
)
```

## File Structure

```
CCHookInstaller/
├── Package.swift
├── README.md
├── LICENSE
├── CLAUDE.md
├── docs/
│   └── ARCHITECTURE.md
├── Sources/CCHookInstaller/
│   ├── HookConfiguration.swift
│   ├── HookManager.swift
│   ├── HookManagerError.swift
│   ├── HookSetupMessages.swift
│   └── HookSetupUI.swift
└── Tests/CCHookInstallerTests/
    └── HookManagerTests.swift
```
