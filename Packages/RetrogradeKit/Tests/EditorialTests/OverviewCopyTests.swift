import RetroCore
import Testing
@testable import Editorial

@Suite struct OverviewCopyTests {
    @Test(arguments: CycleStatus.Stage.allCases)
    func everyMercuryStageHasCompleteCopy(_ stage: CycleStatus.Stage) throws {
        let copy = try #require(OverviewCopy.for(.mercury, stage))
        for text in [copy.countdownUnit, copy.countdownToday, copy.heroHeadline, copy.kitTiming, copy.kitTimingToday] {
            #expect(!text.isEmpty)
        }
        // The countdown row shares a line with the day label; keep units short enough not to wrap at 390 pt.
        #expect(copy.countdownUnit.count <= 30)
        #expect(copy.heroHeadline.split(separator: "\n").allSatisfy { $0.count <= 18 })
    }

    @Test func formatsCountdownAndDayLabels() throws {
        let rx = try #require(OverviewCopy.for(.mercury, .retrograde))
        #expect(rx.countdownUnit(for: 1) == "day to exhale")
        #expect(rx.countdownUnit(for: 10) == "days to exhale")
        #expect(rx.dayLabel(day: 12, of: 22) == "DAY 12 / 22")
        let direct = try #require(OverviewCopy.for(.mercury, .direct))
        #expect(direct.dayLabel(day: 17, of: 70) == nil)
    }

    @Test func kitIntroductionFollowsTheCountdown() throws {
        let rx = try #require(OverviewCopy.for(.mercury, .retrograde))
        #expect(rx.kitIntroduction(daysUntilTarget: 9) == "Quick, practical tasks for the next 9 days: slow down your messages, back up what matters, pad your plans and write it out. Tick them off as you go.")
        #expect(rx.kitIntroduction(daysUntilTarget: 1).hasPrefix("Quick, practical tasks for the next 1 day:"))
        #expect(rx.kitIntroduction(daysUntilTarget: 0).hasPrefix("Quick, practical tasks for the rest of this retrograde:"))
        let direct = try #require(OverviewCopy.for(.mercury, .direct))
        #expect(!direct.kitIntroduction(daysUntilTarget: 40).contains("40"))
    }

    @Test func otherPlanetsHaveNoLaunchCopy() {
        #expect(OverviewCopy.for(.venus, .retrograde) == nil)
    }
}
