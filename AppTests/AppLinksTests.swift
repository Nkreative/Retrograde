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

    @Test func supportFallsBackToEmail() {
        // With neither set, Contact Support is hidden rather than pointing somewhere invented.
        if AppLinks.supportPage == nil && AppLinks.supportEmail == nil { #expect(AppLinks.support == nil) }
        if AppLinks.supportPage == nil, let email = AppLinks.supportEmail { #expect(AppLinks.support?.absoluteString == "mailto:\(email)") }
    }

    @Test func operatorAndVersion() {
        #expect(AppLinks.appOperator == "NKreative LLC")
        #expect(AppLinks.versionDescription.range(of: #"^\d+(\.\d+)* \(\d+\)$"#, options: .regularExpression) != nil)
    }
}
