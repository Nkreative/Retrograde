import Foundation
import Observation

/// Whether the person has started the Survival Kit, saved on the device. It decides the Overview:
/// the kit introduction until then, the personal dashboard after. It's set by tapping Start Survival
/// Kit or marking any task done (opening the kit tab doesn't count), and it's never tied to a cycle:
/// a new retrograde resets the tasks but not this.
@MainActor
@Observable
public final class SurvivalKitActivation {
    public private(set) var isStarted: Bool
    @ObservationIgnored private let defaults: UserDefaults?

    public static let storageKey = "survivalKit.started"

    /// `defaults` nil keeps it in memory only (tests, previews). With nothing saved yet,
    /// `hasCompletedTasks` decides: people updating from a version without this flag, who already
    /// marked a task done, start on the dashboard (and it's saved as started).
    public init(defaults: UserDefaults? = .standard, hasCompletedTasks: Bool = false) {
        self.defaults = defaults
        if let saved = defaults?.object(forKey: Self.storageKey) as? Bool {
            isStarted = saved
        } else {
            isStarted = hasCompletedTasks
            if hasCompletedTasks { defaults?.set(true, forKey: Self.storageKey) }
        }
    }

    public func start() {
        guard !isStarted else { return }
        isStarted = true
        defaults?.set(true, forKey: Self.storageKey)
    }

    /// Debug builds and tests only (Replay onboarding): back to the introduction.
    public func reset() {
        isStarted = false
        defaults?.set(false, forKey: Self.storageKey)
    }
}
