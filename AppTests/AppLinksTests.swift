import Foundation
import Testing
@testable import Retrograde

@Suite struct AppLinksTests {
    @Test func termsOpenApplesStandardEULA() {
        #expect(AppLinks.termsOfUse.absoluteString == "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
    }

    @Test func configuredLinksAreSecureAndNeverPlaceholders() {
        for url in [AppLinks.privacyPolicy, AppLinks.supportPage].compactMap({ $0 }) {
            #expect(url.scheme == "https", "\(url)")
            #expect(!url.absoluteString.contains("example"), "\(url)")
        }
        if let email = AppLinks.supportEmail {
            #expect(email.contains("@") && !email.contains("example"))
        }
    }

    /// Share Retrograde's link must be a real App Store app address (no made-up IDs).
    @Test func appStoreLinkIsAnAppStoreAddress() throws {
        let url = try #require(AppLinks.appStore)
        #expect(url.scheme == "https" && url.host() == "apps.apple.com", "\(url)")
        #expect(url.absoluteString.range(of: #"/id\d+$"#, options: .regularExpression) != nil, "\(url)")
        #expect(url.absoluteString == "https://apps.apple.com/app/id6830406388")
    }

    /// The approved production links (M14.3), the same ones entered in App Store Connect.
    @Test func releaseLinksAreTheApprovedOnes() {
        #expect(AppLinks.privacyPolicy?.absoluteString == "https://apps.nkreative.com/retrograde/privacy")
        #expect(AppLinks.supportPage?.absoluteString == "https://apps.nkreative.com/retrograde/support")
        #expect(AppLinks.supportEmail == "support@nkreative.com")
        #expect(SupportContact.configured.mailURL?.absoluteString == "mailto:support@nkreative.com?subject=Retrograde%20support")
        #expect(SettingsRoute.availability(of: .legal(.privacy)) && SettingsRoute.availability(of: .support))
    }

    @Test func operatorAndVersion() {
        #expect(AppLinks.appOperator == "NKreative LLC")
        #expect(AppLinks.versionDescription.range(of: #"^\d+(\.\d+)* \(\d+\)$"#, options: .regularExpression) != nil)
    }
}
