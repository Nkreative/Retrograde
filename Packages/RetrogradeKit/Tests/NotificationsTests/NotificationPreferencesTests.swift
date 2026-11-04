import Foundation
import Testing
@testable import Notifications

@MainActor
@Suite struct NotificationPreferencesTests {
    private func freshDefaults() throws -> (UserDefaults, String) {
        let suite = "notification-prefs-\(UUID())"
        return (try #require(UserDefaults(suiteName: suite)), suite)
    }

    @Test func defaultsForAFreshInstall() throws {
        let (defaults, suite) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = NotificationPreferences(defaults: defaults)
        #expect(prefs.isEnabled(.retrogradeStarts) && prefs.isEnabled(.retrogradeEnds))
        #expect(!prefs.isEnabled(.dailyGuidance))
    }

    @Test func choicesSurviveRelaunch() throws {
        let (defaults, suite) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = NotificationPreferences(defaults: defaults)
        prefs.set(.retrogradeStarts, false)
        prefs.set(.dailyGuidance, true)
        let relaunched = NotificationPreferences(defaults: defaults)
        #expect(relaunched.enabled == [.retrogradeEnds, .dailyGuidance])
    }

    @Test func turningEverythingOffIsRemembered() throws {
        let (defaults, suite) = try freshDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let prefs = NotificationPreferences(defaults: defaults)
        NotificationKind.allCases.forEach { prefs.set($0, false) }
        #expect(NotificationPreferences(defaults: defaults).enabled.isEmpty) // not reset to defaults
    }
}
