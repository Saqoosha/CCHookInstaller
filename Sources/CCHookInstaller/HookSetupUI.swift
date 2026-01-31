import AppKit

/// Result of install prompt dialog
public enum InstallPromptResult: Sendable {
    case install
    case later
    case dontAskAgain
}

/// UI helpers and coordinator for hook setup flow
@MainActor
public enum HookSetupUI {
    // MARK: - Main Entry Point

    /// Check and setup hooks on app launch
    /// Handles the entire flow: validation, update prompts, and installation
    /// - Parameters:
    ///   - hookManager: The hook manager instance
    ///   - messages: App-specific messages for dialogs
    ///   - dontAskAgainKey: UserDefaults key for "Don't Ask Again" preference
    ///   - onConfigurationChanged: Called when hook configuration changes (for posting notifications)
    public static func checkOnLaunch(
        hookManager: HookManager,
        messages: HookSetupMessages,
        dontAskAgainKey: String,
        onConfigurationChanged: @escaping @Sendable () -> Void
    ) {
        // 1. Check if Claude Code is installed
        guard hookManager.isClaudeCodeInstalled() else { return }

        // 2. Validate settings file
        if let error = hookManager.validateSettings() {
            showWarning(title: messages.settingsWarningTitle, message: error.localizedDescription)
            return
        }

        // 3. Check if hook needs update (path changed or duplicates)
        if hookManager.needsHookUpdate() {
            promptUpdate(
                hookManager: hookManager,
                messages: messages,
                onConfigurationChanged: onConfigurationChanged
            )
            return
        }

        // 4. Already correctly configured - nothing to do
        guard !hookManager.isHookConfigured() else { return }

        // 5. Check "Don't Ask Again" preference
        guard !UserDefaults.standard.bool(forKey: dontAskAgainKey) else { return }

        // 6. Show install prompt
        promptInstall(
            hookManager: hookManager,
            messages: messages,
            dontAskAgainKey: dontAskAgainKey,
            onConfigurationChanged: onConfigurationChanged
        )
    }

    // MARK: - Flow Steps

    private static func promptUpdate(
        hookManager: HookManager,
        messages: HookSetupMessages,
        onConfigurationChanged: @escaping @Sendable () -> Void
    ) {
        guard showUpdatePrompt(title: messages.updatePromptTitle, message: messages.updatePromptMessage) else {
            return
        }

        do {
            try hookManager.cleanupAndInstallHook()
            onConfigurationChanged()
            showSuccess(title: messages.updateSuccessTitle, message: messages.updateSuccessMessage)
        } catch {
            showError(error)
        }
    }

    private static func promptInstall(
        hookManager: HookManager,
        messages: HookSetupMessages,
        dontAskAgainKey: String,
        onConfigurationChanged: @escaping @Sendable () -> Void
    ) {
        switch showInstallPrompt(title: messages.installPromptTitle, message: messages.installPromptMessage) {
        case .install:
            do {
                try hookManager.installHook()
                onConfigurationChanged()
                showSuccess(title: messages.successTitle, message: messages.successMessage)
            } catch {
                showError(error)
            }
        case .dontAskAgain:
            UserDefaults.standard.set(true, forKey: dontAskAgainKey)
        case .later:
            break
        }
    }

    // MARK: - Alert Helpers

    /// Show an error alert
    public static func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to Configure Hooks"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Show a success alert
    public static func showSuccess(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Show a warning alert
    public static func showWarning(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Show install confirmation with Install/Later/Don't Ask Again buttons
    public static func showInstallPrompt(title: String, message: String) -> InstallPromptResult {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Don't Ask Again")

        switch alert.runModal() {
        case .alertFirstButtonReturn: return .install
        case .alertThirdButtonReturn: return .dontAskAgain
        default: return .later
        }
    }

    /// Show update confirmation with Update/Later buttons
    /// Returns true if user confirmed
    public static func showUpdatePrompt(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Later")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Show remove confirmation with Remove/Cancel buttons
    /// Returns true if user confirmed
    public static func showRemovePrompt(title: String, message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
