# CCHookInstaller

A shared Swift library for managing Claude Code hooks on macOS.

## Overview

CCHookInstaller provides a unified mechanism for installing and managing Claude Code hooks. It's used by:
- [CCLangTutor](https://github.com/Saqoosha/CCLangTutor) - English grammar correction for Claude Code prompts
- [CCPlanView](https://github.com/Saqoosha/CCPlanView) - Plan file viewer for Claude Code

## Features

- Support for `UserPromptSubmit` and `PreToolUse` hook types
- Complete hook setup UI flow with `HookSetupUI.checkOnLaunch()`
- Thread-safe file operations via `NSFileCoordinator`
- Automatic hook path detection and update prompts
- Swift 6 concurrency support (`Sendable` conformance)

## Requirements

- macOS 14.0+
- Swift 5.10+

## Installation

### Using GitHub URL (recommended for releases)

In `project.yml` (XcodeGen):

```yaml
packages:
  CCHookInstaller:
    url: https://github.com/Saqoosha/CCHookInstaller
    from: 1.2.0

targets:
  YourApp:
    dependencies:
      - package: CCHookInstaller
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Saqoosha/CCHookInstaller", from: "1.2.0"),
]
```

### Using Local Path (for development)

```yaml
packages:
  CCHookInstaller:
    path: ../CCHookInstaller
```

## Quick Start

### 1. Create HookManager Configuration

```swift
// HookManager.swift
import CCHookInstaller
import Foundation

enum HookManager {
    static let shared = CCHookInstaller.HookManager(
        configuration: .userPromptSubmit(
            appName: "MyApp",
            hookIdentifiers: ["MyApp.app/Contents/MacOS/notifier"]
        )
    )

    static let messages = HookSetupMessages(
        installPromptMessage: "MyApp can enhance your Claude Code experience. Install the hook?",
        updatePromptMessage: "The MyApp hook path has changed. Update it?",
        successMessage: "Hook installed successfully!",
        updateSuccessMessage: "Hook updated successfully!"
    )

    static let dontAskAgainKey = "dontAskHookSetup"

    // Pass-through methods for Settings UI
    static func isClaudeCodeInstalled() -> Bool { shared.isClaudeCodeInstalled() }
    static func isHookConfigured() -> Bool { shared.isHookConfigured() }
    static func installHook() throws { try shared.installHook() }
    static func removeHook() throws { try shared.removeHook() }
}
```

### 2. Call checkOnLaunch in AppDelegate

```swift
// AppDelegate.swift
import AppKit
import CCHookInstaller

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HookSetupUI.checkOnLaunch(
            hookManager: HookManager.shared,
            messages: HookManager.messages,
            dontAskAgainKey: HookManager.dontAskAgainKey,
            onConfigurationChanged: {
                NotificationCenter.default.post(name: .hookConfigurationChanged, object: nil)
            }
        )
    }
}
```

### 3. Add Settings Menu (Optional)

```swift
// In your App struct
import CCHookInstaller

@State private var isHookConfigured = HookManager.isHookConfigured()

var body: some Scene {
    // ...
    .commands {
        CommandGroup(after: .appInfo) {
            Button {
                if isHookConfigured { removeHook() } else { installHook() }
            } label: {
                Text(isHookConfigured ? "✓ Hooks Installed" : "Setup Hooks...")
            }
            .disabled(!HookManager.isClaudeCodeInstalled())
            .onReceive(NotificationCenter.default.publisher(for: .hookConfigurationChanged)) { _ in
                isHookConfigured = HookManager.isHookConfigured()
            }
        }
    }
}

private func installHook() {
    let result = HookSetupUI.showInstallPrompt(
        title: HookManager.messages.installPromptTitle,
        message: HookManager.messages.installPromptMessage
    )
    guard result == .install else { return }

    do {
        try HookManager.installHook()
        isHookConfigured = true
        HookSetupUI.showSuccess(
            title: HookManager.messages.successTitle,
            message: HookManager.messages.successMessage
        )
    } catch {
        HookSetupUI.showError(error)
    }
}

private func removeHook() {
    guard HookSetupUI.showRemovePrompt(
        title: "Remove Hooks?",
        message: "The hook will be removed."
    ) else { return }

    do {
        try HookManager.removeHook()
        isHookConfigured = false
    } catch {
        HookSetupUI.showError(error)
    }
}
```

## Hook Types

### UserPromptSubmit

Triggered when user submits a prompt to Claude Code.

```swift
.userPromptSubmit(
    appName: "MyApp",
    hookIdentifiers: ["MyApp.app/Contents/MacOS/notifier"]
)
```

### PreToolUse

Triggered before Claude uses a specific tool.

```swift
.preToolUse(
    appName: "MyApp",
    hookIdentifiers: ["MyApp.app/Contents/MacOS/notifier"],
    matcher: "ExitPlanMode",  // Tool name to match
    timeout: 10               // Seconds
)
```

## API Reference

### HookManager

| Method | Description |
|--------|-------------|
| `isClaudeCodeInstalled()` | Check if `.claude` directory exists |
| `validateSettings()` | Check for settings.json errors, returns `HookManagerError?` |
| `isHookConfigured()` | Check if hook is correctly installed (including path check) |
| `needsHookUpdate()` | Check if hook exists but needs path update |
| `installHook()` | Install the hook |
| `removeHook()` | Remove the hook |
| `cleanupAndInstallHook()` | Remove all matching hooks and reinstall |

### HookSetupUI

| Method | Description |
|--------|-------------|
| `checkOnLaunch(...)` | Complete setup flow: validate → update prompt → install prompt |
| `showError(_:)` | Show error alert |
| `showSuccess(title:message:)` | Show success alert |
| `showWarning(title:message:)` | Show warning alert |
| `showInstallPrompt(title:message:)` | Show Install/Later/Don't Ask Again dialog |
| `showUpdatePrompt(title:message:)` | Show Update/Later dialog |
| `showRemovePrompt(title:message:)` | Show Remove/Cancel dialog |

### HookSetupMessages

Customizable messages for dialogs:

```swift
HookSetupMessages(
    installPromptTitle: "Setup Claude Code Hooks?",      // Default
    installPromptMessage: "...",                          // Required
    updatePromptTitle: "Update Claude Code Hook?",        // Default
    updatePromptMessage: "...",                           // Required
    successTitle: "Hooks Installed",                      // Default
    successMessage: "...",                                // Required
    updateSuccessTitle: "Hook Updated",                   // Default
    updateSuccessMessage: "...",                          // Required
    settingsWarningTitle: "Claude Code Settings Warning"  // Default
)
```

## checkOnLaunch Flow

`HookSetupUI.checkOnLaunch()` handles the complete setup flow:

1. **Check Claude Code installed** → Skip if not
2. **Validate settings.json** → Show warning if corrupted
3. **Check needsHookUpdate()** → Prompt to update if path changed
4. **Check isHookConfigured()** → Skip if already configured
5. **Check "Don't Ask Again"** → Skip if user opted out
6. **Show install prompt** → Install/Later/Don't Ask Again

This flow ensures:
- Users are prompted to update hooks when app location changes
- "Don't Ask Again" only affects initial install, not updates
- Settings validation catches corruption early

## Notification

Post `.hookConfigurationChanged` when hooks change to update UI:

```swift
extension Notification.Name {
    static let hookConfigurationChanged = Notification.Name("hookConfigurationChanged")
}
```

## License

MIT License - see [LICENSE](LICENSE) for details.
