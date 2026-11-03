import Foundation
import Testing
import RetroCore
@testable import AstroData

@Suite struct BundledEphemerisTests {
    let ephemeris: Ephemeris

    init() throws {
        ephemeris = try BundledEphemeris.load()
    }

    @Test func coversLaunchRange() {
        #expect(ephemeris.coverage == CalendarDay(year: 2025, month: 1, day: 1)...CalendarDay(year: 2030, month: 12, day: 31))
        #expect(Set(ephemeris.retrogrades.map(\.planet)) == Set(Planet.allCases))
        #expect(ephemeris.sources.count == 2)
    }

    @Test func mercuryIsRetrogradeOnNovember3rd2026() throws {
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!
        let now = try #require(BundledEphemeris.parseMinute("2026-11-03T12:00Z"))
        let status = try #require(CycleCalculator(ephemeris: ephemeris, calendar: london).status(of: .mercury, at: now))
        #expect(status.stage == .retrograde)
        #expect(status.day == 11)
        #expect(status.totalDays == 21)
        #expect(status.daysUntilTarget == 10)
        #expect(CalendarDay(status.countdownTarget, in: london) == CalendarDay(year: 2026, month: 11, day: 13))
    }

    @Test func everyStageOccursAroundMercurysAutumn2026Retrograde() throws {
        let calc = CycleCalculator(ephemeris: ephemeris, calendar: Self.utc)
        let expected: [(String, CycleStatus.Stage)] = [
            ("2026-09-20T12:00Z", .direct), ("2026-10-10T12:00Z", .preShadow),
            ("2026-11-03T12:00Z", .retrograde), ("2026-11-20T12:00Z", .postShadow), ("2026-12-20T12:00Z", .direct),
        ]
        for (time, stage) in expected {
            let instant = try #require(BundledEphemeris.parseMinute(time))
            #expect(calc.status(of: .mercury, at: instant)?.stage == stage, "\(time)")
        }
    }

    /// Independent values: Skyfield + JPL DE440s, matching published ephemerides (see tools/ephemeris/known_dates.json).
    @Test func mercuryAutumn2026MatchesIndependentCalculation() throws {
        let period = try #require(ephemeris.retrogrades(of: .mercury).first {
            CalendarDay($0.stationRetrograde, in: Self.utc) == CalendarDay(year: 2026, month: 10, day: 24)
        })
        let expected = [
            (period.preShadowStart, "2026-10-04T09:09Z"), (period.stationRetrograde, "2026-10-24T07:13Z"),
            (period.stationDirect, "2026-11-13T15:54Z"), (period.postShadowEnd, "2026-11-30T06:16Z"),
        ]
        for (actual, reference) in expected {
            let date = try #require(BundledEphemeris.parseMinute(reference))
            #expect(abs(actual.timeIntervalSince(date)) <= 120, "\(actual) vs \(reference)")
        }
        #expect(period.stationRetrogradeSign == .scorpio)
        #expect(period.stationDirectSign == .scorpio)
    }

    private static let utc: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    @Test func statusIsAvailableAcrossTheWholeCoverage() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let calc = CycleCalculator(ephemeris: ephemeris, calendar: utc)
        var day = ephemeris.coverage.lowerBound
        while day <= ephemeris.coverage.upperBound {
            #expect(calc.status(of: .mercury, at: day.start(in: utc)) != nil, "no Mercury status on \(day)")
            day = day.adding(days: 1)
        }
    }

    @Test func rejectsUnknownSchema() {
        let json = #"{"schemaVersion":2,"coverage":{"start":"2025-01-01","end":"2025-12-31"},"sources":[],"retrogrades":[],"ingresses":[],"moonPhases":[]}"#
        #expect(throws: BundledEphemeris.LoadError.self) { try BundledEphemeris.decode(Data(json.utf8)) }
    }

    @Test func parsesTimestamps() {
        #expect(BundledEphemeris.parseMinute("2026-10-24T07:10Z") == (try? Date("2026-10-24T07:10:00Z", strategy: .iso8601)))
        #expect(BundledEphemeris.parseMinute("2026-10-24 07:10") == nil)
    }
}
