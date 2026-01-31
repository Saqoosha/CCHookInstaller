import Foundation

/// Messages used during hook setup flow
public struct HookSetupMessages: Sendable {
    public let installPromptTitle: String
    public let installPromptMessage: String
    public let updatePromptTitle: String
    public let updatePromptMessage: String
    public let successTitle: String
    public let successMessage: String
    public let updateSuccessTitle: String
    public let updateSuccessMessage: String
    public let settingsWarningTitle: String

    public init(
        installPromptTitle: String = "Setup Claude Code Hooks?",
        installPromptMessage: String,
        updatePromptTitle: String = "Update Claude Code Hook?",
        updatePromptMessage: String,
        successTitle: String = "Hooks Installed",
        successMessage: String,
        updateSuccessTitle: String = "Hook Updated",
        updateSuccessMessage: String,
        settingsWarningTitle: String = "Claude Code Settings Warning"
    ) {
        self.installPromptTitle = installPromptTitle
        self.installPromptMessage = installPromptMessage
        self.updatePromptTitle = updatePromptTitle
        self.updatePromptMessage = updatePromptMessage
        self.successTitle = successTitle
        self.successMessage = successMessage
        self.updateSuccessTitle = updateSuccessTitle
        self.updateSuccessMessage = updateSuccessMessage
        self.settingsWarningTitle = settingsWarningTitle
    }
}
