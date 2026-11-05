import AstroData
import Editorial
import Foundation
import RetroCore
import Testing
@testable import Sharing

private let enUS = Locale(identifier: "en_US")

@Suite struct InsightShareCardTests {
    let intensity: IntensityCalculator
    let today = CalendarDay(year: 2026, month: 11, day: 4)

    init() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        intensity = IntensityCalculator(ephemeris: try BundledEphemeris.load(), calendar: utc)
    }

    private func content(_ day: CalendarDay, premium: Bool = false) -> DayDetailContent {
        DayDetailContent.make(day: day, today: today, isPremium: premium, policy: .launch, intensity: intensity)!
    }

    @Test func todaysCardUsesTheCalendarsWords() throws {
        let card = try #require(InsightShareCard(content(today)))
        #expect(card.dateTitle(locale: enUS) == "Wednesday, Nov 4, 2026")
        #expect(card.levelName == "Elevated")
        #expect(card.levelPosition == "03 / 04")
        #expect(card.summary == "Review-mode Mercury. Revisit before you send, and leave room for replies to wander.")
        #expect(card.habit == "Ask a clarifying question instead of assuming.")
    }

    /// The card is for the day being viewed, not today: its copy is that day's own.
    @Test func anotherDayGetsItsOwnInsight() throws {
        let day = today.adding(days: 2)
        let viewed = content(day)
        guard case let .unlocked(insight, _) = viewed.details else { Issue.record("should be unlocked"); return }
        let card = try #require(InsightShareCard(viewed))
        #expect(card.day == day)
        #expect(card.dateTitle(locale: enUS) == "Friday, Nov 6, 2026")
        #expect(card.level == viewed.level)
        #expect(card.summary == insight.summary)
        #expect(card.habit == insight.habit.text)
        let todays = try #require(InsightShareCard(content(today)))
        #expect(card.summary != todays.summary || card.habit != todays.habit)
    }

    @Test func lockedDaysCantBeShared() throws {
        #expect(InsightShareCard(content(today.adding(days: 6))) == nil)
        #expect(InsightShareCard(content(today.adding(days: -3))) == nil)
        // Premium unlocks them, past days included.
        #expect(InsightShareCard(content(today.adding(days: 6), premium: true)) != nil)
        #expect(InsightShareCard(content(today.adding(days: -3), premium: true)) != nil)
    }

    @Test func textAlternativeCoversTheWholeCard() throws {
        let card = try #require(InsightShareCard(content(today)))
        #expect(card.text(locale: enUS) == """
            Wednesday, Nov 4, 2026
            Retrograde intensity: Elevated (3 of 4)
            Review-mode Mercury. Revisit before you send, and leave room for replies to wander.
            Good habit for this day: Ask a clarifying question instead of assuming.
            — Retrograde
            """)
        let link = URL(string: "https://apps.apple.com/app/id123")!
        #expect(card.text(locale: enUS, appStoreURL: link).hasSuffix("— Retrograde\nhttps://apps.apple.com/app/id123"))
    }

    /// The date is the wall-calendar day whatever the time zone.
    @Test func dateDoesNotShiftWithTimeZone() throws {
        let card = try #require(InsightShareCard(content(today)))
        #expect(card.dateTitle(locale: Locale(identifier: "en_GB")).contains("4 Nov 2026"))
    }
}

@Suite struct AppInvitationTests {
    @Test func withoutALinkOnlyTheMessageIsShared() {
        let invitation = AppInvitation(appStoreURL: nil)
        #expect(invitation.text == AppInvitation.message)
        #expect(!invitation.text.contains("http"))
    }

    @Test func linkFollowsTheMessage() {
        let invitation = AppInvitation(appStoreURL: URL(string: "https://apps.apple.com/app/id123")!)
        #expect(invitation.text == AppInvitation.message + "\nhttps://apps.apple.com/app/id123")
    }
}

@MainActor
@Suite struct SharingActivityTests {
    let at = Date(timeIntervalSince1970: 1_793_800_000)

    @Test func onlyCompletedSharesAreRecorded() {
        let activity = SharingActivity(defaults: nil)
        activity.shareSheetFinished(.app, completed: false, at: at)
        #expect(activity.records.isEmpty)
        activity.shareSheetFinished(.app, completed: true, at: at)
        #expect(activity.records == [ShareRecord(item: .app, sharedAt: at)])
    }

    @Test func appAndInsightSharesAreDistinct() {
        let activity = SharingActivity(defaults: nil)
        let nov4 = CalendarDay(year: 2026, month: 11, day: 4), nov6 = CalendarDay(year: 2026, month: 11, day: 6)
        activity.shareSheetFinished(.app, completed: true, at: at)
        activity.shareSheetFinished(.dailyInsight(nov6), completed: true, at: at + 1)
        activity.shareSheetFinished(.dailyInsight(nov4), completed: true, at: at + 2)
        activity.shareSheetFinished(.dailyInsight(nov6), completed: true, at: at + 3)
        #expect(activity.appShareCount == 1)
        #expect(activity.sharedInsightDays == [nov6, nov4])
        #expect(activity.records.map(\.item.insightDay) == [nil, nov6, nov4, nov6])
    }

    @Test func recentListsTheLatestFirst() {
        let activity = SharingActivity(defaults: nil)
        #expect(activity.recent(3).isEmpty)
        for i in 0..<5 { activity.shareSheetFinished(.app, completed: true, at: at + Double(i)) }
        #expect(activity.recent(3).map(\.sharedAt) == [at + 4, at + 3, at + 2])
    }

    @Test func historySurvivesARelaunch() throws {
        let defaults = try #require(UserDefaults(suiteName: "SharingActivityTests.\(UUID())"))
        let day = CalendarDay(year: 2026, month: 11, day: 7)
        SharingActivity(defaults: defaults).shareSheetFinished(.dailyInsight(day), completed: true, at: at)
        let reloaded = SharingActivity(defaults: defaults)
        #expect(reloaded.records == [ShareRecord(item: .dailyInsight(day: "2026-11-07"), sharedAt: at)])
    }

    @Test func historyStaysSmall() {
        let activity = SharingActivity(defaults: nil)
        for i in 0..<(SharingActivity.limit + 5) { activity.shareSheetFinished(.app, completed: true, at: at + Double(i)) }
        #expect(activity.records.count == SharingActivity.limit)
        #expect(activity.records.first?.sharedAt == at + 5)
    }
}
