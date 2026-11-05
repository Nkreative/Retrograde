import AstroData
import Foundation
import RetroCore
import Testing
@testable import Notifications

/// Stands in for iOS: remembers pending and delivered alerts. Like iOS it has no way to ask for
/// permission, so the scheduler can't prompt.
actor FakeNotificationCenter: LocalNotificationCenter {
    var status: NotificationAuthorization
    private(set) var pending: [String: PlannedNotification] = [:]
    var delivered: [String] = []
    private(set) var addCount = 0

    init(_ status: NotificationAuthorization) { self.status = status }

    func set(_ status: NotificationAuthorization) { self.status = status }
    func deliver(_ id: String) { pending[id] = nil; delivered.append(id) }

    func authorization() async -> NotificationAuthorization { status }
    func pendingIDs() async -> [String] { Array(pending.keys) }
    func deliveredIDs() async -> [String] { delivered }
    func schedule(_ notification: PlannedNotification, calendar: Calendar) async throws {
        pending[notification.id] = notification
        addCount += 1
    }
    func removePending(ids: [String]) async { ids.forEach { pending[$0] = nil } }
}

@MainActor
@Suite struct NotificationSchedulerTests {
    let mercury: [RetrogradePeriod]
    var period: RetrogradePeriod { mercury[1] }

    init() throws {
        mercury = try BundledEphemeris.load().retrogrades.filter { $0.planet == .mercury }
    }

    @MainActor private final class Box { var enabled = NotificationPreferences.defaults; var remaining = 4; var now = Date() }

    private func make(_ status: NotificationAuthorization) -> (FakeNotificationCenter, NotificationHistory, NotificationScheduler, Box) {
        let center = FakeNotificationCenter(status)
        let box = Box()
        box.now = period.stationRetrograde - 20 * 86_400
        let history = NotificationHistory(defaults: nil, now: { box.now })
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let periods = mercury
        let scheduler = NotificationScheduler(center: center, history: history) {
            .init(planner: NotificationPlanner(periods: periods, calendar: utc), enabled: box.enabled,
                  remainingTasks: { _ in box.remaining }, now: box.now)
        }
        return (center, history, scheduler, box)
    }

    @Test(arguments: [NotificationAuthorization.denied, .notDetermined])
    func nothingScheduledWithoutPermission(_ status: NotificationAuthorization) async {
        let (center, history, scheduler, _) = make(status)
        await scheduler.refresh()
        #expect(await center.pending.isEmpty)
        #expect(history.records.isEmpty)
        #expect(scheduler.scheduled.isEmpty)
    }

    @Test(arguments: [NotificationAuthorization.allowed, .provisional])
    func schedulesThePlanWhenAllowed(_ status: NotificationAuthorization) async {
        let (center, history, scheduler, _) = make(status)
        await scheduler.refresh()
        let pending = await center.pending
        #expect(!pending.isEmpty && pending.count <= NotificationPlanner.pendingLimit)
        #expect(Set(history.records.map(\.id)) == Set(pending.keys))
        #expect(history.visible.isEmpty) // all in the future: nothing in the Notification Center yet
    }

    @Test func rerunsDontDuplicate() async {
        let (center, history, scheduler, _) = make(.allowed)
        await scheduler.refresh()
        let first = await center.pending.keys.sorted()
        await scheduler.refresh()
        await scheduler.refresh()
        #expect(await center.pending.keys.sorted() == first)
        #expect(history.records.count == first.count)
    }

    @Test func turningAPreferenceOffCancelsItsAlerts() async {
        let (center, history, scheduler, box) = make(.allowed)
        await scheduler.refresh()
        #expect(await center.pending.values.contains { $0.kind == .beforeMercuryRetrograde })
        box.enabled.remove(.beforeMercuryRetrograde)
        await scheduler.refresh()
        #expect(await !center.pending.values.contains { $0.kind == .beforeMercuryRetrograde })
        #expect(!history.records.contains { $0.kind == .beforeMercuryRetrograde })
        // …and back on: rescheduled under the same ids.
        box.enabled.insert(.beforeMercuryRetrograde)
        await scheduler.refresh()
        #expect(await center.pending.keys.contains("\(period.id).retrograde.lead-3d"))
    }

    @Test func revokingPermissionClearsPendingButKeepsThePast() async {
        let (center, history, scheduler, box) = make(.allowed)
        await scheduler.refresh()
        let lead = "\(period.id).retrograde.lead-14d"
        box.now = history.records.first { $0.id == lead }!.fireDate + 60 // its time has passed
        await center.deliver(lead)
        await center.set(.denied)
        await scheduler.refresh()
        #expect(await center.pending.isEmpty)
        #expect(history.records.map(\.id) == [lead]) // the past entry stays; future ones are gone
    }

    @Test func deliveryIsOnlyWhatIOSReports() async {
        let (center, history, scheduler, box) = make(.allowed)
        box.enabled = [.beforeMercuryRetrograde]
        await scheduler.refresh()
        let lead14 = "\(period.id).retrograde.lead-14d", lead3 = "\(period.id).retrograde.lead-3d"
        box.now = history.records.first { $0.id == lead3 }!.fireDate + 60 // both are now past
        await center.deliver(lead14)                                        // iOS still lists only one
        await scheduler.refresh()
        #expect(history.records.first { $0.id == lead14 }!.delivery(at: box.now) == .delivered)
        #expect(history.records.first { $0.id == lead3 }!.delivery(at: box.now) == .due) // time passed, delivery unknown
        #expect(history.visible.map(\.id) == [lead3, lead14])
        history.markAllRead()
        #expect(history.unreadCount == 0)
    }

    @Test func remindersFollowTaskProgress() async {
        let (center, _, scheduler, box) = make(.allowed)
        box.enabled = [.unfinishedTasks]
        box.now = period.stationRetrograde + 60
        await scheduler.refresh()
        #expect(await center.pending.values.contains { $0.id.hasPrefix("\(period.id).kit.reminder") })
        box.remaining = 0 // every task the person can open is done
        await scheduler.refresh()
        #expect(await center.pending.isEmpty)
    }

    @Test func overlappingRefreshesSettleOnTheLatestChoices() async {
        let (center, _, scheduler, box) = make(.allowed)
        async let first: Void = scheduler.refresh()
        box.enabled = [.mercuryTurnsDirect]
        async let second: Void = scheduler.refresh()
        _ = await (first, second)
        #expect(await center.pending.values.allSatisfy { $0.kind == .mercuryTurnsDirect })
    }
}
