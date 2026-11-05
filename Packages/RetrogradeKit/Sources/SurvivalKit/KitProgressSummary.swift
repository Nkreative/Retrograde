/// Where the person stands in this cycle's kit, for the Overview dashboard: how much is done, the
/// next task they can open, and which state the card shows. Uses the same access rules as the kit.
public struct KitProgressSummary: Sendable {
    public enum State: Equatable, Sendable {
        /// Something left to do that the person can open.
        case inProgress
        /// Free, and every free task is done; the rest are in Premium.
        case freeTasksDone
        /// Every task in the kit is done (Premium).
        case allDone
    }

    public let done: Int
    public let total: Int
    /// The first task, in kit order, that the person can open and hasn't done; nil when none is left.
    public let nextTask: KitTask?
    /// The section `nextTask` belongs to.
    public let nextSection: KitSection?
    /// Free tasks not done yet (0 with Premium).
    public let freeTasksLeft: Int
    /// Tasks only Premium opens (0 with Premium).
    public let lockedCount: Int
    public let state: State

    public init(kit: SurvivalKit, done: Set<String>, isPremium: Bool, policy: TaskAccessPolicy = .launch) {
        let open = policy.openTasks(in: kit, isPremium: isPremium)
        let next = open.first { !done.contains($0.id) }
        self.done = kit.tasks.filter { done.contains($0.id) }.count
        total = kit.tasks.count
        nextTask = next
        nextSection = next.flatMap { task in kit.sections.first { $0.tasks.contains(task) } }
        freeTasksLeft = isPremium ? 0 : open.filter { !done.contains($0.id) }.count
        lockedCount = policy.lockedCount(in: kit, isPremium: isPremium)
        state = next != nil ? .inProgress : lockedCount > 0 ? .freeTasksDone : .allDone
    }

    /// 0...1.
    public var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }

    /// Rounded percentage, "11%".
    public var percent: Int { Int((fraction * 100).rounded()) }
}
