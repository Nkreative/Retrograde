import DesignSystem
import Entitlements
import Foundation
import Notifications
import Observation
import Persistence
import RetroCore
import SurvivalKit
import SwiftUI
import UIKit
import UserNotifications

/// A tapped notification's destination, waiting for the main screen to open it. On a cold launch
/// the tap arrives before any screen exists (or while onboarding is showing), so it waits here.
@MainActor
@Observable
final class NotificationRoutes {
    var pending: NotificationDestination?
}

/// iOS's notification callbacks. Set as the delegate at launch, before iOS hands over a tap that
/// opened the app.
@MainActor
final class NotificationResponder: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationResponder()

    let routes = NotificationRoutes()
    weak var history: NotificationHistory?

    /// Shown while the app is open: display it, and record that iOS delivered it.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void) {
        let id = notification.request.identifier
        Task { @MainActor in NotificationResponder.shared.history?.confirmDelivery(id: id) }
        completionHandler([.banner, .list, .sound])
    }

    /// The person tapped it (app open, in the background, or not running).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping @Sendable () -> Void) {
        let id = response.notification.request.identifier
        let destination = response.notification.request.content.userInfo[NotificationDestination.userInfoKey] as? String
        Task { @MainActor in
            NotificationResponder.shared.opened(id: id, destination: destination)
            completionHandler()
        }
    }

    /// Confirms delivery, marks it read, and queues where it leads.
    func opened(id: String, destination: String?) {
        history?.confirmDelivery(id: id)
        history?.markRead(id: id)
        if let destination = destination.flatMap(NotificationDestination.init(userInfoValue:)) {
            routes.pending = destination
        }
    }
}

/// Sets the notification delegate as the app launches.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationResponder.shared
        return true
    }
}

@MainActor
enum AppNotifications {
    /// The scheduler, fed with the verified sky data, the saved choices and real task progress.
    static func makeScheduler(history: NotificationHistory, preferences: NotificationPreferences,
                              completions: CompletionStore, entitlements: EntitlementStore) -> NotificationScheduler {
        let kit = SurvivalKit.for(.mercury)
        let policy = TaskAccessPolicy.launch
        return NotificationScheduler(center: center, history: history) {
            guard let ephemeris = SkyData.ephemeris, let kit else { return nil }
            let open = policy.openTasks(in: kit, isPremium: entitlements.isPremium).map(\.id)
            return .init(
                // The person's time zone right now; a change triggers a new run.
                planner: NotificationPlanner(periods: ephemeris.retrogrades.filter { $0.planet == .mercury }, calendar: .current),
                enabled: preferences.enabled,
                remainingTasks: { period in
                    let done = completions.completedTaskIDs(in: period.id)
                    return open.filter { !done.contains($0) }.count
                },
                now: .now
            )
        }
    }

    private static var center: LocalNotificationCenter {
        #if DEBUG
        // `-notificationAuth allowed|provisional|denied|notDetermined` also makes the scheduler act
        // on that status (to review scheduling in the simulator). It never changes iOS's permission.
        if let status = NotificationPermission.debugOverride { return DebugStatusCenter(status: status) }
        #endif
        return SystemNotificationCenter()
    }
}

#if DEBUG
/// iOS's center with a pretend permission status (review builds only).
private struct DebugStatusCenter: LocalNotificationCenter {
    let status: NotificationAuthorization
    private let system = SystemNotificationCenter()

    func authorization() async -> NotificationAuthorization { status }
    func pendingIDs() async -> [String] { await system.pendingIDs() }
    func deliveredIDs() async -> [String] { await system.deliveredIDs() }
    func schedule(_ notification: PlannedNotification, calendar: Calendar) async throws { try await system.schedule(notification, calendar: calendar) }
    func removePending(ids: [String]) async { await system.removePending(ids: ids) }
}
#endif

#if DEBUG
/// Settings › Developer › Scheduled alerts: what iOS actually has pending, plus a test alert.
/// Debug builds only; the test alert is never recorded in the history.
struct ScheduledAlertsView: View {
    @Environment(NotificationScheduler.self) private var scheduler
    @State private var pending: [(id: String, title: String, date: Date?)] = []
    @State private var sent = false

    var body: some View {
        List {
            Section {
                Button(sent ? "Test alert sent. Lock the phone." : "Send a test alert in 10 seconds") { Task { await sendTest() } }
                    .frame(minHeight: 44)
                Text("Copies the next scheduled alert (title, text and where it opens). Not saved in the history.")
                    .retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
            .listRowBackground(RetroColor.surface)
            Section {
                if pending.isEmpty {
                    Text("Nothing pending. Notifications may be off, or every alert is turned off.")
                        .retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                ForEach(pending, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                        Text(item.date?.formatted(date: .abbreviated, time: .shortened) ?? "—").retroText(.body).foregroundStyle(RetroColor.textMuted)
                        Text(item.id).retroText(.monoSmall).foregroundStyle(RetroColor.textMuted)
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("PENDING IN iOS (\(pending.count))").retroText(.mono).foregroundStyle(RetroColor.textMuted)
            }
            .listRowBackground(RetroColor.surface)
        }
        .scrollContentBackground(.hidden)
        .retroScreenBackground()
        .navigationTitle("Scheduled alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
    }

    private func reload() async {
        await scheduler.refresh()
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        pending = requests.map { request in
            (request.identifier, request.content.title, (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate())
        }
        .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    private func sendTest() async {
        guard let next = scheduler.scheduled.first else { return }
        let content = UNMutableNotificationContent()
        content.title = next.title
        content.body = next.body
        content.sound = .default
        content.userInfo = [NotificationDestination.userInfoKey: next.destination.userInfoValue]
        let request = UNNotificationRequest(identifier: "debug.test-alert", content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false))
        try? await UNUserNotificationCenter.current().add(request)
        sent = true
    }
}
#endif
