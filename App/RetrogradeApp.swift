import DesignSystem
import Entitlements
import Notifications
import Persistence
import Sharing
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

@main
struct RetrogradeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var completions: CompletionStore
    @State private var entitlements: EntitlementStore
    @State private var notificationPreferences: NotificationPreferences
    @State private var notificationHistory: NotificationHistory
    /// Finished shares, kept on the device (in memory while hosting tests).
    @State private var sharingActivity = RetrogradeApp.makeSharingActivity()
    @State private var kitActivation: SurvivalKitActivation
    @State private var notificationScheduler: NotificationScheduler
    @State private var onboarding = Self.makeOnboarding()

    init() {
        RetroFonts.register()
        let container: ModelContainer
        do {
            container = try CompletionStore.makeContainer()
        } catch {
            // Don't lose the session over storage: keep progress in memory until next launch.
            container = try! CompletionStore.makeContainer(inMemory: true)
        }
        let store = CompletionStore(container: container)
        #if DEBUG
        // `-markDone <task id,task id>` marks tasks done in the current cycle, for review.
        if let ids = UserDefaults.standard.string(forKey: "markDone") {
            for id in ids.split(separator: ",") { store.markDone(String(id), in: KitCycle.id(at: .now)) }
        }
        #endif
        let entitlements = AppEntitlements.make()
        let preferences = NotificationPreferences()
        let history = Self.makeHistory()
        NotificationResponder.shared.history = history
        _completions = State(initialValue: store)
        _kitActivation = State(initialValue: Self.makeKitActivation(hasCompletedTasks: store.hasCompletions()))
        _entitlements = State(initialValue: entitlements)
        _notificationPreferences = State(initialValue: preferences)
        _notificationHistory = State(initialValue: history)
        _notificationScheduler = State(initialValue: AppNotifications.makeScheduler(
            history: history, preferences: preferences, completions: store, entitlements: entitlements))
        #if DEBUG
        // `-openNotification calendarDay:2026-11-13` (or `survivalKit`) acts as if a notification
        // was tapped to launch the app, for review of cold-launch navigation.
        if let destination = UserDefaults.standard.string(forKey: "openNotification") {
            NotificationResponder.shared.opened(id: "debug.cold-launch", destination: destination)
        }
        #endif
    }

    /// The on-device notification history. Debug builds launched with `-sampleNotifications YES`
    /// use an in-memory history with sample entries instead (screenshots only); `read` marks them
    /// all read and `empty` starts with none.
    private static func makeHistory() -> NotificationHistory {
        #if DEBUG
        if let sample = UserDefaults.standard.string(forKey: "sampleNotifications"), ["YES", "read", "empty"].contains(sample) {
            let history = NotificationHistory(defaults: nil)
            if sample != "empty" { history.debugReplace(with: SampleNotifications.records()) }
            if sample == "read" { history.markAllRead() }
            return history
        }
        #endif
        return NotificationHistory()
    }

    /// Whether the Overview shows the kit introduction or the dashboard. People updating with tasks
    /// already done start on the dashboard. Debug: `-kitStarted YES|NO` sets it for this launch only.
    private static func makeKitActivation(hasCompletedTasks: Bool) -> SurvivalKitActivation {
        if isHostingTests { return SurvivalKitActivation(defaults: nil) }
        #if DEBUG
        if UserDefaults.standard.object(forKey: "kitStarted") != nil {
            let activation = SurvivalKitActivation(defaults: nil)
            if UserDefaults.standard.bool(forKey: "kitStarted") { activation.start() }
            return activation
        }
        #endif
        return SurvivalKitActivation(hasCompletedTasks: hasCompletedTasks)
    }

    /// Finished shares. Debug builds launched with `-sampleShares YES` use an in-memory history with
    /// sample entries (`empty`: none), for screenshots only.
    private static func makeSharingActivity() -> SharingActivity {
        if isHostingTests { return SharingActivity(defaults: nil) }
        #if DEBUG
        if let sample = UserDefaults.standard.string(forKey: "sampleShares"), ["YES", "empty"].contains(sample) {
            let activity = SharingActivity(defaults: nil)
            if sample == "YES" {
                let now = Date.now
                activity.shareSheetFinished(.app, completed: true, at: now.addingTimeInterval(-8 * 86_400))
                activity.shareSheetFinished(.dailyInsight(day: "2026-11-01"), completed: true, at: now.addingTimeInterval(-4 * 86_400))
                activity.shareSheetFinished(.dailyInsight(day: "2026-11-06"), completed: true, at: now.addingTimeInterval(-600))
            }
            return activity
        }
        #endif
        return SharingActivity()
    }

    /// Saved onboarding progress. While hosting tests it's in memory and already complete.
    /// Debug: `-onboarding reset` starts it again; `-onboarding skip` hides it for this launch.
    private static func makeOnboarding() -> OnboardingProgress {
        if isHostingTests { return OnboardingProgress(defaults: nil, initial: .completed) }
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "onboarding") {
        case "reset":
            let progress = OnboardingProgress()
            progress.reset()
            return progress
        case "skip":
            return OnboardingProgress(defaults: nil, initial: .completed)
        default: break
        }
        #endif
        return OnboardingProgress()
    }

    /// When the app only hosts the StoreKit tests, it stays out of their way: no listener of its own
    /// reading or finishing the tests' transactions.
    private static var isHostingTests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #else
        false
        #endif
    }

    private func rescheduleNotifications() {
        guard !Self.isHostingTests else { return }
        Task { await notificationScheduler.refresh() }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(completions)
                .environment(entitlements)
                .environment(notificationPreferences)
                .environment(notificationHistory)
                .environment(sharingActivity)
                .environment(kitActivation)
                .environment(onboarding)
                .environment(notificationScheduler)
                .environment(NotificationResponder.shared.routes)
                .preferredColorScheme(.dark)
                // Verified entitlements at launch, then live updates; re-checked on every return to the app.
                .task { if !Self.isHostingTests { await entitlements.start() } }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, !Self.isHostingTests { Task { await entitlements.refresh() } }
                }
                // Alerts follow everything they depend on: launch and every return to the app
                // (permission may have changed in iOS Settings), choices, Premium, task progress,
                // finishing onboarding (permission asked), and the clock (time zone, daylight
                // saving, midnight).
                .task { rescheduleNotifications() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { rescheduleNotifications() } }
                .onChange(of: notificationPreferences.enabled) { rescheduleNotifications() }
                .onChange(of: entitlements.isPremium) { rescheduleNotifications() }
                .onChange(of: completions.revision) { rescheduleNotifications() }
                .onChange(of: onboarding.isComplete) { rescheduleNotifications() }
                // The widget works out its days in the time zone it last saw; after a clock or
                // time zone change it's redrawn now rather than at its next daily refresh.
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                    rescheduleNotifications()
                    WidgetCenter.shared.reloadAllTimelines()
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                    rescheduleNotifications()
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}
