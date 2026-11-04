import Foundation
import Observation

/// The two ways to get Premium. Both unlock exactly the same features (`retrograde.premium`).
public enum PremiumPlan: String, Codable, CaseIterable, Sendable {
    case yearly, lifetime

    /// App Store product identifiers (App Store Connect; mirrored in StoreKit/Retrograde.storekit).
    public var productID: String {
        switch self {
        case .yearly: "com.nkreative.retrograde.premium.yearly"
        case .lifetime: "com.nkreative.retrograde.premium.lifetime"
        }
    }
}

/// What Apple has verified about the person's purchases, at the moment it was read.
public struct EntitlementSnapshot: Equatable, Sendable {
    /// A verified, non-revoked Lifetime purchase.
    public var ownsLifetime: Bool
    /// The Yearly subscription's latest verified state, if they ever subscribed.
    public var yearly: YearlySubscription?

    public init(ownsLifetime: Bool = false, yearly: YearlySubscription? = nil) {
        self.ownsLifetime = ownsLifetime
        self.yearly = yearly
    }

    public static let none = EntitlementSnapshot()
}

public struct YearlySubscription: Equatable, Sendable {
    /// StoreKit's renewal states.
    public enum State: Equatable, Sendable { case subscribed, inGracePeriod, inBillingRetry, expired, revoked }

    public var state: State
    /// From Apple's verified transaction — never computed by the app.
    public var expiresAt: Date?
    public var willAutoRenew: Bool
    /// From Apple's verified renewal info, while in the billing grace period.
    public var gracePeriodEndsAt: Date?

    public init(state: State, expiresAt: Date?, willAutoRenew: Bool, gracePeriodEndsAt: Date? = nil) {
        self.state = state
        self.expiresAt = expiresAt
        self.willAutoRenew = willAutoRenew
        self.gracePeriodEndsAt = gracePeriodEndsAt
    }
}

public enum PremiumStatus: Equatable, Sendable {
    case free
    /// `yearlyStillRenewing`: they also have an auto-renewing Yearly they may want to cancel.
    case lifetime(yearlyStillRenewing: Bool)
    /// Active Yearly; renews (or, if auto-renew is off, ends) at `until`.
    case yearly(until: Date?, willRenew: Bool)
    /// Payment failed, but Apple's grace period keeps Premium until `until`.
    case yearlyGracePeriod(until: Date?)
    /// Payment failed and the grace period (if any) is over; Apple is still retrying.
    case yearlyBillingIssue
    case yearlyExpired(on: Date?)

    public var isPremium: Bool {
        switch self {
        case .lifetime, .yearly, .yearlyGracePeriod: true
        case .free, .yearlyBillingIssue, .yearlyExpired: false
        }
    }
}

/// How a verified snapshot becomes a status. Lifetime always wins; otherwise the Yearly
/// subscription's verified state and dates decide. Refunded/revoked purchases grant nothing.
public enum EntitlementRules {
    public static func status(of snapshot: EntitlementSnapshot, at now: Date) -> PremiumStatus {
        let yearly = snapshot.yearly.map { yearlyStatus($0, at: now) }
        if snapshot.ownsLifetime {
            let renewing: Bool = switch yearly {
            case let .yearly(_, willRenew): willRenew
            case .yearlyGracePeriod, .yearlyBillingIssue: true
            default: false
            }
            return .lifetime(yearlyStillRenewing: renewing)
        }
        return yearly ?? .free
    }

    private static func yearlyStatus(_ y: YearlySubscription, at now: Date) -> PremiumStatus {
        switch y.state {
        case .revoked:
            return .free
        case .subscribed:
            // Belt and braces: never honour a verified expiry that has already passed.
            if let expiry = y.expiresAt, now >= expiry { return .yearlyExpired(on: expiry) }
            return .yearly(until: y.expiresAt, willRenew: y.willAutoRenew)
        case .inGracePeriod:
            if let end = y.gracePeriodEndsAt, now >= end { return .yearlyBillingIssue }
            return .yearlyGracePeriod(until: y.gracePeriodEndsAt)
        case .inBillingRetry:
            return .yearlyBillingIssue
        case .expired:
            return .yearlyExpired(on: y.expiresAt)
        }
    }
}

/// A length of time as StoreKit describes it (a billing period or a trial).
public struct BillingPeriod: Equatable, Sendable {
    public enum Unit: Sendable { case day, week, month, year }

    public let value: Int
    public let unit: Unit

    public init(value: Int, unit: Unit) {
        self.value = value
        self.unit = unit
    }
}

/// What the paywall shows for a plan, straight from StoreKit for the person's storefront.
public struct PlanOffer: Equatable, Sendable {
    public let plan: PremiumPlan
    /// Localized, e.g. "$9.99" or "9,99 €".
    public let displayPrice: String
    /// Yearly's billing period; nil for Lifetime.
    public let billingPeriod: BillingPeriod?
    /// Only when the storefront offers a free trial *and* StoreKit says this person is eligible.
    public let freeTrial: BillingPeriod?

    public init(plan: PremiumPlan, displayPrice: String, billingPeriod: BillingPeriod? = nil, freeTrial: BillingPeriod? = nil) {
        self.plan = plan
        self.displayPrice = displayPrice
        self.billingPeriod = billingPeriod
        self.freeTrial = freeTrial
    }
}

public enum PurchaseOutcome: Equatable, Sendable {
    case purchased
    /// Waiting on Ask to Buy or another approval; Premium unlocks when it completes.
    case pending
    case cancelled
}

/// Where purchases come from: StoreKit in production, a simulator in debug builds only.
public protocol EntitlementSource: AnyObject, Sendable {
    /// Verified entitlements now. Throws only when the answer can't be trusted or obtained.
    func currentSnapshot() async throws -> EntitlementSnapshot
    /// Signals whenever purchases may have changed (renewal, refund, approval, another device).
    func changes() -> AsyncStream<Void>
    func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome
    /// Re-syncs purchases with the App Store (Restore Purchases).
    func restore() async throws
    /// Localized prices and offers for the paywall. Throws if no product can be loaded.
    func offers() async throws -> [PlanOffer]
}

/// The single source of truth for Premium. Screens read `isPremium`; it updates as soon as a
/// purchase, renewal, expiry, refund or restore is verified.
@MainActor
@Observable
public final class EntitlementStore {
    /// The last verified snapshot. A failed refresh keeps it, so a temporary StoreKit or network
    /// problem never takes Premium away.
    public private(set) var snapshot: EntitlementSnapshot = .none
    /// True once this launch has read verified entitlements at least once.
    public private(set) var hasLoaded = false
    /// An Ask to Buy (or similar) purchase is waiting for approval.
    public private(set) var isPurchasePending = false

    @ObservationIgnored private let source: EntitlementSource
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var listener: Task<Void, Never>?

    public init(source: EntitlementSource, now: @escaping () -> Date = Date.init) {
        self.source = source
        self.now = now
    }

    public var status: PremiumStatus { EntitlementRules.status(of: snapshot, at: now()) }
    public var isPremium: Bool { status.isPremium }

    /// Reads entitlements and keeps listening for changes. Safe to call more than once.
    public func start() async {
        if listener == nil {
            let changes = source.changes()
            listener = Task { [weak self] in
                for await _ in changes { await self?.refresh() }
            }
        }
        await refresh()
    }

    /// Re-reads verified entitlements (launch, foreground, after any change).
    public func refresh() async {
        do {
            snapshot = try await source.currentSnapshot()
            hasLoaded = true
            if isPremium { isPurchasePending = false }
        } catch {
            // Keep the last verified snapshot.
        }
    }

    public func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        let outcome = try await source.purchase(plan)
        switch outcome {
        case .purchased: await refresh()
        case .pending: isPurchasePending = true
        case .cancelled: break
        }
        return outcome
    }

    public func restorePurchases() async throws {
        try await source.restore()
        await refresh()
    }

    public func offers() async throws -> [PlanOffer] {
        try await source.offers()
    }
}
