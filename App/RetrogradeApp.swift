import DesignSystem
import Entitlements
import Persistence
import SwiftData
import SwiftUI

@main
struct RetrogradeApp: App {
    @State private var completions: CompletionStore
    @State private var entitlements = AppEntitlements.make()

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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(completions)
                .environment(entitlements)
                .preferredColorScheme(.dark)
        }
    }
}
