import Foundation
import Notifications
import RetroCore
import Testing
@testable import Retrograde

@MainActor
@Suite struct HeaderNavigationTests {
    @Test func bellOpensNotificationCenterOnly() {
        let router = AppRouter()
        router.openNotificationCenter()
        #expect(router.showsNotificationCenter && !router.showsSettings)
    }

    @Test func gearOpensSettingsOnly() {
        let router = AppRouter()
        router.openNotificationCenter()
        router.openSettings()
        #expect(router.showsSettings && !router.showsNotificationCenter)
    }

    @Test func notificationOpensItsCalendarDay() {
        let router = AppRouter()
        router.openNotificationCenter()
        router.open(.calendarDay("2026-11-13"))
        #expect(!router.showsNotificationCenter)
        #expect(router.tab == .calendar && router.calendarFocus == CalendarDay(year: 2026, month: 11, day: 13))
    }

    @Test func notificationOpensItsKitSection() {
        let router = AppRouter()
        router.open(.survivalKitSection("journal"))
        #expect(router.tab == .survivalKit && router.kitFocus == "journal")
    }

    @Test func malformedDestinationIsIgnored() {
        let router = AppRouter(tab: .overview)
        router.open(.calendarDay("not-a-date"))
        #expect(router.tab == .overview && router.calendarFocus == nil)
    }
}

@Suite struct LegalAndSupportTests {
    @Test func termsAreTheSameDestinationEverywhere() {
        #expect(LegalPage.terms.url == AppLinks.termsOfUse)
        #expect(SettingsRoute.availability(of: .legal(.terms)))
    }

    @Test func privacyIsOfferedOnlyWhenConfigured() {
        #expect(LegalPage.privacy.url == AppLinks.privacyPolicy)
        #expect(SettingsRoute.availability(of: .legal(.privacy)) == (AppLinks.privacyPolicy != nil))
    }

    @Test func supportNeverInventsAContact() {
        let none = SupportContact(email: nil, page: nil)
        #expect(!none.isAvailable && none.mailURL == nil)
        let email = SupportContact(email: "help@nkreative.test", page: nil)
        #expect(email.isAvailable && email.mailURL?.scheme == "mailto")
        #expect(email.mailURL?.absoluteString.hasPrefix("mailto:help@nkreative.test") == true)
        #expect(SettingsRoute.availability(of: .support) == SupportContact.configured.isAvailable)
        #expect(SupportContact.configured == SupportContact(email: AppLinks.supportEmail, page: AppLinks.supportPage))
    }

    @Test func otherSettingsPagesAreAlwaysAvailable() {
        #expect([SettingsRoute.notifications, .methodology, .sources].allSatisfy(SettingsRoute.availability))
    }
}
