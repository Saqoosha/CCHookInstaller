import Foundation
import Testing

@testable import CCHookInstaller

@Suite
struct HookManagerTests {
    // Test directory for each test
    let testDir: URL

    init() throws {
        testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("HookManagerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }

    func createManager(
        configuration: HookConfiguration,
        notifierPath: String? = "/TestApp.app/Contents/MacOS/notifier",
        claudeDir: URL? = nil
    ) -> HookManager {
        HookManager(
            configuration: configuration,
            claudeDir: claudeDir ?? testDir,
            notifierPathProvider: { notifierPath }
        )
    }

    // MARK: - UserPromptSubmit Tests

    @Test
    func userPromptSubmit_isClaudeCodeInstalled_returnsFalse_whenDirectoryMissing() throws {
        // Create manager with a non-existent directory
        let nonExistentDir = testDir.appendingPathComponent("nonexistent-\(UUID().uuidString)")
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            ),
            claudeDir: nonExistentDir
        )

        #expect(!manager.isClaudeCodeInstalled())
    }

    @Test
    func userPromptSubmit_isClaudeCodeInstalled_returnsTrue_whenDirectoryExists() {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        #expect(manager.isClaudeCodeInstalled())
    }

    @Test
    func userPromptSubmit_isHookConfigured_returnsFalse_whenNoSettingsFile() {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        #expect(!manager.isHookConfigured())
    }

    @Test
    func userPromptSubmit_isHookConfigured_returnsFalse_whenNoHook() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        let settings: [String: Any] = ["hooks": ["UserPromptSubmit": []]]
        try writeSettings(settings, to: manager.settingsPath)

        #expect(!manager.isHookConfigured())
    }

    @Test
    func userPromptSubmit_isHookConfigured_returnsTrue_whenHookExists() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        let settings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    [
                        "hooks": [
                            ["command": "/path/to/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ]
                    ]
                ]
            ]
        ]
        try writeSettings(settings, to: manager.settingsPath)

        #expect(manager.isHookConfigured())
    }

    @Test
    func userPromptSubmit_installHook_createsSettingsFile() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        try manager.installHook()

        #expect(FileManager.default.fileExists(atPath: manager.settingsPath.path))
        #expect(manager.isHookConfigured())
    }

    @Test
    func userPromptSubmit_installHook_preservesExistingSettings() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        let existingSettings: [String: Any] = [
            "customSetting": "value",
            "hooks": [
                "SomeOtherHook": [["command": "other-command"]]
            ],
        ]
        try writeSettings(existingSettings, to: manager.settingsPath)

        try manager.installHook()

        let settings = try manager.readSettings()!
        #expect(settings["customSetting"] as? String == "value")
        let hooks = settings["hooks"] as! [String: Any]
        #expect(hooks["SomeOtherHook"] != nil)
        #expect(manager.isHookConfigured())
    }

    @Test
    func userPromptSubmit_removeHook_removesHookEntry() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        try manager.installHook()
        #expect(manager.isHookConfigured())

        try manager.removeHook()
        #expect(!manager.isHookConfigured())
    }

    // MARK: - PreToolUse Tests

    @Test
    func preToolUse_isHookConfigured_returnsFalse_whenMatcherDiffers() throws {
        let manager = createManager(
            configuration: .preToolUse(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"],
                matcher: "ExitPlanMode",
                timeout: 10
            )
        )

        let settings: [String: Any] = [
            "hooks": [
                "PreToolUse": [
                    [
                        "matcher": "DifferentMatcher",
                        "hooks": [
                            ["command": "/path/to/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ],
                    ]
                ]
            ]
        ]
        try writeSettings(settings, to: manager.settingsPath)

        #expect(!manager.isHookConfigured())
    }

    @Test
    func preToolUse_isHookConfigured_returnsTrue_whenMatcherAndCommandMatch() throws {
        let manager = createManager(
            configuration: .preToolUse(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"],
                matcher: "ExitPlanMode",
                timeout: 10
            )
        )

        let settings: [String: Any] = [
            "hooks": [
                "PreToolUse": [
                    [
                        "matcher": "ExitPlanMode",
                        "hooks": [
                            ["command": "/path/to/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ],
                    ]
                ]
            ]
        ]
        try writeSettings(settings, to: manager.settingsPath)

        #expect(manager.isHookConfigured())
    }

    @Test
    func preToolUse_installHook_includesMatcherAndTimeout() throws {
        let manager = createManager(
            configuration: .preToolUse(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"],
                matcher: "ExitPlanMode",
                timeout: 10
            )
        )

        try manager.installHook()

        let settings = try manager.readSettings()!
        let hooks = settings["hooks"] as! [String: Any]
        let preToolUse = hooks["PreToolUse"] as! [[String: Any]]
        let hookEntry = preToolUse.first!

        #expect(hookEntry["matcher"] as? String == "ExitPlanMode")

        let nestedHooks = hookEntry["hooks"] as! [[String: Any]]
        let command = nestedHooks.first!
        #expect(command["timeout"] as? Int == 10)
    }

    // MARK: - needsHookUpdate Tests

    @Test
    func needsHookUpdate_returnsFalse_whenNoHookExists() {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        #expect(!manager.needsHookUpdate())
    }

    @Test
    func needsHookUpdate_returnsFalse_whenPathMatches() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            ),
            notifierPath: "/TestApp.app/Contents/MacOS/notifier"
        )

        let settings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    [
                        "hooks": [
                            ["command": "/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ]
                    ]
                ]
            ]
        ]
        try writeSettings(settings, to: manager.settingsPath)

        #expect(!manager.needsHookUpdate())
    }

    @Test
    func needsHookUpdate_returnsTrue_whenPathDiffers() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            ),
            notifierPath: "/NewPath/TestApp.app/Contents/MacOS/notifier"
        )

        let settings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    [
                        "hooks": [
                            ["command": "/OldPath/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ]
                    ]
                ]
            ]
        ]
        try writeSettings(settings, to: manager.settingsPath)

        #expect(manager.needsHookUpdate())
    }

    @Test
    func needsHookUpdate_returnsTrue_whenMultipleHooksExist() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            ),
            notifierPath: "/TestApp.app/Contents/MacOS/notifier"
        )

        let settings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    [
                        "hooks": [
                            ["command": "/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ]
                    ],
                    [
                        "hooks": [
                            ["command": "/Another/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ]
                    ],
                ]
            ]
        ]
        try writeSettings(settings, to: manager.settingsPath)

        #expect(manager.needsHookUpdate())
    }

    // MARK: - cleanupAndInstallHook Tests

    @Test
    func cleanupAndInstallHook_removesAllAndInstallsFresh() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            ),
            notifierPath: "/NewPath/TestApp.app/Contents/MacOS/notifier"
        )

        // Set up multiple existing hooks
        let settings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    [
                        "hooks": [
                            ["command": "/OldPath1/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ]
                    ],
                    [
                        "hooks": [
                            ["command": "/OldPath2/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ]
                    ],
                ]
            ]
        ]
        try writeSettings(settings, to: manager.settingsPath)

        try manager.cleanupAndInstallHook()

        let newSettings = try manager.readSettings()!
        let hooks = newSettings["hooks"] as! [String: Any]
        let userPromptSubmit = hooks["UserPromptSubmit"] as! [[String: Any]]

        // Should have exactly one hook with the new path
        #expect(userPromptSubmit.count == 1)
        let nestedHooks = userPromptSubmit[0]["hooks"] as! [[String: Any]]
        #expect(nestedHooks[0]["command"] as? String == "/NewPath/TestApp.app/Contents/MacOS/notifier")
    }

    // MARK: - Error Handling Tests

    @Test
    func readSettings_throwsCorrupted_whenInvalidJSON() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        try "not valid json".write(to: manager.settingsPath, atomically: true, encoding: .utf8)

        #expect(throws: HookManagerError.settingsCorrupted) {
            _ = try manager.readSettings()
        }
    }

    @Test
    func installHook_throwsNotifierNotFound_whenNotifierMissing() {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            ),
            notifierPath: nil
        )

        #expect(throws: HookManagerError.notifierNotFound(appName: "TestApp")) {
            try manager.installHook()
        }
    }

    @Test
    func installHook_throwsUnexpectedStructure_whenHooksNotDict() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        let settings: [String: Any] = ["hooks": "not a dictionary"]
        try writeSettings(settings, to: manager.settingsPath)

        #expect(throws: HookManagerError.unexpectedStructure) {
            try manager.installHook()
        }
    }

    // MARK: - Mixed Array Tests

    @Test
    func isHookConfigured_handlesNonDictionaryEntries() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        // Settings with mixed types in array
        let settings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    "a string",
                    123,
                    [
                        "hooks": [
                            ["command": "/path/to/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ]
                    ],
                ]
            ]
        ]
        try writeSettings(settings, to: manager.settingsPath)

        #expect(manager.isHookConfigured())
    }

    @Test
    func removeHook_preservesNonDictionaryEntries() throws {
        let manager = createManager(
            configuration: .userPromptSubmit(
                appName: "TestApp",
                hookIdentifiers: ["TestApp.app/"]
            )
        )

        let settings: [String: Any] = [
            "hooks": [
                "UserPromptSubmit": [
                    "a string",
                    [
                        "hooks": [
                            ["command": "/path/to/TestApp.app/Contents/MacOS/notifier", "type": "command"]
                        ]
                    ],
                ]
            ]
        ]
        try writeSettings(settings, to: manager.settingsPath)

        try manager.removeHook()

        let newSettings = try manager.readSettings()!
        let hooks = newSettings["hooks"] as! [String: Any]
        let userPromptSubmit = hooks["UserPromptSubmit"] as! [Any]

        // String entry should still be there, hook entry should be removed
        #expect(userPromptSubmit.count == 1)
        #expect(userPromptSubmit[0] as? String == "a string")
    }

    // MARK: - Coexistence Tests

    @Test
    func multipleAppsCanCoexist_inSameSettingsFile() throws {
        // Create two managers with different configurations
        let userPromptManager = createManager(
            configuration: .userPromptSubmit(
                appName: "CCLangTutor",
                hookIdentifiers: ["CCLangTutor.app/"]
            ),
            notifierPath: "/path/to/CCLangTutor.app/Contents/MacOS/notifier"
        )

        let preToolUseManager = HookManager(
            configuration: .preToolUse(
                appName: "CCPlanView",
                hookIdentifiers: ["CCPlanView.app/"],
                matcher: "ExitPlanMode",
                timeout: 10
            ),
            claudeDir: testDir,
            notifierPathProvider: { "/path/to/CCPlanView.app/Contents/MacOS/notifier" }
        )

        // Install both hooks
        try userPromptManager.installHook()
        try preToolUseManager.installHook()

        // Both should be configured
        #expect(userPromptManager.isHookConfigured())
        #expect(preToolUseManager.isHookConfigured())

        // Verify settings structure
        let settings = try userPromptManager.readSettings()!
        let hooks = settings["hooks"] as! [String: Any]

        let userPromptSubmit = hooks["UserPromptSubmit"] as! [[String: Any]]
        let preToolUse = hooks["PreToolUse"] as! [[String: Any]]

        #expect(userPromptSubmit.count == 1)
        #expect(preToolUse.count == 1)

        // Remove one, the other should remain
        try userPromptManager.removeHook()
        #expect(!userPromptManager.isHookConfigured())
        #expect(preToolUseManager.isHookConfigured())

        // Remove the other
        try preToolUseManager.removeHook()
        #expect(!preToolUseManager.isHookConfigured())
    }

    // MARK: - Helpers

    private func writeSettings(_ settings: [String: Any], to path: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted])
        try data.write(to: path)
    }
}
