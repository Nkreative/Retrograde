#if DEBUG
import Foundation

/// Debug-only stand-in for the App Store (from M8), for exploring every Premium state without
/// StoreKit. Not compiled into release builds. Its Yearly "year" is a simulation convenience;
/// real expiry always comes from Apple.
public final class SimulatedEntitlementSource: EntitlementSource, @unchecked Sendable {
    public struct Account: Codable, Equatable, Sendable {
        public struct Yearly: Codable, Equatable, Sendable {
            public enum Issue: String, Codable, Sendable { case none, gracePeriod, billingRetry }
            public var expiresAt: Date
            public var willAutoRenew = true
            public var issue = Issue.none
            public var revoked = false
        }

        public var lifetime: Bool = false
        public var lifetimeRevoked = false
        public var yearly: Yearly?

        public init() {}
    }

    private let storage: SimulatedAccountStorage
    private let now: @Sendable () -> Date
    private let stream: AsyncStream<Void>
    private let continuation: AsyncStream<Void>.Continuation
    private let lock = NSLock()

    public init(storage: SimulatedAccountStorage, now: @escaping @Sendable () -> Date = Date.init) {
        self.storage = storage
        self.now = now
        (stream, continuation) = AsyncStream.makeStream(of: Void.self)
    }

    public var account: Account { lock.withLock { storage.load() } }

    public func currentSnapshot() async throws -> EntitlementSnapshot {
        let a = account
        let yearly = a.yearly.map { y -> YearlySubscription in
            let state: YearlySubscription.State =
                y.revoked ? .revoked
                : y.issue == .billingRetry ? .inBillingRetry
                : y.issue == .gracePeriod ? .inGracePeriod
                : y.expiresAt > now() ? .subscribed : .expired
            let graceEnd = y.issue == .gracePeriod ? y.expiresAt.addingTimeInterval(16 * 86_400) : nil
            return YearlySubscription(state: state, expiresAt: y.expiresAt, willAutoRenew: y.willAutoRenew, gracePeriodEndsAt: graceEnd)
        }
        return EntitlementSnapshot(ownsLifetime: a.lifetime && !a.lifetimeRevoked, yearly: yearly)
    }

    public func changes() -> AsyncStream<Void> { stream }

    public func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        let at = now()
        update { account in
            switch plan {
            case .lifetime:
                account.lifetime = true
                account.lifetimeRevoked = false
            case .yearly:
                let expiry = Calendar(identifier: .gregorian).date(byAdding: .year, value: 1, to: at)!
                account.yearly = .init(expiresAt: expiry)
            }
        }
        return .purchased
    }

    public func restore() async throws {
        continuation.yield()
    }

    // MARK: Simulated App Store events

    public func expireYearly() { update { $0.yearly?.expiresAt = now().addingTimeInterval(-1); $0.yearly?.issue = .none } }
    public func enterGracePeriod() { update { $0.yearly?.issue = .gracePeriod; $0.yearly?.expiresAt = now().addingTimeInterval(-1) } }
    public func enterBillingRetry() { update { $0.yearly?.issue = .billingRetry; $0.yearly?.expiresAt = now().addingTimeInterval(-1) } }
    public func turnOffAutoRenew() { update { $0.yearly?.willAutoRenew = false } }
    public func refund(_ plan: PremiumPlan) {
        update { plan == .lifetime ? ($0.lifetimeRevoked = true) : ($0.yearly?.revoked = true) }
    }
    public func reset() { update { $0 = Account() } }

    private func update(_ change: (inout Account) -> Void) {
        lock.withLock {
            var account = storage.load()
            change(&account)
            storage.save(account)
        }
        continuation.yield()
    }
}

public protocol SimulatedAccountStorage: AnyObject, Sendable {
    func load() -> SimulatedEntitlementSource.Account
    func save(_ account: SimulatedEntitlementSource.Account)
}

public final class DefaultsAccountStorage: SimulatedAccountStorage, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> SimulatedEntitlementSource.Account {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(SimulatedEntitlementSource.Account.self, from: $0) } ?? .init()
    }

    public func save(_ account: SimulatedEntitlementSource.Account) {
        defaults.set(try? JSONEncoder().encode(account), forKey: key)
    }
}

public final class InMemoryAccountStorage: SimulatedAccountStorage, @unchecked Sendable {
    private var account = SimulatedEntitlementSource.Account()

    public init() {}

    public func load() -> SimulatedEntitlementSource.Account { account }
    public func save(_ account: SimulatedEntitlementSource.Account) { self.account = account }
}
#endif
