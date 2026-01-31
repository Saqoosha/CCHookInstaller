import Foundation

/// Type of Claude Code hook
public enum HookType: String, Sendable {
    case userPromptSubmit = "UserPromptSubmit"
    case preToolUse = "PreToolUse"
}

/// Configuration for a Claude Code hook
public struct HookConfiguration: Sendable {
    /// The type of hook (UserPromptSubmit or PreToolUse)
    public let hookType: HookType

    /// Identifiers used to detect this app's hook in settings
    /// Multiple patterns allow for flexible detection (e.g., different install paths)
    public let hookIdentifiers: [String]

    /// Matcher for PreToolUse hooks (e.g., "ExitPlanMode")
    /// Only used when hookType is .preToolUse
    public let matcher: String?

    /// Timeout in seconds for hook execution
    /// Only used when hookType is .preToolUse
    public let timeout: Int?

    /// App name for error messages
    public let appName: String

    /// Create a configuration for UserPromptSubmit hook
    public static func userPromptSubmit(
        appName: String,
        hookIdentifiers: [String]
    ) -> HookConfiguration {
        HookConfiguration(
            hookType: .userPromptSubmit,
            hookIdentifiers: hookIdentifiers,
            matcher: nil,
            timeout: nil,
            appName: appName
        )
    }

    /// Create a configuration for PreToolUse hook
    public static func preToolUse(
        appName: String,
        hookIdentifiers: [String],
        matcher: String,
        timeout: Int = 10
    ) -> HookConfiguration {
        HookConfiguration(
            hookType: .preToolUse,
            hookIdentifiers: hookIdentifiers,
            matcher: matcher,
            timeout: timeout,
            appName: appName
        )
    }
}
