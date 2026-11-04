import Foundation
import Observation

/// First-launch onboarding position, saved after every step so an interrupted onboarding resumes
/// where it stopped. Completion is permanent (updates never replay it). It's marked complete when
/// the person leaves the notifications step — before the paywall — so reopening the app never
/// lands on a purchase screen.
@MainActor
@Observable
public final class OnboardingProgress {
    public enum Step: String, CaseIterable, Sendable {
        case mercury, features, notifications, completed
    }

    public private(set) var step: Step
    @ObservationIgnored private let defaults: UserDefaults?

    public static let storageKey = "onboarding.step"

    /// `defaults` nil keeps progress in memory only (test hosts, debug previews).
    public init(defaults: UserDefaults? = .standard, initial: Step = .mercury) {
        self.defaults = defaults
        step = defaults?.string(forKey: Self.storageKey).flatMap(Step.init(rawValue:)) ?? initial
    }

    public var isComplete: Bool { step == .completed }

    /// 0-based position among the visible pages, for the page indicator.
    public var pageIndex: Int { Step.allCases.firstIndex(of: step) ?? 0 }
    public static let pageCount = 3

    public func advance() {
        guard let i = Step.allCases.firstIndex(of: step), i + 1 < Step.allCases.count else { return }
        set(Step.allCases[i + 1])
    }

    public func back() {
        guard !isComplete, let i = Step.allCases.firstIndex(of: step), i > 0 else { return }
        set(Step.allCases[i - 1])
    }

    public func complete() { set(.completed) }

    /// Debug builds and tests only: start onboarding again.
    public func reset() { set(.mercury) }

    private func set(_ new: Step) {
        step = new
        defaults?.set(new.rawValue, forKey: Self.storageKey)
    }
}
