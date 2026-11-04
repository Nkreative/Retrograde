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

    @Test func freshInstallStartsAtTheBeginning() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        let p = OnboardingProgress(defaults: d)
        #expect(p.step == .mercury && !p.isComplete)
    }

    @Test func interruptedOnboardingResumesAtTheSameStep() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        let p = OnboardingProgress(defaults: d)
        p.advance(); p.advance()
        #expect(OnboardingProgress(defaults: d).step == .notifications)
    }

    @Test func completedOnboardingNeverReplays() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        OnboardingProgress(defaults: d).complete()
        let relaunched = OnboardingProgress(defaults: d)
        #expect(relaunched.isComplete)
        relaunched.back() // can't go back from completed
        #expect(OnboardingProgress(defaults: d).isComplete)
    }

    @Test func leavingNotificationsCompletesBeforeThePaywall() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        let p = OnboardingProgress(defaults: d)
        p.advance(); p.advance(); p.advance()
        #expect(p.isComplete) // the paywall comes after, so reopening never shows it again
    }

    @Test func backAndReset() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        let p = OnboardingProgress(defaults: d)
        p.advance(); p.back()
        #expect(p.step == .mercury)
        p.complete(); p.reset()
        #expect(OnboardingProgress(defaults: d).step == .mercury)
    }

    @Test func unknownSavedValueFallsBackSafely() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        d.set("garbage", forKey: OnboardingProgress.storageKey)
        #expect(OnboardingProgress(defaults: d).step == .mercury)
    }
}
