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

    /// What reminders count: the tasks the person can open (the first of each section when free).
    @Test func openTasksMatchTheLocks() {
        let kit = SurvivalKit.for(.mercury)!
        #expect(policy.openTasks(in: kit, isPremium: false).map(\.id) == kit.sections.map { $0.tasks[0].id })
        #expect(policy.openTasks(in: kit, isPremium: true).count == kit.tasks.count)
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

@Suite struct KitProgressSummaryTests {
    let kit = SurvivalKit.for(.mercury)!

    private func firsts(_ count: Int) -> Set<String> {
        Set(kit.sections.prefix(count).map { $0.tasks[0].id })
    }

    @Test func freshCycleStartsWithTheFirstTask() {
        let p = KitProgressSummary(kit: kit, done: [], isPremium: false)
        #expect(p.done == 0 && p.total == 27 && p.percent == 0)
        #expect(p.nextTask?.id == "mercury.communication.breathe-first")
        #expect(p.freeTasksLeft == 4 && p.lockedCount == 23 && p.state == .inProgress)
    }

    @Test func nextUpSkipsDoneAndLockedTasks() {
        let p = KitProgressSummary(kit: kit, done: firsts(3), isPremium: false)
        #expect(p.done == 3 && p.percent == 11)
        #expect(p.nextTask?.id == "mercury.journal.name-the-feeling")
        #expect(p.nextSection?.category == "JOURNAL")
        #expect(p.freeTasksLeft == 1)
    }

    @Test func freeWithEveryFreeTaskDone() {
        let p = KitProgressSummary(kit: kit, done: firsts(4), isPremium: false)
        #expect(p.state == .freeTasksDone && p.nextTask == nil && p.lockedCount == 23 && p.percent == 15)
    }

    @Test func premiumContinuesInKitOrder() {
        let p = KitProgressSummary(kit: kit, done: firsts(4), isPremium: true)
        #expect(p.nextTask?.id == "mercury.communication.ask-for-clarity")
        #expect(p.freeTasksLeft == 0 && p.lockedCount == 0 && p.state == .inProgress)
    }

    @Test func premiumAllDone() {
        let p = KitProgressSummary(kit: kit, done: Set(kit.tasks.map(\.id)), isPremium: true)
        #expect(p.state == .allDone && p.done == 27 && p.percent == 100)
    }

    @Test func ignoresUnknownTaskIDs() {
        #expect(KitProgressSummary(kit: kit, done: ["mercury.retired-task"], isPremium: false).done == 0)
    }
}
