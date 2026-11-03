import AstroData
import Foundation
import RetroCore
import Testing
@testable import Editorial

@Suite struct DayDetailContentTests {
    let intensity: IntensityCalculator
    let today = CalendarDay(year: 2026, month: 11, day: 3)

    init() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        intensity = IntensityCalculator(ephemeris: try BundledEphemeris.load(), calendar: utc)
    }

    private func content(_ day: CalendarDay, premium: Bool) -> DayDetailContent {
        DayDetailContent.make(day: day, today: today, isPremium: premium, policy: .launch, intensity: intensity)!
    }

    @Test func freeWindowDayShowsInsightsAndOtherPlanets() throws {
        for offset in 0...3 {
            guard case let .unlocked(insight, others) = content(today.adding(days: offset), premium: false).details else {
                Issue.record("day +\(offset) should be unlocked"); continue
            }
            #expect(!insight.summary.isEmpty)
            #expect(others.map(\.planet) == [.venus, .saturn, .uranus, .neptune])
        }
    }

    @Test func lockedDayHidesEverythingBehindOnePaywall() {
        let future = content(today.adding(days: 4), premium: false)
        guard case let .locked(freeFrom, _) = future.details else { Issue.record("should be locked"); return }
        #expect(freeFrom == today.adding(days: 1))
        guard case .locked(nil, _) = content(today.adding(days: -1), premium: false).details else { Issue.record("past day should be locked"); return }
        // Level and count stay visible on locked days.
        #expect(future.level == .elevated)
        #expect(future.retrogradeCount == 5)
    }

    @Test func premiumUnlocksEverySupportedDate() {
        var day = CalendarDay(year: 2025, month: 1, day: 1)
        while day <= CalendarDay(year: 2030, month: 12, day: 31) {
            guard case .unlocked = content(day, premium: true).details else { Issue.record("\(day) locked for Premium"); return }
            day = day.adding(days: 11)
        }
        #expect(DayDetailContent.make(day: CalendarDay(year: 2031, month: 1, day: 1), today: today, isPremium: true, policy: .launch, intensity: intensity) == nil)
    }

    @Test func retrogradeCountAndLabelFollowTheSelectedDate() {
        #expect(content(CalendarDay(year: 2026, month: 11, day: 3), premium: false).retrogradeLabel == "5 Retrogrades")
        // Mercury and Venus turn direct by 15 Nov; Saturn, Uranus and Neptune remain.
        #expect(content(CalendarDay(year: 2026, month: 11, day: 15), premium: true).retrogradeLabel == "3 Retrogrades")
        // Jupiter turns retrograde on 13 Dec; Saturn and Neptune are direct by then.
        #expect(content(CalendarDay(year: 2026, month: 12, day: 13), premium: true).retrogradeCount == 2)
        #expect(DayDetailContent.retrogradeLabel(1) == "1 Retrograde")
        #expect(DayDetailContent.retrogradeLabel(0) == "0 Retrogrades")
    }
}
