import Foundation

/// Outbound links, contact details and legal identity in one place. A nil value hides its link
/// entirely — placeholders are never shown to customers. Archiving is blocked while
/// `privacyPolicy`, `appStore`, `supportPage` or `supportEmail` is nil (build phase "Require
/// release links").
enum AppLinks {
    /// Apple's standard licensed-application EULA (approved as Retrograde's Terms of Use).
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Retrograde's privacy policy (also entered in App Store Connect).
    static let privacyPolicy: URL? = URL(string: "https://apps.nkreative.com/retrograde/privacy")
    /// Retrograde's App Store page (Apple ID 6830406388), shared by "Share Retrograde" and with a
    /// day's card. Archiving is blocked if this is ever nil.
    static let appStore: URL? = URL(string: "https://apps.apple.com/app/id6830406388")
    /// Retrograde's support page (also entered in App Store Connect).
    static let supportPage: URL? = URL(string: "https://apps.nkreative.com/retrograde/support")
    /// Support and privacy enquiries.
    static let supportEmail: String? = "support@nkreative.com"

    /// Who runs the app, shown in Settings › About. Not the App Store seller: the Apple Developer
    /// account is individual, so the App Store lists the account holder.
    static let appOperator = "NKreative LLC"

    /// "1.0 (1)" from the bundle.
    static var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
