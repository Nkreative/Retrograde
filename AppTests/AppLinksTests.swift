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

    /// Share Retrograde's link, once set, must be a real App Store app address (no made-up IDs).
    @Test func appStoreLinkIsAnAppStoreAddress() {
        guard let url = AppLinks.appStore else { return }
        #expect(url.scheme == "https" && url.host() == "apps.apple.com", "\(url)")
        #expect(url.absoluteString.range(of: #"/id\d+$"#, options: .regularExpression) != nil, "\(url)")
    }

    @Test func operatorAndVersion() {
        #expect(AppLinks.appOperator == "NKreative LLC")
        #expect(AppLinks.versionDescription.range(of: #"^\d+(\.\d+)* \(\d+\)$"#, options: .regularExpression) != nil)
    }
}
