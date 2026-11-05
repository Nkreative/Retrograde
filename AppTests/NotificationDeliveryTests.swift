#if os(iOS)
import Foundation
@testable import Notifications
import RetroCore
import Testing
import UserNotifications
@testable import Retrograde

/// Tapped notifications: where they lead, including when the tap launches the app.
@MainActor
@Suite struct NotificationTapTests {
    @Test func tapOpensTheCalendarOnTheEventDay() {
        let responder = NotificationResponder.shared
        let history = NotificationHistory(defaults: nil, now: { Date(timeIntervalSince1970: 2_000_000_000) })
        history.record(NotificationRecord(id: "mercury-2026-10-24.direct", kind: .mercuryTurnsDirect, title: "t", body: "b",
                                          fireDate: Date(timeIntervalSince1970: 1_900_000_000)))
        responder.history = history
        defer { responder.history = nil; responder.routes.pending = nil }

        responder.opened(id: "mercury-2026-10-24.direct", destination: "calendarDay:2026-11-13")
        #expect(responder.routes.pending == .calendarDay("2026-11-13"))
        // Opening it confirms delivery and marks it read: no unread dot for something already seen.
        #expect(history.records[0].delivery(at: .now) == .delivered && history.records[0].isRead)

        let router = AppRouter(tab: .overview)
        router.open(responder.routes.pending!)
        #expect(router.tab == .calendar && router.calendarFocus == CalendarDay(year: 2026, month: 11, day: 13))
    }

    @Test func kitNotificationsOpenTheSurvivalKit() {
        let router = AppRouter(tab: .calendar)
        router.showsSettings = true
        router.open(.survivalKit)
        #expect(router.tab == .survivalKit && !router.showsSettings)
    }

    /// Cold launch: iOS hands over the tap before any screen exists; the destination waits, then
    /// the main screen opens it.
    @Test func coldLaunchTapWaitsForTheMainScreen() {
        let responder = NotificationResponder.shared
        defer { responder.routes.pending = nil }
        responder.opened(id: "unknown-to-history", destination: "survivalKit")
        #expect(responder.routes.pending == .survivalKit) // kept until MainTabView appears
    }

    @Test func unknownDestinationsAreIgnored() {
        let responder = NotificationResponder.shared
        responder.routes.pending = nil
        responder.opened(id: "x", destination: "somewhere-else")
        responder.opened(id: "y", destination: nil)
        #expect(responder.routes.pending == nil)
    }
}

/// Against iOS's real notification center. iOS refuses to store alerts until the person has
/// allowed notifications (UNErrorDomain 2003), and no tool can grant that on a simulator — so the
/// first test runs everywhere, and the rest run only where notifications are allowed (a device,
/// or a simulator where someone tapped Allow); elsewhere they're reported as skipped.
@MainActor
@Suite(.serialized) struct SystemNotificationCenterTests {
    let center = UNUserNotificationCenter.current()
    let system = SystemNotificationCenter()

    static func allowed() async -> Bool { await SystemNotificationCenter().authorization().canDeliver }

    private func planned(_ id: String, in seconds: TimeInterval, destination: NotificationDestination = .survivalKit) -> PlannedNotification {
        PlannedNotification(id: id, kind: .newCycleTasks, title: "Your survival kit is ready.", body: "A little preparation never hurt anyone.",
                            fireDate: Date.now.addingTimeInterval(seconds).rounded(), destination: destination)
    }

    @Test func withoutPermissionNothingIsScheduledOrRecorded() async throws {
        guard await !Self.allowed() else { return } // covered by the tests below on an allowed device
        await #expect(throws: (any Error).self) { try await system.schedule(planned("test.refused", in: 3_600), calendar: .current) }
        let history = NotificationHistory(defaults: nil)
        let scheduler = NotificationScheduler(center: system, history: history) {
            guard let ephemeris = SkyData.ephemeris else { return nil }
            return .init(planner: NotificationPlanner(periods: ephemeris.retrogrades, calendar: .current),
                         enabled: NotificationPreferences.defaults, remainingTasks: { _ in 4 }, now: .now)
        }
        await scheduler.refresh()
        #expect(history.records.isEmpty && scheduler.scheduled.isEmpty)
        #expect(await system.pendingIDs().isEmpty)
    }

    @Test(.enabled { await SystemNotificationCenterTests.allowed() })
    func schedulesAtTheLocalWallClockTimeWithItsDestination() async throws {
        defer { center.removeAllPendingNotificationRequests() }
        let alert = planned("test.kit.ready", in: 86_400, destination: .calendarDay("2026-11-13"))
        try await system.schedule(alert, calendar: .current)
        let request = try #require(await center.pendingNotificationRequests().first { $0.identifier == alert.id })
        let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.nextTriggerDate() == alert.fireDate)
        #expect(!trigger.repeats)
        #expect(request.content.title == alert.title && request.content.body == alert.body)
        #expect(request.content.userInfo[NotificationDestination.userInfoKey] as? String == "calendarDay:2026-11-13")
    }

    @Test(.enabled { await SystemNotificationCenterTests.allowed() })
    func sameIDReplacesInsteadOfDuplicating() async throws {
        defer { center.removeAllPendingNotificationRequests() }
        try await system.schedule(planned("test.same", in: 3_600), calendar: .current)
        try await system.schedule(planned("test.same", in: 7_200), calendar: .current)
        #expect(await system.pendingIDs().filter { $0 == "test.same" }.count == 1)
        await system.removePending(ids: ["test.same"])
        #expect(await !system.pendingIDs().contains("test.same"))
    }

    /// The limit the planner stays under: iOS keeps only the soonest 64 pending alerts per app.
    @Test(.enabled { await SystemNotificationCenterTests.allowed() })
    func iOSKeepsAtMost64Pending() async throws {
        defer { center.removeAllPendingNotificationRequests() }
        for i in 0..<70 { try await system.schedule(planned("test.limit.\(i)", in: 3_600 + Double(i) * 60), calendar: .current) }
        #expect(await system.pendingIDs().count <= 64)
        #expect(NotificationPlanner.pendingLimit < 64)
    }
}

private extension Date {
    /// Whole seconds: calendar triggers fire on second boundaries.
    func rounded() -> Date { Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.rounded(.up)) }
}
#endif
