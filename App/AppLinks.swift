import Foundation

/// Outbound links, contact details and legal identity in one place. A nil value hides its link
/// entirely — placeholders are never shown to customers. Archiving is blocked while
/// `privacyPolicy` is nil (build phase "Require privacy policy URL").
enum AppLinks {
    /// Apple's standard licensed-application EULA (approved as Retrograde's Terms of Use).
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Retrograde's privacy policy — set once NKreative LLC's legal pages are published.
    static let privacyPolicy: URL? = nil
    /// Retrograde's support page — set once it's published.
    static let supportPage: URL? = nil
    /// Support email — set once it's chosen.
    static let supportEmail: String? = nil

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
