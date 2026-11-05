import Foundation
import RetroCore
import SurvivalKit
import Testing
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
