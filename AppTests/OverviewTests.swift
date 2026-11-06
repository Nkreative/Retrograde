import Editorial
import Foundation
import Persistence
import RetroCore
import SurvivalKit
import Testing
import UIKit
@testable import Retrograde

@MainActor
@Suite struct OverviewNavigationTests {
    @Test func continueOpensTheNextTaskInTheKit() throws {
        let router = AppRouter()
        let task = try #require(SurvivalKit.for(.mercury)?.tasks.last)
        router.openKit(at: task)
        #expect(router.tab == .survivalKit && router.kitTask == task)
    }

    @Test func todayOpensInTheCalendar() {
        let router = AppRouter()
        let day = CalendarDay(year: 2026, month: 11, day: 5)
        router.openCalendar(on: day)
        #expect(router.tab == .calendar && router.calendarFocus == day)
    }

    @Test func widgetHowToReplacesOtherHeaderSheets() {
        let router = AppRouter()
        router.openSettings()
        router.openWidgetHowTo()
        #expect(router.showsWidgetHowTo && !router.showsSettings)
        router.openOverview() // a widget tap closes it
        #expect(!router.showsWidgetHowTo)
    }
}

@MainActor
@Suite struct OverviewDashboardTests {
    @Test func everyLevelHasItsOwnFigmaArtwork() {
        let art = IntensityLevel.allCases.map(IntensityArtwork.for)
        #expect(art.map(\.image) == ["IntensityCalm", "IntensityMild", "IntensityElevated", "IntensityIntense"])
        #expect(art.map(\.diameter) == [69, 118, 156, 283]) // Mercury grows with the level, as in Figma
    }

    @Test func artworkIsSharpAtTheCardSize() throws {
        for level in IntensityLevel.allCases {
            let image = try #require(UIImage(named: IntensityArtwork.for(level).image), "\(level)")
            // The Figma card's size, at 3× (Retina) resolution.
            #expect(image.size == IntensityArtwork.canvas, "\(level)")
            #expect(image.scale == 3, "\(level)")
        }
    }

    @Test func todayUsesTheCalendarsOwnExplanation() throws {
        let intensity = try #require(SkyData.intensity())
        // Days at each level in the bundled data (US Eastern days; the app's calendar decides).
        for iso in ["2026-12-01", "2026-11-14", "2026-11-03", "2026-11-13"] {
            let day = try #require(CalendarDay(iso: iso))
            let today = try #require(OverviewToday.make(today: day, intensity: intensity))
            let reading = try #require(intensity.intensity(on: day))
            #expect(today.level == reading.level)
            #expect(today.summary == DailyInsightCopy.insight(for: reading).summary)
        }
        let days = ["2026-12-01", "2026-11-14", "2026-11-03", "2026-11-13"].compactMap(CalendarDay.init(iso:))
        let summaries = days.compactMap { OverviewToday.make(today: $0, intensity: intensity)?.summary }
        #expect(summaries.count == 4)
        #expect(Set(summaries).count > 1) // not one sentence for every day
    }

    @Test func intensityCardOpensTodayInTheCalendar() {
        let router = AppRouter()
        let today = CalendarDay(year: 2026, month: 11, day: 5)
        router.open(overview: .today(today))
        #expect(router.tab == .calendar && router.calendarFocus == today)
    }

    @Test func cycleSectionOpensTheSurvivalKit() {
        let router = AppRouter()
        router.open(overview: .survivalKit)
        #expect(router.tab == .survivalKit && router.kitTask == nil)
    }

    @Test func sharingCardOpensTheShareScreen() {
        let router = AppRouter()
        router.open(overview: .shareInvite)
        #expect(router.showsShareInvite && router.tab == .overview)
    }

    @Test func addWidgetPillFollowsWidgetDetection() {
        let prompt = WidgetPrompt(defaults: nil)
        #expect(OverviewLayout.showsWidgetPill(prompt))
        prompt.record(widgetCount: 2)
        #expect(!OverviewLayout.showsWidgetPill(prompt))
        prompt.dismissTip() // the old dashboard tip's ✕ doesn't hide the pill
        prompt.record(widgetCount: 0)
        #expect(OverviewLayout.showsWidgetPill(prompt))
        let router = AppRouter()
        router.open(overview: .widgetHowTo)
        #expect(router.showsWidgetHowTo)
    }

    @Test func spacingGrowsOnTallerScreensOnly() {
        #expect(OverviewLayout.gapStretch(viewportHeight: 0) == 1) // not measured yet
        #expect(OverviewLayout.gapStretch(viewportHeight: 580) == 1)
        #expect(OverviewLayout.gapStretch(viewportHeight: 696) > 1.19 && OverviewLayout.gapStretch(viewportHeight: 696) < 1.21)
        #expect(OverviewLayout.gapStretch(viewportHeight: 2000) == 1.5)
    }

    @Test func dashboardOnlyAfterTheKitIsStarted() {
        #expect(OverviewMode(kitStarted: false) == .introduction)
        let activation = SurvivalKitActivation(defaults: nil)
        #expect(OverviewMode(kitStarted: activation.isStarted) == .introduction)
        activation.start()
        #expect(OverviewMode(kitStarted: activation.isStarted) == .dashboard)
    }
}

@MainActor
@Suite struct CalendarSkyDetailsTests {
    private func day(_ iso: String) -> CalendarDay { CalendarDay(iso: iso)! }

    @Test func summaryNamesThePlanetsRetrograde() throws {
        let intensity = try #require(SkyData.intensity())
        let planets = intensity.retrogrades(on: day("2026-11-05")).map(\.planet)
        #expect(planets.count == 5)
        #expect(SkySummary.line(planets: planets, rows: []).hasSuffix("and 3 more planets"))
        #expect(SkySummary.line(planets: [.mercury], rows: []) == "Mercury retrograde")
        #expect(SkySummary.line(planets: [], rows: []) == "A quiet sky")
    }

    @Test func eachPlanetIsListedOnce() throws {
        let intensity = try #require(SkyData.intensity())
        let content = try #require(DayDetailContent.make(day: day("2026-11-05"), today: day("2026-11-05"), isPremium: true, policy: .launch, intensity: intensity))
        guard case let .unlocked(insight, others) = content.details else { Issue.record("locked"); return }
        let also = SkySummary.alsoRetrograde(others, rows: insight.rows)
        let withRows = Set(insight.rows.map(\.title))
        // Venus has its own event row, so it isn't repeated under "Also retrograde".
        #expect(withRows.contains("Venus retrograde"))
        #expect(!also.contains { $0.planet == .venus })
        #expect(also.count == others.count - 1)
    }

    @Test func freeUsersStillGetTheLockedDay() throws {
        let intensity = try #require(SkyData.intensity())
        let locked = try #require(DayDetailContent.make(day: day("2026-11-12"), today: day("2026-11-05"), isPremium: false, policy: .launch, intensity: intensity))
        guard case .locked = locked.details else { Issue.record("Nov 12 should be locked for free users"); return }
    }
}
