import AstroData
import Foundation
import RetroCore
import Testing
@testable import HomeWidget

private func calendar(_ zone: String) -> Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: zone)!
    return c
}

private func utc(_ s: String) -> Date {
    try! Date(s + ":00Z", strategy: .iso8601)
}

/// Real Mercury periods from the bundled ephemeris; expectations follow from their instants.
@Suite struct WidgetContentTests {
    let ephemeris: Ephemeris
    let autumn: RetrogradePeriod

    init() throws {
        ephemeris = try BundledEphemeris.load()
        autumn = ephemeris.retrogrades.first { $0.planet == .mercury && CalendarDay($0.stationDirect, in: calendar("UTC")).description == "2026-11-13" }!
    }

    private func timeline(_ zone: String = "UTC") -> WidgetTimeline {
        WidgetTimeline(calculator: CycleCalculator(ephemeris: ephemeris, calendar: calendar(zone)), calendar: calendar(zone))
    }

    @Test func retrogradeMatchesTheOverview() throws {
        let content = try #require(timeline("Europe/London").content(at: utc("2026-11-03T12:00")))
        #expect(content.planetName == "MERCURY")
        #expect(content.phaseName == "RETROGRADE")
        #expect(content.countdown == "10")
        #expect(content.countdownText == "days to exhale")
        #expect(content.leading == "DAY 11 / 21")
        #expect(content.trailing == "DIRECT")
        #expect(content.accessibilityLabel == "Mercury retrograde. 10 days to exhale. Day 11 of 21.")
    }

    @Test func allFourPhasesUseTheOverviewWords() throws {
        let t = timeline()
        let pre = try #require(t.content(at: autumn.stationRetrograde - 5 * 86_400))
        #expect(pre.phaseName == "PRE-SHADOW" && pre.countdownText == "days till the slowdown")
        #expect(pre.leading.hasPrefix("SHADOW · DAY ") && pre.trailing == "RETROGRADE")
        let rx = try #require(t.content(at: autumn.stationRetrograde + 86_400))
        #expect(rx.phaseName == "RETROGRADE" && rx.countdownText == "days to exhale")
        let post = try #require(t.content(at: autumn.stationDirect + 5 * 86_400))
        #expect(post.phaseName == "POST-SHADOW" && post.countdownText == "days till the dust settles" && post.trailing == "ALL CLEAR")
        let direct = try #require(t.content(at: autumn.postShadowEnd + 10 * 86_400))
        #expect(direct.phaseName == "DIRECT" && direct.countdownText == "days till the next plot twist")
        // The direct stage has no day count, as on the Overview: the bar's own labels instead.
        #expect(direct.leading == "DIRECT" && direct.trailing == "NEXT RX")
        #expect(direct.accessibilityLabel.hasSuffix("days till the next plot twist."))
    }

    @Test func countdownAndProgressComeFromTheSharedCalculation() throws {
        let instant = autumn.stationRetrograde + 7.5 * 86_400
        let status = try #require(CycleCalculator(ephemeris: ephemeris, calendar: calendar("Asia/Tokyo")).status(of: .mercury, at: instant))
        let content = try #require(timeline("Asia/Tokyo").content(at: instant))
        #expect(content.countdown == "\(status.daysUntilTarget)")
        #expect(content.leading == "DAY \(status.day) / \(status.totalDays)")
        #expect(content.progress == status.progress)
        let expected = instant.timeIntervalSince(autumn.stationRetrograde) / autumn.stationDirect.timeIntervalSince(autumn.stationRetrograde)
        #expect(abs(content.progress - expected) < 1e-9)
    }

    @Test func phaseBoundariesFlipAtTheExactInstant() throws {
        let t = timeline()
        let lastRx = try #require(t.content(at: autumn.stationDirect - 1))
        #expect(lastRx.phaseName == "RETROGRADE" && lastRx.countdown == "TODAY" && lastRx.countdownText == "Mercury turns direct")
        #expect(lastRx.accessibilityLabel == "Mercury retrograde. Today, Mercury turns direct. Day 21 of 21.")
        #expect(t.content(at: autumn.stationDirect)?.phaseName == "POST-SHADOW")
        #expect(t.content(at: autumn.stationRetrograde - 1)?.phaseName == "PRE-SHADOW")
        #expect(t.content(at: autumn.stationRetrograde)?.phaseName == "RETROGRADE")
        #expect(t.content(at: autumn.postShadowEnd - 1)?.phaseName == "POST-SHADOW")
        #expect(t.content(at: autumn.postShadowEnd)?.phaseName == "DIRECT")
        #expect(t.content(at: autumn.preShadowStart - 1)?.phaseName == "DIRECT")
        #expect(t.content(at: autumn.preShadowStart)?.phaseName == "PRE-SHADOW")
        #expect(t.content(at: autumn.preShadowStart)?.progress == 0)
    }

    @Test func singularDay() throws {
        // Mercury turns direct on Nov 13 (UTC); at noon on Nov 12 that's one day away.
        let content = try #require(timeline().content(at: utc("2026-11-12T12:00")))
        #expect(content.countdown == "1" && content.countdownText == "day to exhale")
    }

    @Test func outsideTheDataThereIsNoContent() {
        #expect(timeline().content(at: utc("2040-01-01T00:00")) == nil)
    }
}

@Suite struct WidgetTimelineTests {
    let ephemeris: Ephemeris
    let autumn: RetrogradePeriod

    init() throws {
        ephemeris = try BundledEphemeris.load()
        autumn = ephemeris.retrogrades.first { $0.planet == .mercury && CalendarDay($0.stationDirect, in: calendar("UTC")).description == "2026-11-13" }!
    }

    private func timeline(_ zone: String) -> WidgetTimeline {
        WidgetTimeline(calculator: CycleCalculator(ephemeris: ephemeris, calendar: calendar(zone)), calendar: calendar(zone))
    }

    @Test func entriesAtNowEachLocalMidnightAndTheStageChange() throws {
        let zone = "America/Los_Angeles"
        let cal = calendar(zone)
        let now = autumn.stationDirect - 20 * 3_600 // the day before Mercury turns direct
        let entries = timeline(zone).entries(from: now)
        #expect(entries.first?.date == now)
        #expect(entries.map(\.date) == entries.map(\.date).sorted())
        #expect(Set(entries.map(\.date)).count == entries.count)
        // The station itself is an entry, and it shows the new stage from that instant.
        let change = try #require(entries.first { $0.date == autumn.stationDirect })
        #expect(change.content?.phaseName == "POST-SHADOW")
        #expect(entries.last { $0.date < autumn.stationDirect }?.content?.phaseName == "RETROGRADE")
        // Two local midnights, nothing else: a handful of entries, not one per minute.
        let midnights = entries.dropFirst().filter { $0.date != autumn.stationDirect }
        #expect(midnights.count == WidgetTimeline.horizonDays)
        #expect(midnights.allSatisfy { cal.dateComponents([.hour, .minute], from: $0.date) == DateComponents(hour: 0, minute: 0) })
        #expect(entries.count == 4)
    }

    @Test func countdownStepsDownAtEachMidnight() throws {
        let now = autumn.stationRetrograde + 3 * 86_400
        let entries = timeline("Europe/Berlin").entries(from: now)
        let counts = entries.compactMap { $0.content.flatMap { Int($0.countdown) } }
        #expect(counts.count == 3)
        #expect(zip(counts, counts.dropFirst()).allSatisfy { $0 - $1 == 1 })
        let progress = entries.compactMap { $0.content?.progress }
        #expect(progress == progress.sorted() && progress.first! < progress.last!)
    }

    @Test func daylightSavingMidnightsStayAtMidnight() {
        // US clocks go back on Nov 1, 2026: that local day is 25 hours long.
        let zone = "America/New_York"
        let cal = calendar(zone)
        let now = utc("2026-10-31T16:00") // midday Oct 31 in New York
        let midnights = timeline(zone).entries(from: now).dropFirst().map(\.date)
        #expect(midnights.count == 2)
        #expect(midnights.allSatisfy { cal.component(.hour, from: $0) == 0 })
        #expect(midnights[1].timeIntervalSince(midnights[0]) == 25 * 3_600)
        #expect(timeline(zone).refreshDate(after: now) == midnights[0])
    }

    @Test func timeZonesGetTheirOwnMidnights() {
        let now = utc("2026-11-05T12:00")
        let tokyo = timeline("Asia/Tokyo").entries(from: now).dropFirst().map(\.date)
        let la = timeline("America/Los_Angeles").entries(from: now).dropFirst().map(\.date)
        #expect(tokyo != la)
        #expect(tokyo.allSatisfy { calendar("Asia/Tokyo").component(.hour, from: $0) == 0 })
        #expect(la.allSatisfy { calendar("America/Los_Angeles").component(.hour, from: $0) == 0 })
    }

    @Test func eachStageAcrossTheCycleIsReached() {
        // Walking day by day through a whole cycle, every entry has content and all four stages appear.
        var seen = Set<String>()
        var instant = autumn.preShadowStart - 10 * 86_400
        while instant < autumn.postShadowEnd + 10 * 86_400 {
            for entry in timeline("UTC").entries(from: instant) {
                if let phase = entry.content?.phaseName { seen.insert(phase) }
            }
            instant += 86_400
        }
        #expect(seen == ["DIRECT", "PRE-SHADOW", "RETROGRADE", "POST-SHADOW"])
    }

    @Test func missingDataStillGivesATimeline() {
        let empty = Ephemeris(coverage: CalendarDay(year: 2026, month: 1, day: 1)...CalendarDay(year: 2026, month: 12, day: 31), retrogrades: [])
        let cal = calendar("UTC")
        let t = WidgetTimeline(calculator: CycleCalculator(ephemeris: empty, calendar: cal), calendar: cal)
        let now = utc("2026-06-01T10:00")
        let entries = t.entries(from: now)
        #expect(!entries.isEmpty && entries.allSatisfy { $0.content == nil })
        #expect(t.refreshDate(after: now) == utc("2026-06-02T00:00"))
    }
}
