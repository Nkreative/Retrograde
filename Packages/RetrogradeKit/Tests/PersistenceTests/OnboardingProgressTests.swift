import Foundation
import Testing
@testable import Persistence

@MainActor
@Suite struct OnboardingProgressTests {
    private func defaults() throws -> (UserDefaults, () -> Void) {
        let suite = "onboarding-\(UUID())"
        let d = try #require(UserDefaults(suiteName: suite))
        return (d, { d.removePersistentDomain(forName: suite) })
    }

    @Test func freshInstallShowsOnboarding() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        let p = OnboardingProgress(defaults: d)
        #expect(p.step == .notifications && !p.isComplete)
    }

    @Test func interruptedOnboardingShowsAgain() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        _ = OnboardingProgress(defaults: d) // app closed during the splash or notifications screen
        #expect(!OnboardingProgress(defaults: d).isComplete)
    }

    @Test func completedOnboardingNeverReplays() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        OnboardingProgress(defaults: d).complete() // completed before the paywall appears
        #expect(OnboardingProgress(defaults: d).isComplete)
        #expect(OnboardingProgress(defaults: d, initial: .notifications).isComplete)
    }

    @Test func reset() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        let p = OnboardingProgress(defaults: d)
        p.complete(); p.reset()
        #expect(OnboardingProgress(defaults: d).step == .notifications)
    }

    /// Earlier builds saved "mercury" / "features"; anything but "completed" isn't done.
    @Test func earlierOrUnknownSavedValuesFallBackSafely() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        for value in ["mercury", "features", "garbage"] {
            d.set(value, forKey: OnboardingProgress.storageKey)
            #expect(OnboardingProgress(defaults: d).step == .notifications)
        }
    }
}
