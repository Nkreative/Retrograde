import Testing
@testable import RetroCore

@Suite struct CalendarAccessTests {
    let policy = CalendarAccessPolicy.launch
    let today = CalendarDay(year: 2026, month: 11, day: 3)

    @Test func freeIsTodayPlusThreeDays() {
        let unlocked = (-2...6).map { policy.detailsUnlocked(today.adding(days: $0), today: today, isPremium: false) }
        #expect(unlocked == [false, false, true, true, true, true, false, false, false])
    }

    @Test func windowRollsDaily() {
        let tomorrow = today.adding(days: 1)
        #expect(!policy.detailsUnlocked(today.adding(days: 4), today: today, isPremium: false))
        #expect(policy.detailsUnlocked(today.adding(days: 4), today: tomorrow, isPremium: false))
        #expect(!policy.detailsUnlocked(today, today: tomorrow, isPremium: false))
    }

    @Test func premiumUnlocksEveryDay() {
        #expect(policy.detailsUnlocked(today.adding(days: -300), today: today, isPremium: true))
        #expect(policy.detailsUnlocked(today.adding(days: 300), today: today, isPremium: true))
    }

    @Test func tellsWhenAFutureDayBecomesFree() {
        #expect(policy.freeFrom(CalendarDay(year: 2026, month: 11, day: 7), today: today) == CalendarDay(year: 2026, month: 11, day: 4))
        #expect(policy.freeFrom(CalendarDay(year: 2026, month: 11, day: 1), today: today) == nil)
    }
}

@Suite struct MonthGridTests {
    @Test func november2026SundayFirst() {
        let grid = MonthGrid(year: 2026, month: 11, firstWeekday: 1)
        #expect(grid.weeks.count == 5)
        #expect(grid.weeks.first?.first == CalendarDay(year: 2026, month: 11, day: 1)) // a Sunday
        #expect(grid.weeks.last?.last == CalendarDay(year: 2026, month: 12, day: 5))
    }

    @Test func november2026MondayFirst() {
        let grid = MonthGrid(year: 2026, month: 11, firstWeekday: 2)
        #expect(grid.weeks.first?.first == CalendarDay(year: 2026, month: 10, day: 26))
        #expect(grid.weeks.allSatisfy { $0.count == 7 })
        #expect(grid.week(containing: CalendarDay(year: 2026, month: 11, day: 3))?.first == CalendarDay(year: 2026, month: 11, day: 2))
    }

    @Test func monthArithmetic() {
        #expect(MonthGrid.ID(year: 2026, month: 12).adding(months: 1) == MonthGrid.ID(year: 2027, month: 1))
        #expect(MonthGrid.ID(year: 2025, month: 1).adding(months: -1) == MonthGrid.ID(year: 2024, month: 12))
    }
}

@Suite struct RollingWeekTests {
    let today = CalendarDay(year: 2026, month: 11, day: 3)

    @Test func startsTodayWithNoPastDays() {
        #expect(RollingWeek.days(from: today, block: 0).first == today)
        #expect(RollingWeek.days(from: today, block: 0).last == CalendarDay(year: 2026, month: 11, day: 9))
        #expect(RollingWeek.days(from: today, block: 1).first == CalendarDay(year: 2026, month: 11, day: 10))
    }

    @Test func findsTheBlockForADay() {
        #expect(RollingWeek.block(containing: today, from: today) == 0)
        #expect(RollingWeek.block(containing: CalendarDay(year: 2026, month: 11, day: 9), from: today) == 0)
        #expect(RollingWeek.block(containing: CalendarDay(year: 2026, month: 11, day: 10), from: today) == 1)
        #expect(RollingWeek.block(containing: CalendarDay(year: 2026, month: 10, day: 1), from: today) == 0)
    }
}
