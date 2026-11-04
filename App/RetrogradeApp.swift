import DesignSystem
import Entitlements
import Notifications
import Persistence
import SwiftData
import SwiftUI

@main
struct RetrogradeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var completions: CompletionStore
    @State private var entitlements = AppEntitlements.make()
    @State private var notificationPreferences = NotificationPreferences()
    @State private var notificationHistory = Self.makeHistory()

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
        _completions = State(initialValue: store)
    }

    /// The on-device notification history. Debug builds launched with `-sampleNotifications YES`
    /// use an in-memory history with sample entries instead (screenshots only).
    private static func makeHistory() -> NotificationHistory {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "sampleNotifications") {
            let history = NotificationHistory(defaults: nil)
            history.debugReplace(with: SampleNotifications.records())
            return history
        }
        #endif
        return NotificationHistory()
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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(completions)
                .environment(entitlements)
                .environment(notificationPreferences)
                .environment(notificationHistory)
                .preferredColorScheme(.dark)
                // Verified entitlements at launch, then live updates; re-checked on every return to the app.
                .task { if !Self.isHostingTests { await entitlements.start() } }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active, !Self.isHostingTests { Task { await entitlements.refresh() } }
                }
        }
    }
}
