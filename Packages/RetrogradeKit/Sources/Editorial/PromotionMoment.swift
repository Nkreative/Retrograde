import RetroCore

/// The paywall's "retrograde is ending" message for a verified launch promotion. Whether a
/// promotion is running (and its discount) comes from StoreKit; this decides only whether the
/// sky makes the message fit, from the bundled ephemeris.
public enum PromotionMoment {
    /// "Approaching the end of retrograde": the planet is retrograde and stations direct within
    /// this many calendar days (0 = the day it turns direct).
    public static let leadDays = 7

    public static func isRetrogradeEnding(_ status: CycleStatus) -> Bool {
        status.stage == .retrograde && status.daysUntilTarget <= leadDays
    }

    public struct Message: Equatable, Sendable {
        public let headline: String
        public let body: String
        public let signOff: String
    }

    /// The copy, with the verified discount (never assumed).
    public static func message(for planet: Planet, percentOff: Int) -> Message {
        Message(
            headline: "\(planet.name.uppercased())’S CLOCKING OUT. PRICES ARE DROPPING.",
            body: "Celebrate the end of retrograde with \(percentOff)% off Lifetime Premium.",
            signOff: "The chaos will return. Your backup stays."
        )
    }
}
