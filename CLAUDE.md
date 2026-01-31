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

This package is published on GitHub and used by:
- CCLangTutor (XcodeGen project)
- CCPlanView (XcodeGen project)

Both projects reference it via GitHub URL in their `project.yml`:
```yaml
packages:
  CCHookInstaller:
    url: https://github.com/Saqoosha/CCHookInstaller
    from: 1.0.0
```

## Local Development Workflow

When developing CCHookInstaller alongside CCLangTutor or CCPlanView:

```bash
# 1. In the app project (CCLangTutor/CCPlanView), ignore local project.yml changes
git update-index --assume-unchanged project.yml

# 2. Edit project.yml to use local path temporarily
# packages:
#   CCHookInstaller:
#     path: ../CCHookInstaller

# 3. Develop and build normally - changes to CCHookInstaller are reflected immediately

# 4. When done with CCHookInstaller changes:
#    - Commit and push CCHookInstaller
#    - Create a new version tag (e.g., v1.1.0)
#    - jj bookmark create main -r @ && jj git push --bookmark main
#    - git tag v1.1.0 && git push --tags

# 5. Revert project.yml to use remote URL with new version

# 6. Stop ignoring project.yml and commit
git update-index --no-assume-unchanged project.yml
git add project.yml && git commit -m "Bump CCHookInstaller to v1.1.0"
```

**Note:** This workflow keeps project.yml pointing to GitHub URL in commits, so CCPlanView (which is public) remains buildable by others.

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
