import Foundation
import Observation
import SwiftData

/// One "Mark as done", stored on the device. Records are kept per retrograde cycle, so a new
/// cycle starts with an empty kit while earlier cycles' history stays intact.
@Model
public final class TaskCompletion {
    /// `RetrogradePeriod.id`, e.g. "mercury-2026-10-24".
    public var cycleID: String
    /// `KitTask.id`.
    public var taskID: String
    public var completedAt: Date

    public init(cycleID: String, taskID: String, completedAt: Date) {
        self.cycleID = cycleID
        self.taskID = taskID
        self.completedAt = completedAt
    }
}

/// Reads and writes task completion. Observable, so lists update the moment a task is marked done.
@MainActor
@Observable
public final class CompletionStore {
    private let context: ModelContext
    /// Completed task IDs per cycle, loaded on first use.
    private var cache: [String: Set<String>] = [:]

    public init(container: ModelContainer) {
        self.context = ModelContext(container)
    }

    /// The app's on-device store.
    public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(for: TaskCompletion.self, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
    }

    public func completedTaskIDs(in cycleID: String) -> Set<String> {
        if let cached = cache[cycleID] { return cached }
        let records = (try? context.fetch(FetchDescriptor<TaskCompletion>(predicate: #Predicate { $0.cycleID == cycleID }))) ?? []
        let ids = Set(records.map(\.taskID))
        cache[cycleID] = ids
        return ids
    }

    public func isDone(_ taskID: String, in cycleID: String) -> Bool {
        completedTaskIDs(in: cycleID).contains(taskID)
    }

    public func markDone(_ taskID: String, in cycleID: String, at date: Date = .now) {
        guard !isDone(taskID, in: cycleID) else { return }
        context.insert(TaskCompletion(cycleID: cycleID, taskID: taskID, completedAt: date))
        save()
        cache[cycleID, default: []].insert(taskID)
    }

    public func markNotDone(_ taskID: String, in cycleID: String) {
        let records = (try? context.fetch(FetchDescriptor<TaskCompletion>(
            predicate: #Predicate { $0.cycleID == cycleID && $0.taskID == taskID }
        ))) ?? []
        records.forEach(context.delete)
        save()
        cache[cycleID]?.remove(taskID)
    }

    private func save() {
        do {
            try context.save()
        } catch {
            assertionFailure("Couldn't save task completion: \(error)")
        }
    }
}
