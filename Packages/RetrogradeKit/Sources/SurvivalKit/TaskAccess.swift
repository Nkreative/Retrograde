/// How a task appears to the person, from the approved free-user Figma screen.
public enum TaskVisibility: Sendable {
    /// Tappable; opens the task.
    case unlocked
    /// Readable but dimmed with a lock; not tappable.
    case preview
    /// Dimmed, locked and blurred; not tappable.
    case hidden
}

/// Free vs Premium task rules, kept apart from the UI so pricing can change without touching screens.
public struct TaskAccessPolicy: Sendable {
    /// Tasks unlocked at the top of each section for free users.
    public let freeUnlockedPerSection: Int
    /// Locked-but-readable tasks after those.
    public let freePreviewPerSection: Int

    public static let launch = TaskAccessPolicy(freeUnlockedPerSection: 1, freePreviewPerSection: 2)

    public init(freeUnlockedPerSection: Int, freePreviewPerSection: Int) {
        self.freeUnlockedPerSection = freeUnlockedPerSection
        self.freePreviewPerSection = freePreviewPerSection
    }

    /// Visibility of the task at `index` (0-based) within its section.
    public func visibility(ofTaskAt index: Int, isPremium: Bool) -> TaskVisibility {
        if isPremium || index < freeUnlockedPerSection { return .unlocked }
        return index < freeUnlockedPerSection + freePreviewPerSection ? .preview : .hidden
    }

    /// Tasks a free person can't open, for the "N more tasks in Premium" nudge.
    public func lockedCount(in kit: SurvivalKit, isPremium: Bool) -> Int {
        guard !isPremium else { return 0 }
        return kit.sections.reduce(0) { $0 + max($1.tasks.count - freeUnlockedPerSection, 0) }
    }
}
