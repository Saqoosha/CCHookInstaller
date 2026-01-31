import Foundation

/// Errors that can occur during hook management
public enum HookManagerError: LocalizedError, Equatable, Sendable {
    case settingsCorrupted
    case settingsUnreadable
    case unexpectedStructure
    case notifierNotFound(appName: String)

    public var errorDescription: String? {
        switch self {
        case .settingsCorrupted:
            return "Claude Code settings.json is corrupted or not valid JSON."
        case .settingsUnreadable:
            return "Could not read Claude Code settings.json. Check file permissions."
        case .unexpectedStructure:
            return "Claude Code settings.json has unexpected structure."
        case let .notifierNotFound(appName):
            return "Could not find \(appName) app bundle or notifier CLI."
        }
    }
}
