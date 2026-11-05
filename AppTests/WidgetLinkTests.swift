#if os(iOS)
import Foundation
import Testing
@testable import Retrograde

/// Tapping the Home Screen widget opens the Overview, whatever was showing.
@MainActor
@Suite struct WidgetLinkTests {
    @Test func widgetTapOpensTheOverview() {
        #expect(WidgetLink.opensOverview(WidgetLink.overview))
        let router = AppRouter(tab: .calendar)
        router.showsSettings = true
        router.openOverview()
        #expect(router.tab == .overview && !router.showsSettings && !router.showsNotificationCenter)
    }

    @Test func otherLinksAreIgnored() {
        #expect(!WidgetLink.opensOverview(URL(string: "retrograde://calendar")!))
        #expect(!WidgetLink.opensOverview(URL(string: "https://example.com/overview")!))
    }
}
#endif
