import AstroData
import Foundation
import RetroCore
import Testing
@testable import SurvivalKit

@Suite struct KitContentTests {
    let kit = SurvivalKit.for(.mercury)!

    @Test func matchesTheFigmaKit() {
        #expect(kit.sections.map(\.label) == ["01 / COMMUNICATION", "02 / TECH BACKUP", "03 / FLEXIBLE PLANNING", "04 / JOURNAL"])
        #expect(kit.sections.map(\.tasks.count) == [8, 6, 6, 7])
        #expect(kit.tasks.count == 27)
    }

    @Test func taskIDsAreUniqueAndStable() {
        #expect(Set(kit.tasks.map(\.id)).count == kit.tasks.count)
        #expect(kit.tasks.allSatisfy { $0.id.hasPrefix("mercury.") })
    }
}

@Suite struct TaskAccessTests {
    let policy = TaskAccessPolicy.launch

    @Test func freeShowsOneUnlockedTwoPreviewsThenBlurred() {
        #expect((0..<5).map { policy.visibility(ofTaskAt: $0, isPremium: false) } == [.unlocked, .preview, .preview, .hidden, .hidden])
    }

    @Test func premiumUnlocksEverything() {
        #expect((0..<8).allSatisfy { policy.visibility(ofTaskAt: $0, isPremium: true) == .unlocked })
    }

    @Test func countsLockedTasksForTheNudge() {
        let kit = SurvivalKit.for(.mercury)!
        #expect(policy.lockedCount(in: kit, isPremium: false) == 23)
        #expect(policy.lockedCount(in: kit, isPremium: true) == 0)
    }
}

@Suite struct KitCycleTests {
    let calc: CycleCalculator

    init() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        calc = CycleCalculator(ephemeris: try BundledEphemeris.load(), calendar: utc)
    }

    private func at(_ s: String) -> Date { try! Date(s, strategy: .iso8601) }

    @Test func kitRollsOverTheMomentTheNextRetrogradeBegins() {
        // Mercury stations retrograde at 07:13 UT on 24 Oct 2026.
        #expect(calc.currentCycle(of: .mercury, at: at("2026-10-24T07:00:00Z"))?.id == "mercury-2026-06-29")
        #expect(calc.currentCycle(of: .mercury, at: at("2026-10-24T07:30:00Z"))?.id == "mercury-2026-10-24")
    }

    @Test func kitStaysTheSameThroughShadowsAndDirect() {
        for time in ["2026-11-03T12:00:00Z", "2026-11-20T12:00:00Z", "2027-01-30T12:00:00Z"] {
            #expect(calc.currentCycle(of: .mercury, at: at(time))?.id == "mercury-2026-10-24", "\(time)")
        }
    }
}
