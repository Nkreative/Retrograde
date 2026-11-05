import Foundation
import Testing
@testable import Persistence

@MainActor
@Suite struct WidgetPromptTests {
    private func defaults() throws -> (UserDefaults, () -> Void) {
        let suite = "widget-prompt-\(UUID())"
        let d = try #require(UserDefaults(suiteName: suite))
        return (d, { d.removePersistentDomain(forName: suite) })
    }

    @Test func offeredUntilIOSListsAWidget() {
        let p = WidgetPrompt(defaults: nil)
        #expect(p.offersWidget && p.showsTip)
        p.record(widgetCount: 1)
        #expect(!p.offersWidget && !p.showsTip)
    }

    @Test func severalWidgetsCountTheSameAsOne() {
        let p = WidgetPrompt(defaults: nil)
        p.record(widgetCount: 3)
        #expect(!p.offersWidget)
        p.record(widgetCount: 2) // one of three removed
        #expect(!p.offersWidget)
    }

    @Test func removingTheLastWidgetOffersItAgain() {
        let p = WidgetPrompt(defaults: nil)
        p.record(widgetCount: 1)
        p.record(widgetCount: 0)
        #expect(p.offersWidget && p.showsTip)
    }

    @Test func dismissedTipStaysHiddenUntilAWidgetComesAndGoes() {
        let p = WidgetPrompt(defaults: nil)
        p.dismissTip()
        #expect(p.offersWidget && !p.showsTip) // the pill isn't dismissible; the tip is
        p.record(widgetCount: 0)
        #expect(!p.showsTip) // no widget seen yet: stays dismissed
        p.record(widgetCount: 1)
        p.record(widgetCount: 0)
        #expect(p.showsTip) // listed, then removed
    }

    @Test func aFailedCheckChangesNothing() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        WidgetPrompt(defaults: d).record(widgetCount: 1)
        // A failed check records nothing, so a relaunch keeps the last answer.
        #expect(!WidgetPrompt(defaults: d).offersWidget)
    }

    @Test func keepsTheEarlierDismissal() throws {
        let (d, cleanup) = try defaults(); defer { cleanup() }
        d.set(true, forKey: WidgetPrompt.legacyDismissedKey)
        #expect(!WidgetPrompt(defaults: d).showsTip)
    }
}
