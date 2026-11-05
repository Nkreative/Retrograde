#if os(iOS)
import Editorial
import RetroCore
import Sharing
import SwiftUI
import Testing
import UIKit
@testable import Retrograde

@MainActor
@Suite struct ShareTests {
    /// Every date in the sky data: the card's words fit its fixed 4:5 frame, so nothing is cut off
    /// whichever summary and habit a day gets.
    @Test func everyDaysCardFitsWithoutClipping() throws {
        let intensity = try #require(SkyData.intensity())
        let coverage = try #require(SkyData.ephemeris?.coverage)
        var cards: [String: InsightShareCard] = [:]
        var day = coverage.lowerBound
        while day <= coverage.upperBound {
            let content = try #require(DayDetailContent.make(day: day, today: day, isPremium: true, policy: .launch, intensity: intensity))
            let card = try #require(InsightShareCard(content))
            cards[card.levelName + card.summary + card.habit] = card
            day = day.adding(days: 1)
        }
        let width = InsightShareCardView.size.width - 48
        var tallest: CGFloat = 0
        for card in cards.values {
            let host = UIHostingController(rootView: InsightShareCardView(card: card).content.frame(width: width).dynamicTypeSize(.large))
            let height = host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height + 48
            #expect(height <= InsightShareCardView.size.height, "\(card.day): \(height) pt")
            tallest = max(tallest, height)
        }
        // A real measurement, not an empty layout: the words take most of the card.
        #expect(cards.count > 20 && tallest > 360, "\(cards.count) cards, tallest \(tallest) pt")
        print("ShareTests: \(cards.count) distinct cards, tallest \(tallest) of \(InsightShareCardView.size.height) pt")
    }

    @Test func cardRendersAt1080By1350() throws {
        let intensity = try #require(SkyData.intensity())
        let today = CalendarDay(year: 2026, month: 11, day: 4)
        let content = try #require(DayDetailContent.make(day: today, today: today, isPremium: false, policy: .launch, intensity: intensity))
        let card = try #require(InsightShareCard(content))
        let image = try #require(InsightShareCardView(card: card).render())
        #expect(image.size.width * image.scale == 1080)
        #expect(image.size.height * image.scale == 1350)
    }

    /// The header's share button opens the invite; any other header sheet closes.
    @Test func headerShareOpensTheInvite() {
        let router = AppRouter(tab: .calendar)
        router.showsSettings = true
        router.openShareInvite()
        #expect(router.showsShareInvite && !router.showsSettings && !router.showsNotificationCenter)
        router.openOverview()
        #expect(!router.showsShareInvite)
    }
}
#endif
