import Foundation

/// Manages Claude Code hooks for an application
/// Thread-safe via file coordination
/// Marked as Sendable because configuration is immutable and file operations use NSFileCoordinator
public final class HookManager: @unchecked Sendable {
    /// Claude Code settings directory (set at initialization, typically for testing)
    public private(set) var claudeDir: URL

    /// Path to settings.json
    public var settingsPath: URL { claudeDir.appendingPathComponent("settings.json") }

    /// Hook configuration for this app
    public let configuration: HookConfiguration

    /// Custom notifier path provider (for testing)
    private let notifierPathProvider: () -> String?

    /// Create a hook manager with the given configuration
    /// - Parameters:
    ///   - configuration: The hook configuration
    ///   - claudeDir: Override Claude directory (for testing)
    ///   - notifierPathProvider: Custom notifier path provider (for testing)
    public init(
        configuration: HookConfiguration,
        claudeDir: URL? = nil,
        notifierPathProvider: (() -> String?)? = nil
    ) {
        self.configuration = configuration
        self.claudeDir = claudeDir ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        self.notifierPathProvider = notifierPathProvider ?? {
            let bundlePath = Bundle.main.bundlePath
            let notifierPath = "\(bundlePath)/Contents/MacOS/notifier"
            return FileManager.default.fileExists(atPath: notifierPath) ? notifierPath : nil
        }
    }

    // MARK: - Public API

    /// Check if Claude Code is installed (.claude directory exists)
    public func isClaudeCodeInstalled() -> Bool {
        FileManager.default.fileExists(atPath: claudeDir.path)
    }

    /// Validate settings.json and return any error
    /// Returns nil if settings are valid or don't exist yet
    public func validateSettings() -> HookManagerError? {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else {
            return nil // No settings file is fine
        }

        do {
            _ = try readSettings()
            return nil
        } catch let error as HookManagerError {
            return error
        } catch {
            return .settingsUnreadable
        }
    }

    /// Check if this app's hook is configured
    /// Returns false if settings can't be read (file doesn't exist or errors)
    public func isHookConfigured() -> Bool {
        guard let settings = try? readSettings() else { return false }
        return findHookIndex(in: settings) != nil
    }

    /// Check if hook needs update (cleanup required)
    /// Returns true if any of:
    /// - Hook path doesn't match current app bundle
    /// - Multiple hooks exist for this app
    public func needsHookUpdate() -> Bool {
        guard let settings = try? readSettings(),
              let hooks = settings["hooks"] as? [String: Any],
              let hookArray = hooks[configuration.hookType.rawValue] as? [Any]
        else {
            return false
        }

        guard let currentNotifierPath = notifierPathProvider() else {
            return false // Can't update if notifier doesn't exist
        }

        var hookCount = 0
        var hasCorrectPath = false

        for item in hookArray {
            guard let hookEntry = item as? [String: Any] else { continue }

            // For PreToolUse, check matcher first
            if configuration.hookType == .preToolUse {
                guard let matcher = hookEntry["matcher"] as? String,
                      matcher == configuration.matcher
                else {
                    continue
                }
            }

            // Check command in nested hooks array
            if let hooksList = hookEntry["hooks"] as? [[String: Any]] {
                for hook in hooksList {
                    guard let command = hook["command"] as? String else { continue }
                    if isOurHookCommand(command) {
                        hookCount += 1
                        if command == currentNotifierPath {
                            hasCorrectPath = true
                        }
                    }
                }
            }

            // Check flat format (command at top level)
            if let command = hookEntry["command"] as? String, isOurHookCommand(command) {
                hookCount += 1
                if command == currentNotifierPath {
                    hasCorrectPath = true
                }
            }
        }

        // Needs update if: multiple hooks, or no correct path hook exists
        return hookCount > 1 || (hookCount > 0 && !hasCorrectPath)
    }

    /// Clean up and reinstall hook
    /// Removes ALL hooks for this app and installs fresh one
    /// All operations are performed in a single file coordination block
    public func cleanupAndInstallHook() throws {
        guard let notifierPath = notifierPathProvider() else {
            throw HookManagerError.notifierNotFound(appName: configuration.appName)
        }

        try withFileCoordination(writing: true) {
            var settings = try readSettingsOrEmpty()

            // Validate and get hooks object
            if let existing = settings["hooks"], !(existing is [String: Any]) {
                throw HookManagerError.unexpectedStructure
            }
            var hooks = settings["hooks"] as? [String: Any] ?? [:]

            // Get hook array
            let hookTypeKey = configuration.hookType.rawValue
            if let existing = hooks[hookTypeKey], !(existing is [Any]) {
                throw HookManagerError.unexpectedStructure
            }
            var hookArray = hooks[hookTypeKey] as? [Any] ?? []

            // Remove all existing hooks for this app
            let indicesToRemove = findAllHookIndices(hookArray: hookArray)
            for index in indicesToRemove.reversed() {
                hookArray.remove(at: index)
            }

            // Add fresh hook
            let newHook = createHookEntry(notifierPath: notifierPath)
            hookArray.append(newHook)
            hooks[hookTypeKey] = hookArray
            settings["hooks"] = hooks

            try writeSettings(settings)
        }
    }

    /// Install this app's hook into settings.json
    /// Uses merge strategy to preserve existing settings
    /// Thread-safe via file coordination
    public func installHook() throws {
        guard let notifierPath = notifierPathProvider() else {
            throw HookManagerError.notifierNotFound(appName: configuration.appName)
        }

        try withFileCoordination(writing: true) {
            var settings = try readSettingsOrEmpty()

            // Skip if already installed (check within coordination block to avoid TOCTOU)
            if findHookIndex(in: settings) != nil { return }

            // Validate and get hooks object
            if let existing = settings["hooks"], !(existing is [String: Any]) {
                throw HookManagerError.unexpectedStructure
            }
            var hooks = settings["hooks"] as? [String: Any] ?? [:]

            // Get hook array
            let hookTypeKey = configuration.hookType.rawValue
            if let existing = hooks[hookTypeKey], !(existing is [Any]) {
                throw HookManagerError.unexpectedStructure
            }
            var hookArray = hooks[hookTypeKey] as? [Any] ?? []

            // Create and add hook entry
            let newHook = createHookEntry(notifierPath: notifierPath)
            hookArray.append(newHook)
            hooks[hookTypeKey] = hookArray
            settings["hooks"] = hooks

            try writeSettings(settings)
        }
    }

    /// Remove this app's hook from settings.json
    /// Removes ALL matching entries to handle duplicate installations
    /// Thread-safe via file coordination
    public func removeHook() throws {
        try withFileCoordination(writing: true) {
            guard var settings = try readSettings() else { return }

            guard var hooks = settings["hooks"] as? [String: Any],
                  var hookArray = hooks[configuration.hookType.rawValue] as? [Any]
            else {
                return
            }

            // Find and remove ALL hook entries for this app (in reverse order to preserve indices)
            let indicesToRemove = findAllHookIndices(hookArray: hookArray)
            guard !indicesToRemove.isEmpty else { return }

            for index in indicesToRemove.reversed() {
                hookArray.remove(at: index)
            }
            hooks[configuration.hookType.rawValue] = hookArray
            settings["hooks"] = hooks
            try writeSettings(settings)
        }
    }

    // MARK: - Settings File Operations

    /// Read settings, returning nil only if file doesn't exist
    /// Throws error if file exists but can't be read or parsed
    func readSettings() throws -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else {
            return nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: settingsPath)
        } catch {
            throw HookManagerError.settingsUnreadable
        }

        guard let json = try? JSONSerialization.jsonObject(with: data),
              let settings = json as? [String: Any]
        else {
            throw HookManagerError.settingsCorrupted
        }

        return settings
    }

    /// Read settings, returning empty dict if file doesn't exist
    /// Throws error if file exists but can't be read or parsed
    func readSettingsOrEmpty() throws -> [String: Any] {
        try readSettings() ?? [:]
    }

    func writeSettings(_ settings: [String: Any]) throws {
        // Create .claude directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: claudeDir.path) {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        }

        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )

        try data.write(to: settingsPath, options: .atomic)
    }

    // MARK: - Private Helpers

    /// Check if a command string matches any of our hook identifiers
    private func isOurHookCommand(_ command: String) -> Bool {
        let lowercasedCommand = command.lowercased()
        return configuration.hookIdentifiers.contains { identifier in
            lowercasedCommand.contains(identifier.lowercased())
        }
    }

    /// Create a hook entry dictionary for the current configuration
    private func createHookEntry(notifierPath: String) -> [String: Any] {
        var hookCommand: [String: Any] = [
            "command": notifierPath,
            "type": "command",
        ]

        // Add timeout if specified
        if let timeout = configuration.timeout {
            hookCommand["timeout"] = timeout
        }

        var entry: [String: Any] = [
            "hooks": [hookCommand],
        ]

        // Add matcher for PreToolUse hooks
        if let matcher = configuration.matcher {
            entry["matcher"] = matcher
        }

        return entry
    }

    /// Find first hook index for this app
    private func findHookIndex(in settings: [String: Any]) -> Int? {
        guard let hooks = settings["hooks"] as? [String: Any],
              let hookArray = hooks[configuration.hookType.rawValue] as? [Any]
        else {
            return nil
        }
        return findAllHookIndices(hookArray: hookArray).first
    }

    /// Find ALL hook indices for this app in the hook array
    /// Handles both flat format (command at top level) and nested format (command inside hooks array)
    private func findAllHookIndices(hookArray: [Any]) -> [Int] {
        var indices: [Int] = []

        for (index, item) in hookArray.enumerated() {
            // Skip non-dictionary entries
            guard let hookEntry = item as? [String: Any] else { continue }

            // For PreToolUse, check matcher first
            if configuration.hookType == .preToolUse {
                guard let matcher = hookEntry["matcher"] as? String,
                      matcher == configuration.matcher
                else {
                    continue
                }
            }

            // Check flat format: command directly on the entry
            if let command = hookEntry["command"] as? String, isOurHookCommand(command) {
                indices.append(index)
                continue
            }

            // Check nested format: command inside hooks array
            if let nestedHooks = hookEntry["hooks"] as? [[String: Any]] {
                for nestedHook in nestedHooks {
                    if let command = nestedHook["command"] as? String, isOurHookCommand(command) {
                        indices.append(index)
                        break
                    }
                }
            }
        }
        return indices
    }

    /// Execute a block with file coordination for thread safety
    private func withFileCoordination(writing: Bool, block: () throws -> Void) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var blockError: Error?

        let intent: NSFileCoordinator.WritingOptions = writing ? .forMerging : []

        coordinator.coordinate(
            writingItemAt: settingsPath,
            options: intent,
            error: &coordinatorError
        ) { _ in
            do {
                try block()
            } catch {
                blockError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }
        if let error = blockError {
            throw error
        }
    }
}
