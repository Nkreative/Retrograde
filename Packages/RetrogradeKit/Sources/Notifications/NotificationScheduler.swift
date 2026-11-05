import Foundation
import Observation
import RetroCore
#if canImport(UserNotifications)
import UserNotifications
#endif

/// The parts of iOS's notification center Retrograde uses. Reading permission never prompts;
/// there is deliberately no way to request permission here.
public protocol LocalNotificationCenter: Sendable {
    func authorization() async -> NotificationAuthorization
    /// Ids of the app's alerts iOS is still waiting to show.
    func pendingIDs() async -> [String]
    /// Ids of the app's alerts iOS reports as delivered and still keeps in Notification Center.
    func deliveredIDs() async -> [String]
    /// Adds the alert, replacing any pending one with the same id.
    func schedule(_ notification: PlannedNotification, calendar: Calendar) async throws
    func removePending(ids: [String]) async
}

/// Keeps iOS's pending alerts and the notification history in step with the plan. Run it on
/// launch, on return to the app, and whenever permission, preferences, Premium, task progress or
/// the time zone change; repeated runs converge on the same state (stable ids, no duplicates).
@MainActor
@Observable
public final class NotificationScheduler {
    /// Everything a plan depends on, read fresh at the start of each run.
    public struct Input {
        public let planner: NotificationPlanner
        public let enabled: Set<NotificationKind>
        public let remainingTasks: (RetrogradePeriod) -> Int
        public let now: Date

        public init(planner: NotificationPlanner, enabled: Set<NotificationKind>, remainingTasks: @escaping (RetrogradePeriod) -> Int, now: Date) {
            self.planner = planner
            self.enabled = enabled
            self.remainingTasks = remainingTasks
            self.now = now
        }
    }

    @ObservationIgnored private let center: LocalNotificationCenter
    @ObservationIgnored private let history: NotificationHistory
    @ObservationIgnored private let input: @MainActor () -> Input?
    @ObservationIgnored private var running = false
    @ObservationIgnored private var runAgain = false

    /// The plan from the last run (empty when iOS won't deliver), for Settings › Developer.
    public private(set) var scheduled: [PlannedNotification] = []

    public init(center: LocalNotificationCenter, history: NotificationHistory, input: @escaping @MainActor () -> Input?) {
        self.center = center
        self.history = history
        self.input = input
    }

    /// Brings iOS and the history in line with the current plan. Calls made while a run is in
    /// progress are folded into one more run, so the last change always wins.
    public func refresh() async {
        if running { runAgain = true; return }
        running = true
        defer { running = false }
        repeat {
            runAgain = false
            await reconcile()
        } while runAgain
    }

    private func reconcile() async {
        let authorization = await center.authorization()
        let pending = Set(await center.pendingIDs())
        guard authorization.canDeliver, let input = input() else {
            // Not allowed (or no sky data): nothing waits in iOS, and no future entry claims otherwise.
            if !pending.isEmpty { await center.removePending(ids: Array(pending)) }
            history.cancelScheduled(keeping: [])
            scheduled = []
            return
        }
        let plan = input.planner.plan(enabled: input.enabled, remainingTasks: input.remainingTasks, now: input.now)
        let ids = Set(plan.map(\.id))
        let stale = pending.subtracting(ids)
        if !stale.isEmpty { await center.removePending(ids: Array(stale)) }
        var added: Set<String> = []
        for notification in plan {
            do {
                try await center.schedule(notification, calendar: input.planner.calendar)
                added.insert(notification.id)
            } catch {
                continue // not scheduled, so not recorded either
            }
        }
        history.cancelScheduled(keeping: added)
        for notification in plan where added.contains(notification.id) { history.record(notification.record) }
        for id in await center.deliveredIDs() { history.confirmDelivery(id: id) }
        scheduled = plan.filter { added.contains($0.id) }
    }
}

#if canImport(UserNotifications)
/// iOS's notification center.
public struct SystemNotificationCenter: LocalNotificationCenter {
    public init() {}

    public func authorization() async -> NotificationAuthorization {
        NotificationAuthorization(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
    }

    public func pendingIDs() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    public func deliveredIDs() async -> [String] {
        await UNUserNotificationCenter.current().deliveredNotifications().map(\.request.identifier)
    }

    public func schedule(_ notification: PlannedNotification, calendar: Calendar) async throws {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.threadIdentifier = notification.destination == .survivalKit ? "survival-kit" : "sky"
        content.userInfo = [NotificationDestination.userInfoKey: notification.destination.userInfoValue]
        // Wall-clock time in the person's calendar; rescheduled whenever the time zone changes.
        let when = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notification.fireDate)
        let request = UNNotificationRequest(identifier: notification.id, content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: false))
        try await UNUserNotificationCenter.current().add(request)
    }

    public func removePending(ids: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
#endif
