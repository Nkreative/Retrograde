import Foundation
import Observation

/// The two ways to get Premium. Both unlock exactly the same features (`retrograde.premium`).
public enum PremiumPlan: String, Codable, CaseIterable, Sendable {
    case yearly, lifetime

    /// App Store product identifiers, kept out of the UI (configured in App Store Connect in M9).
    public var productID: String {
        switch self {
        case .yearly: "com.nkreative.retrograde.premium.yearly"
        case .lifetime: "com.nkreative.retrograde.premium.lifetime"
        }
    }
}

/// A purchase as the App Store reports it. Yearly has an expiry; Lifetime never expires.
public struct PremiumTransaction: Codable, Equatable, Sendable {
    public let plan: PremiumPlan
    public let purchasedAt: Date
    public var expiresAt: Date?

    public init(plan: PremiumPlan, purchasedAt: Date, expiresAt: Date?) {
        self.plan = plan
        self.purchasedAt = purchasedAt
        self.expiresAt = expiresAt
    }
}

public enum PremiumStatus: Equatable, Sendable {
    case free
    /// Active subscription; renews (or ends) on this date.
    case yearly(renewsOn: Date)
    case lifetime
    /// Had Yearly; it ended on this date and there's no Lifetime.
    case yearlyExpired(on: Date)

    public var isPremium: Bool {
        switch self {
        case .yearly, .lifetime: true
        case .free, .yearlyExpired: false
        }
    }
}

/// How transactions become a status. Lifetime wins over everything; otherwise the latest Yearly
/// decides, active until its expiry instant.
public enum EntitlementRules {
    public static func status(of transactions: [PremiumTransaction], at now: Date) -> PremiumStatus {
        if transactions.contains(where: { $0.plan == .lifetime }) { return .lifetime }
        let latestExpiry = transactions.filter { $0.plan == .yearly }.compactMap(\.expiresAt).max()
        guard let latestExpiry else { return .free }
        return now < latestExpiry ? .yearly(renewsOn: latestExpiry) : .yearlyExpired(on: latestExpiry)
    }
}

/// Small persistent storage for entitlement records (UserDefaults in the app, a test suite in tests).
public protocol EntitlementPersistence: AnyObject, Sendable {
    func load() -> [PremiumTransaction]
    func save(_ transactions: [PremiumTransaction])
}

public final class DefaultsEntitlementPersistence: EntitlementPersistence, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [PremiumTransaction] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PremiumTransaction].self, from: data)) ?? []
    }

    public func save(_ transactions: [PremiumTransaction]) {
        defaults.set(try? JSONEncoder().encode(transactions), forKey: key)
    }
}

public final class InMemoryEntitlementPersistence: EntitlementPersistence, @unchecked Sendable {
    private var transactions: [PremiumTransaction]

    public init(_ transactions: [PremiumTransaction] = []) {
        self.transactions = transactions
    }

    public func load() -> [PremiumTransaction] { transactions }
    public func save(_ transactions: [PremiumTransaction]) { self.transactions = transactions }
}

/// The single source of truth for Premium. Screens read `isPremium`; it changes immediately when
/// a purchase, expiry or restore happens.
///
/// - `device` is the app's own record, read at launch.
/// - `account` stands in for the person's App Store account: purchases go there and Restore reads
///   from it. In M8 it's simulated (debug builds only); M9 replaces it with StoreKit. With no
///   account (production until M9) nothing can be bought and the status is Free.
@MainActor
@Observable
public final class EntitlementStore {
    public private(set) var transactions: [PremiumTransaction]
    @ObservationIgnored private let device: EntitlementPersistence
    @ObservationIgnored private let account: EntitlementPersistence?
    @ObservationIgnored private let now: () -> Date

    public init(device: EntitlementPersistence, account: EntitlementPersistence?, now: @escaping () -> Date = Date.init) {
        self.device = device
        self.account = account
        self.now = now
        self.transactions = device.load()
    }

    public var status: PremiumStatus { EntitlementRules.status(of: transactions, at: now()) }
    public var isPremium: Bool { status.isPremium }
    public var canPurchase: Bool { account != nil }

    /// Records a purchase in the account and on the device. Yearly runs one year from now.
    public func purchase(_ plan: PremiumPlan) {
        guard let account else { return }
        let at = now()
        let expiry = plan == .yearly ? Calendar(identifier: .gregorian).date(byAdding: .year, value: 1, to: at) : nil
        var ledger = account.load()
        ledger.append(PremiumTransaction(plan: plan, purchasedAt: at, expiresAt: expiry))
        account.save(ledger)
        apply(ledger)
    }

    /// Re-reads purchases from the account (e.g. after reinstalling or on a new phone).
    public func restorePurchases() {
        apply(account?.load() ?? [])
    }

    private func apply(_ ledger: [PremiumTransaction]) {
        transactions = ledger
        device.save(ledger)
    }

    // MARK: Simulation (debug builds and tests only; replaced by StoreKit in M9)

    #if DEBUG

    /// Ends the current Yearly subscription now (as if it lapsed without renewing).
    public func simulateYearlyExpiry() {
        guard let account else { return }
        let at = now().addingTimeInterval(-1)
        let ledger = account.load().map { t -> PremiumTransaction in
            guard t.plan == .yearly, let expiry = t.expiresAt, expiry > at else { return t }
            var ended = t
            ended.expiresAt = at
            return ended
        }
        account.save(ledger)
        apply(ledger)
    }

    /// Forgets the device record only, as after deleting and reinstalling the app.
    public func simulateReinstall() {
        transactions = []
        device.save([])
    }

    /// Clears every simulated purchase.
    public func simulateReset() {
        account?.save([])
        apply([])
    }
    #endif
}
