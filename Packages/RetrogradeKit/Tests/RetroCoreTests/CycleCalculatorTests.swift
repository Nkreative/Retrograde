import Foundation
import Testing
@testable import RetroCore

/// Mercury's Oct–Nov 2026 retrograde and the one after it (Horizons-derived values).
private let autumn2026 = RetrogradePeriod(
    planet: .mercury,
    preShadowStart: utc("2026-10-04T09:09"), stationRetrograde: utc("2026-10-24T07:13"),
    stationDirect: utc("2026-11-13T15:54"), postShadowEnd: utc("2026-11-30T06:16"),
    stationRetrogradeLongitude: 230.979, stationDirectLongitude: 215.0335
)
private let winter2027 = RetrogradePeriod(
    planet: .mercury,
    preShadowStart: utc("2027-01-25T18:58"), stationRetrograde: utc("2027-02-09T17:36"),
    stationDirect: utc("2027-03-03T12:34"), postShadowEnd: utc("2027-03-23T14:58"),
    stationRetrogradeLongitude: 335.9812, stationDirectLongitude: 320.9231
)
private let ephemeris = Ephemeris(
    coverage: CalendarDay(year: 2026, month: 1, day: 1)...CalendarDay(year: 2027, month: 12, day: 31),
    retrogrades: [winter2027, autumn2026]
)

private func utc(_ s: String) -> Date {
    try! Date(s + ":00Z", strategy: .iso8601)
}

private func calendar(_ zone: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    return c
}

@Suite struct CycleStatusTests {
    private func calc(_ zone: String = "UTC") -> CycleCalculator {
        CycleCalculator(ephemeris: ephemeris, calendar: calendar(zone))
    }

    @Test func midRetrogradeInLondonCountsDaysAcrossTheClockChange() throws {
        // Clocks go back on Oct 25 in London; day counting must not drift.
        let status = try #require(calc("Europe/London").status(of: .mercury, at: utc("2026-11-03T12:00")))
        #expect(status.stage == .retrograde)
        #expect(status.day == 11)
        #expect(status.totalDays == 21)
        #expect(status.daysUntilTarget == 10)
        #expect(status.countdownTarget == autumn2026.stationDirect)
        #expect(status.period == autumn2026)
    }

    @Test func stationsLandOnTheLocalCalendarDay() throws {
        // 07:13 UT on Oct 24 is still Oct 23 in Honolulu and already the evening of Oct 24 in Auckland;
        // 15:54 UT on Nov 13 is Nov 14 in Auckland.
        let instant = utc("2026-11-03T12:00")
        let honolulu = try #require(calc("Pacific/Honolulu").status(of: .mercury, at: instant))
        #expect(honolulu.totalDays == 22)
        #expect(honolulu.day == 12)
        let auckland = try #require(calc("Pacific/Auckland").status(of: .mercury, at: instant))
        #expect(auckland.totalDays == 22)
        #expect(auckland.day == 12) // already Nov 4 there
    }

    @Test func lastRetrogradeDayCountsDownToZero() throws {
        let status = try #require(calc().status(of: .mercury, at: utc("2026-11-13T09:00")))
        #expect(status.stage == .retrograde)
        #expect(status.daysUntilTarget == 0)
    }

    @Test func postShadowStartsAtTheDirectStation() throws {
        let status = try #require(calc().status(of: .mercury, at: utc("2026-11-13T16:00")))
        #expect(status.stage == .postShadow)
        #expect(status.day == 1)
        #expect(status.windowStart == autumn2026.stationDirect)
        #expect(status.countdownTarget == autumn2026.postShadowEnd)
        #expect(status.daysUntilTarget == 17)
    }

    @Test func directCountsDownToTheNextRetrograde() throws {
        let status = try #require(calc().status(of: .mercury, at: utc("2026-12-20T00:00")))
        #expect(status.stage == .direct)
        #expect(status.period == winter2027)
        #expect(status.windowStart == autumn2026.postShadowEnd)
        #expect(status.countdownTarget == winter2027.stationRetrograde)
        #expect(status.day == 21) // Nov 30 is day 1
        #expect(status.daysUntilTarget == 51)
    }

    @Test func preShadowCountsDownToTheRetrograde() throws {
        let status = try #require(calc().status(of: .mercury, at: utc("2027-02-01T00:00")))
        #expect(status.stage == .preShadow)
        #expect(status.period == winter2027)
        #expect(status.windowStart == winter2027.preShadowStart)
        #expect(status.day == 8)
        #expect(status.daysUntilTarget == 8)
    }

    @Test func stagesChangeExactlyAtEachEvent() {
        let c = calc()
        let second: TimeInterval = 1
        #expect(c.status(of: .mercury, at: winter2027.preShadowStart.addingTimeInterval(-second))?.stage == .direct)
        #expect(c.status(of: .mercury, at: winter2027.preShadowStart)?.stage == .preShadow)
        #expect(c.status(of: .mercury, at: winter2027.stationRetrograde)?.stage == .retrograde)
        #expect(c.status(of: .mercury, at: winter2027.stationDirect)?.stage == .postShadow)
        #expect(c.status(of: .mercury, at: autumn2026.postShadowEnd)?.stage == .direct)
    }

    @Test func progressIsTimeBasedAndClamped() throws {
        let mid = autumn2026.stationRetrograde.addingTimeInterval(autumn2026.stationDirect.timeIntervalSince(autumn2026.stationRetrograde) / 2)
        let status = try #require(calc().status(of: .mercury, at: mid))
        #expect(abs(status.progress - 0.5) < 0.0001)
    }

    @Test func returnsNilBeyondTheData() {
        #expect(calc().status(of: .mercury, at: utc("2026-01-01T00:00")) == nil)
        #expect(calc().status(of: .mercury, at: utc("2027-06-01T00:00")) == nil)
        #expect(calc().status(of: .venus, at: utc("2026-11-03T00:00")) == nil)
    }
}

@Suite struct DayMarkerTests {
    @Test func marksRetrogradeShadowAndDirectDays() {
        let calc = CycleCalculator(ephemeris: ephemeris, calendar: calendar("UTC"))
        #expect(calc.marker(for: .mercury, on: CalendarDay(year: 2026, month: 10, day: 3)) == .direct)
        #expect(calc.marker(for: .mercury, on: CalendarDay(year: 2026, month: 10, day: 4)) == .shadow)
        #expect(calc.marker(for: .mercury, on: CalendarDay(year: 2026, month: 10, day: 24)) == .retrograde)
        #expect(calc.marker(for: .mercury, on: CalendarDay(year: 2026, month: 11, day: 13)) == .retrograde)
        #expect(calc.marker(for: .mercury, on: CalendarDay(year: 2026, month: 11, day: 14)) == .shadow)
        #expect(calc.marker(for: .mercury, on: CalendarDay(year: 2026, month: 11, day: 30)) == .shadow)
        #expect(calc.marker(for: .mercury, on: CalendarDay(year: 2026, month: 12, day: 1)) == .direct)
    }

    @Test func usesTheLocalDayOfTheStation() {
        let honolulu = CycleCalculator(ephemeris: ephemeris, calendar: calendar("Pacific/Honolulu"))
        #expect(honolulu.marker(for: .mercury, on: CalendarDay(year: 2026, month: 10, day: 23)) == .retrograde)
        let utcCalc = CycleCalculator(ephemeris: ephemeris, calendar: calendar("UTC"))
        #expect(utcCalc.marker(for: .mercury, on: CalendarDay(year: 2026, month: 10, day: 23)) == .shadow)
    }
}

@Suite struct CalendarDayTests {
    @Test func arithmetic() {
        let day = CalendarDay(year: 2026, month: 12, day: 30)
        #expect(day.adding(days: 3) == CalendarDay(year: 2027, month: 1, day: 2))
        #expect(day.days(to: CalendarDay(year: 2027, month: 3, day: 1)) == 61)
        #expect(CalendarDay(iso: "2026-11-03") == CalendarDay(year: 2026, month: 11, day: 3))
        #expect(CalendarDay(iso: "nope") == nil)
    }

    @Test func zodiacSignFromLongitude() {
        #expect(ZodiacSign.containing(longitude: 230.979) == .scorpio)
        #expect(ZodiacSign.containing(longitude: 359.99) == .pisces)
        #expect(ZodiacSign.containing(longitude: 360) == .aries)
        #expect(ZodiacSign.containing(longitude: -1) == .pisces)
    }
}
