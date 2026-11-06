/// The Overview's one-line sharing message, from the person's own finished shares on this iPhone
/// (`SharingActivity`: only shares iOS reported as completed). It never mentions who received
/// anything: iOS doesn't tell the app.
public struct SharingSummary: Equatable, Sendable {
    /// The big number ("12"); nil before the first finished share.
    public let count: String?
    public let message: String

    public init(finishedShares: Int) {
        switch finishedShares {
        case ..<1:
            count = nil
            message = "Invite someone who needs this."
        case 1:
            count = "1"
            message = "time you’ve shared Retrograde"
        default:
            count = "\(finishedShares)"
            message = "times you’ve shared Retrograde"
        }
    }

    /// For VoiceOver: "12 times you’ve shared Retrograde."
    public var spoken: String { count.map { "\($0) \(message)." } ?? message }
}
