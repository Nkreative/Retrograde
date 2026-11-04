import Foundation
import Testing
@testable import Notifications

@MainActor
private func freshDefaults() throws -> (UserDefaults, () -> Void) {
    let suite = "notifications-\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    return (defaults, { defaults.removePersistentDomain(forName: suite) })
}

@MainActor
@Suite struct NotificationPreferencesTests {
    @Test func approvedDefaults() throws {
        let (defaults, cleanup) = try freshDefaults(); defer { cleanup() }
        let prefs = NotificationPreferences(defaults: defaults)
        #expect(prefs.enabled == [.mercuryTurnsRetrograde, .mercuryTurnsDirect, .beforeMercuryRetrograde, .newCycleTasks])
        #expect(NotificationKind.leadTimes == [DateComponents(day: 14), DateComponents(day: 3)])
    }

    @Test func savedChoicesSurviveRelaunch() throws {
        let (defaults, cleanup) = try freshDefaults(); defer { cleanup() }
        NotificationPreferences(defaults: defaults).save([.beforeMercuryDirect, .unfinishedTasks])
        #expect(NotificationPreferences(defaults: defaults).enabled == [.beforeMercuryDirect, .unfinishedTasks])
        NotificationPreferences(defaults: defaults).save([])
        #expect(NotificationPreferences(defaults: defaults).enabled.isEmpty) // all-off isn't reset to defaults
    }

    @Test func migratesTheFirstVersionWithoutResettingChoices() throws {
        let (defaults, cleanup) = try freshDefaults(); defer { cleanup() }
        // The person had turned "retrograde starts" off and daily guidance on.
        defaults.set(["retrogradeEnds", "dailyGuidance"], forKey: NotificationPreferences.legacyKey)
        let prefs = NotificationPreferences(defaults: defaults)
        #expect(!prefs.isEnabled(.mercuryTurnsRetrograde)) // their "off" kept
        #expect(prefs.isEnabled(.mercuryTurnsDirect))
        #expect(prefs.isEnabled(.beforeMercuryRetrograde) && prefs.isEnabled(.newCycleTasks)) // new options at defaults
        #expect(defaults.array(forKey: NotificationPreferences.legacyKey) == nil)
        #expect(NotificationPreferences(defaults: defaults).enabled == prefs.enabled) // migrated once, then saved
    }

    #if canImport(UserNotifications)
    @Test func authorizationStates() {
        #expect(NotificationAuthorization(.notDetermined) == .notDetermined)
        #expect(NotificationAuthorization(.denied) == .denied)
        #expect(NotificationAuthorization(.authorized) == .allowed)
        #expect(NotificationAuthorization(.provisional) == .allowed)
    }
    #endif
}

@MainActor
@Suite struct NotificationHistoryTests {
    final class Clock { var now = Date(timeIntervalSince1970: 1_793_750_400) }

    private func record(_ id: String, firesIn seconds: TimeInterval, _ clock: Clock) -> NotificationRecord {
        NotificationRecord(id: id, kind: .mercuryTurnsDirect, title: "Mercury turns direct", body: "…",
                           fireDate: clock.now + seconds, destination: .calendarDay("2026-11-13"))
    }

    @Test func emptyByDefault() {
        let history = NotificationHistory(defaults: nil)
        #expect(history.visible.isEmpty && history.unreadCount == 0)
    }

    @Test func futureAlertsStayHiddenUntilTheirTime() {
        let clock = Clock()
        let history = NotificationHistory(defaults: nil, now: { clock.now })
        history.record(record("a", firesIn: 3_600, clock))
        #expect(history.visible.isEmpty)
        clock.now += 3_600
        #expect(history.visible.map(\.id) == ["a"] && history.unreadCount == 1)
        #expect(history.visible[0].delivery(at: clock.now) == .due) // not claimed as received
    }

    @Test func deliveryIsOnlyConfirmedWhenReported() {
        let clock = Clock()
        let history = NotificationHistory(defaults: nil, now: { clock.now })
        history.record(record("a", firesIn: -10, clock))
        #expect(history.records[0].delivery(at: clock.now) == .due)
        history.confirmDelivery(id: "a")
        #expect(history.records[0].delivery(at: clock.now) == .delivered)
    }

    @Test func reschedulingNeverDuplicatesAndKeepsReadState() {
        let clock = Clock()
        let history = NotificationHistory(defaults: nil, now: { clock.now })
        history.record(record("a", firesIn: -60, clock))
        history.markRead(id: "a")
        history.record(record("a", firesIn: -30, clock)) // re-recorded on relaunch / reschedule
        #expect(history.records.count == 1)
        #expect(history.records[0].isRead)
    }

    @Test func newestFirstAndMarkAllRead() {
        let clock = Clock()
        let history = NotificationHistory(defaults: nil, now: { clock.now })
        history.record(record("old", firesIn: -7_200, clock))
        history.record(record("new", firesIn: -60, clock))
        history.record(record("later", firesIn: 60, clock))
        #expect(history.visible.map(\.id) == ["new", "old"])
        history.markRead(id: "old")
        #expect(history.unreadCount == 1)
        history.markAllRead()
        #expect(history.unreadCount == 0)
        clock.now += 120
        #expect(history.unreadCount == 1) // "later" arrives unread
    }

    @Test func cancelOnlyRemovesNotYetDueEntries() {
        let clock = Clock()
        let history = NotificationHistory(defaults: nil, now: { clock.now })
        history.record(record("past", firesIn: -60, clock))
        history.record(record("future", firesIn: 60, clock))
        history.cancel(id: "past")
        history.cancel(id: "future")
        #expect(history.records.map(\.id) == ["past"])
    }

    @Test func persistsAcrossRelaunch() throws {
        let (defaults, cleanup) = try freshDefaults(); defer { cleanup() }
        let clock = Clock()
        let history = NotificationHistory(defaults: defaults, now: { clock.now })
        history.record(record("a", firesIn: -60, clock))
        history.markRead(id: "a")
        let relaunched = NotificationHistory(defaults: defaults, now: { clock.now })
        #expect(relaunched.records.count == 1 && relaunched.records[0].isRead)
        #expect(relaunched.records[0].destination == .calendarDay("2026-11-13"))
    }
}
