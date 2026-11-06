import Foundation
import Observation

/// First-launch onboarding (the splash, then the notifications screen), saved on the device so an
/// interrupted onboarding starts again on the next launch. Completion is permanent (updates never
/// replay it). It's marked complete when the person leaves the notifications screen, as Premium
/// appears as onboarding's last step, so reopening the app never lands on a purchase screen.
@MainActor
@Observable
public final class OnboardingProgress {
    public enum Step: String, Sendable {
        case notifications, completed
    }

    public private(set) var step: Step
    @ObservationIgnored private let defaults: UserDefaults?

    public static let storageKey = "onboarding.step"

    /// `defaults` nil keeps progress in memory only (test hosts, debug previews). Any saved value
    /// other than "completed" (including steps from earlier builds) means onboarding isn't done.
    public init(defaults: UserDefaults? = .standard, initial: Step = .notifications) {
        self.defaults = defaults
        step = switch defaults?.string(forKey: Self.storageKey) {
        case nil: initial
        case Step.completed.rawValue?: .completed
        default: .notifications
        }
    }

    public var isComplete: Bool { step == .completed }

    public func complete() { set(.completed) }

    /// Debug builds and tests only: start onboarding again.
    public func reset() { set(.notifications) }

    private func set(_ new: Step) {
        step = new
        defaults?.set(new.rawValue, forKey: Self.storageKey)
    }
}
