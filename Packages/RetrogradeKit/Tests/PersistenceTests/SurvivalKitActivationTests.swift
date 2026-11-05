import Foundation
import Testing
@testable import Persistence

@MainActor
@Suite struct SurvivalKitActivationTests {
    private func defaults() throws -> (UserDefaults, () -> Void) {
        let suite = "kit-activation-\(UUID())"
        let d = try #require(UserDefaults(suiteName: suite))
        return (d, { d.removePersistentDomain(forName: suite) })
    }

    @Test func freshInstallShowsTheIntroduction() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        #expect(!SurvivalKitActivation(defaults: d).isStarted)
    }

    @Test func startingIsSavedAcrossLaunches() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        SurvivalKitActivation(defaults: d).start()
        #expect(SurvivalKitActivation(defaults: d).isStarted)
    }

    @Test func peopleWithCompletedTasksStartOnTheDashboard() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        #expect(SurvivalKitActivation(defaults: d, hasCompletedTasks: true).isStarted)
        // Saved, so it stays started even if those tasks are later unmarked.
        #expect(SurvivalKitActivation(defaults: d, hasCompletedTasks: false).isStarted)
    }

    @Test func onlyAResetGoesBack() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        let activation = SurvivalKitActivation(defaults: d)
        activation.start()
        activation.reset()
        #expect(!activation.isStarted)
        // A reset isn't undone by old completions on the next launch.
        #expect(!SurvivalKitActivation(defaults: d, hasCompletedTasks: true).isStarted)
    }
}
