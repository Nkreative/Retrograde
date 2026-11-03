import Foundation
import SwiftData
import Testing
@testable import Persistence

@MainActor
@Suite struct CompletionStoreTests {
    @Test func marksAndUnmarksTasks() throws {
        let store = CompletionStore(container: try CompletionStore.makeContainer(inMemory: true))
        #expect(!store.isDone("a", in: "mercury-2026-10-24"))
        store.markDone("a", in: "mercury-2026-10-24")
        store.markDone("a", in: "mercury-2026-10-24") // second tap is harmless
        #expect(store.completedTaskIDs(in: "mercury-2026-10-24") == ["a"])
        store.markNotDone("a", in: "mercury-2026-10-24")
        #expect(store.completedTaskIDs(in: "mercury-2026-10-24").isEmpty)
    }

    @Test func eachCycleStartsEmpty() throws {
        let store = CompletionStore(container: try CompletionStore.makeContainer(inMemory: true))
        store.markDone("a", in: "mercury-2026-06-29")
        store.markDone("b", in: "mercury-2026-06-29")
        #expect(store.completedTaskIDs(in: "mercury-2026-10-24").isEmpty)
        #expect(store.completedTaskIDs(in: "mercury-2026-06-29") == ["a", "b"])
    }

    @Test func survivesAnAppRestart() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("completion-\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let container = try ModelContainer(for: TaskCompletion.self, configurations: ModelConfiguration(url: url))
            CompletionStore(container: container).markDone("a", in: "mercury-2026-10-24")
        }
        // A fresh container and store, as after relaunching the app.
        let reopened = try ModelContainer(for: TaskCompletion.self, configurations: ModelConfiguration(url: url))
        #expect(CompletionStore(container: reopened).isDone("a", in: "mercury-2026-10-24"))
    }
}
