import Foundation
import Testing
import RetroCore
@testable import AstroData

/// Pins methodology v1 against the verified data. If any of these change, the methodology
/// changed: update docs/INTENSITY_METHODOLOGY.md and bump `IntensityCalculator.methodologyVersion`.
@Suite struct DailyIntensityTests {
    let ephemeris: Ephemeris

    init() throws {
        ephemeris = try BundledEphemeris.load()
    }

    private func calculator(_ zone: String) -> IntensityCalculator {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: zone)!
        return IntensityCalculator(ephemeris: ephemeris, calendar: c)
    }

    private func day(_ s: String) -> CalendarDay { CalendarDay(iso: s)! }

    @Test func levelThresholds() {
        #expect((0...6).map { IntensityLevel(score: $0) } == [.calm, .mild, .mild, .elevated, .elevated, .intense, .intense])
    }

    @Test func mercuryStationDaysAreIntense() throws {
        let calc = calculator("Europe/London")
        for date in ["2026-10-24", "2026-11-13"] {
            let reading = try #require(calc.intensity(on: day(date)))
            #expect(reading.level == .intense, "\(date)")
            #expect(reading.influences.first?.points == IntensityCalculator.Points.mercuryStation)
        }
    }

    @Test func autumn2026Walkthrough() throws {
        let calc = calculator("UTC")
        let expected: [(String, Int, IntensityLevel)] = [
            ("2026-10-22", 2, .mild),      // Venus Rx + Mercury pre-shadow
            ("2026-10-23", 3, .elevated),  // + day before the station
            ("2026-10-24", 6, .intense),   // Venus Rx + Mercury Rx + station
            ("2026-10-26", 4, .elevated),  // + Full Moon
            ("2026-11-03", 3, .elevated),
            ("2026-11-14", 4, .elevated),  // Venus stations direct, day after Mercury's
            ("2026-11-20", 1, .mild),      // Mercury post-shadow
            ("2026-12-02", 0, .calm),
        ]
        for (date, score, level) in expected {
            let reading = try #require(calc.intensity(on: day(date)))
            #expect(reading.score == score, "\(date)")
            #expect(reading.level == level, "\(date)")
        }
    }

    @Test func retrogradeDayCountIsLocal() throws {
        let reading = try #require(calculator("Europe/London").intensity(on: day("2026-11-03")))
        #expect(reading.influences.contains { $0.kind == .mercuryRetrograde(day: 11, totalDays: 21) })
    }

    @Test func stationDayFollowsTheLocalCalendar() throws {
        // 07:13 UT on 24 Oct is still 23 Oct in Honolulu.
        let honolulu = calculator("Pacific/Honolulu")
        #expect(try #require(honolulu.intensity(on: day("2026-10-23"))).level == .intense)
        #expect(try #require(honolulu.intensity(on: day("2026-10-24"))).level == .elevated)
    }

    @Test func distributionPerYearMatchesCalibration() {
        // UTC days; independently computed by tools/intensity/calibrate.py on the same file.
        let expected: [Int: [Int]] = [
            2025: [118, 205, 36, 6], 2026: [161, 167, 31, 6], 2027: [146, 175, 38, 6],
            2028: [159, 162, 39, 6], 2029: [101, 222, 35, 7], 2030: [149, 183, 26, 7],
        ]
        let calc = calculator("UTC")
        for (year, counts) in expected {
            var tally = [IntensityLevel: Int]()
            var d = CalendarDay(year: year, month: 1, day: 1)
            while d.year == year {
                tally[calc.intensity(on: d)!.level, default: 0] += 1
                d = d.adding(days: 1)
            }
            #expect(IntensityLevel.allCases.map { tally[$0, default: 0] } == counts, "\(year)")
        }
    }

    @Test func planetsRetrogradeOnADay() {
        let calc = calculator("UTC")
        let nov3 = calc.retrogrades(on: day("2026-11-03")).map(\.planet)
        #expect(nov3 == [.mercury, .venus, .saturn, .uranus, .neptune])
        let mercury = calc.retrogrades(on: day("2026-11-03")).first!
        #expect(mercury.from == day("2026-10-24") && mercury.to == day("2026-11-13"))
        // Venus stations direct at 00:28 UT on 14 Nov: retrograde that day in UTC, not in New York.
        #expect(calc.retrogrades(on: day("2026-11-14")).map(\.planet).contains(.venus))
        #expect(!calculator("America/New_York").retrogrades(on: day("2026-11-14")).map(\.planet).contains(.venus))
        #expect(calc.retrogrades(on: day("2031-06-01")).isEmpty)
    }

    @Test func outsideCoverageHasNoReading() {
        #expect(calculator("UTC").intensity(on: day("2031-06-01")) == nil)
    }

    @Test func isDeterministic() {
        let a = calculator("America/New_York").intensity(on: day("2027-02-09"))!
        let b = calculator("America/New_York").intensity(on: day("2027-02-09"))!
        #expect(a.influences == b.influences)
        #expect(a.methodologyVersion == 1)
    }
}
