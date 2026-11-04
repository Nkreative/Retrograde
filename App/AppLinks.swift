import Foundation

/// Outbound links and contact details in one place. A nil value hides its link entirely —
/// placeholders are never shown to customers.
enum AppLinks {
    /// Apple's standard licensed-application EULA (approved as Retrograde's Terms of Use).
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    /// Retrograde's privacy policy — set once it's published.
    static let privacyPolicy: URL? = nil
    /// Retrograde's support page — set once it's published (used by Settings, M9c).
    static let supportPage: URL? = nil
    /// Support email — set once it's chosen (used by Settings, M9c).
    static let supportEmail: String? = nil
}
