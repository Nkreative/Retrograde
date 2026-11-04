import Foundation

/// What Settings shows about Premium, from the verified status. Never says Premium was lost while
/// the first read is still pending: a failed read keeps the last verified state (EntitlementStore).
public struct PremiumSummary: Equatable, Sendable {
    public enum Action: Equatable, Sendable {
        case upgrade, restore, manageSubscription, requestRefund
    }

    public enum Tone: Equatable, Sendable { case neutral, premium, warning }

    public let title: String
    public let detail: String?
    /// A highlighted reminder (e.g. cancel Yearly separately, payment issue).
    public let notice: String?
    public let tone: Tone
    public let actions: [Action]

    /// `formatDate` turns Apple's verified dates into the person's locale ("Dec 2, 2027").
    public static func make(status: PremiumStatus, hasLoaded: Bool, formatDate: (Date) -> String) -> PremiumSummary {
        func day(_ date: Date?) -> String? { date.map(formatDate) }
        switch status {
        case .free where !hasLoaded:
            return PremiumSummary(title: "Checking your purchases…", detail: nil, notice: nil, tone: .neutral, actions: [.restore])
        case .free:
            return PremiumSummary(title: "Free", detail: "First task in each Survival Kit section, and today + 3 days of calendar detail.",
                                  notice: nil, tone: .neutral, actions: [.upgrade, .restore])
        case let .lifetime(yearlyStillRenewing):
            return PremiumSummary(
                title: "Premium · Lifetime",
                detail: "One-time purchase. It never expires and never renews.",
                notice: yearlyStillRenewing
                    ? "You also have a Yearly subscription that’s still set to renew. Cancel it in Manage Subscription to avoid further charges — Lifetime already covers everything."
                    : nil,
                tone: .premium,
                actions: yearlyStillRenewing ? [.manageSubscription, .restore, .requestRefund] : [.restore, .requestRefund]
            )
        case let .yearly(until, willRenew):
            let detail = day(until).map { willRenew ? "Renews \($0)." : "Ends \($0). Auto-renew is off." }
            return PremiumSummary(title: "Premium · Yearly", detail: detail, notice: nil, tone: .premium,
                                  actions: [.manageSubscription, .restore, .requestRefund])
        case let .yearlyGracePeriod(until):
            return PremiumSummary(
                title: "Premium · Yearly",
                detail: nil,
                notice: "There’s a problem with your payment. Premium stays on\(day(until).map { " until \($0)" } ?? "") while Apple retries — update your payment method in Manage Subscription.",
                tone: .warning, actions: [.manageSubscription, .restore]
            )
        case .yearlyBillingIssue:
            return PremiumSummary(
                title: "Yearly paused",
                detail: nil,
                notice: "Apple couldn’t take your renewal payment. Update your payment method in Manage Subscription and Premium comes back automatically.",
                tone: .warning, actions: [.manageSubscription, .restore, .upgrade]
            )
        case let .yearlyExpired(on):
            return PremiumSummary(title: "Free", detail: day(on).map { "Your Yearly subscription ended \($0)." },
                                  notice: nil, tone: .neutral, actions: [.upgrade, .restore])
        }
    }
}
