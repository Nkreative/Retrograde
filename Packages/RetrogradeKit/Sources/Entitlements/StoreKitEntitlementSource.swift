import Foundation
import StoreKit

/// Production purchases via StoreKit 2. Only cryptographically verified transactions count;
/// StoreKit keeps those signed records on the device, so entitlements also work offline.
public actor StoreKitEntitlementSource: EntitlementSource {
    public enum StoreError: Error, Equatable {
        case productUnavailable(PremiumPlan)
        case unverifiedTransaction
    }

    private var products: [PremiumPlan: Product] = [:]

    public init() {}

    public func currentSnapshot() async throws -> EntitlementSnapshot {
        var ownsLifetime = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result, transaction.revocationDate == nil else { continue }
            if transaction.productID == PremiumPlan.lifetime.productID { ownsLifetime = true }
        }
        return EntitlementSnapshot(ownsLifetime: ownsLifetime, yearly: await yearlySubscription())
    }

    /// The Yearly subscription's state from its latest verified transaction and renewal info.
    private func yearlySubscription() async -> YearlySubscription? {
        guard let latest = await Transaction.latest(for: PremiumPlan.yearly.productID),
              case let .verified(transaction) = latest
        else { return nil }
        if transaction.revocationDate != nil {
            return YearlySubscription(state: .revoked, expiresAt: transaction.expirationDate, willAutoRenew: false)
        }
        if let status = await transaction.subscriptionStatus, case let .verified(renewal) = status.renewalInfo {
            return YearlySubscription(
                state: Self.state(status.state), expiresAt: transaction.expirationDate,
                willAutoRenew: renewal.willAutoRenew, gracePeriodEndsAt: renewal.gracePeriodExpirationDate
            )
        }
        // Renewal details unavailable (e.g. offline): fall back to the verified transaction's own expiry.
        let active = (transaction.expirationDate ?? .distantPast) > Date()
        return YearlySubscription(state: active ? .subscribed : .expired, expiresAt: transaction.expirationDate, willAutoRenew: true)
    }

    private static func state(_ state: Product.SubscriptionInfo.RenewalState) -> YearlySubscription.State {
        switch state {
        case .subscribed: .subscribed
        case .inGracePeriod: .inGracePeriod
        case .inBillingRetryPeriod: .inBillingRetry
        case .revoked: .revoked
        default: .expired
        }
    }

    public nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                // Anything left unfinished last time (e.g. the app closed mid-purchase).
                for await result in Transaction.unfinished {
                    continuation.yield()
                    if case let .verified(transaction) = result { await transaction.finish() }
                }
                // Renewals, refunds, Ask to Buy approvals, purchases on other devices.
                for await result in Transaction.updates {
                    continuation.yield()
                    if case let .verified(transaction) = result { await transaction.finish() }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        let product = try await product(for: plan)
        switch try await product.purchase() {
        case let .success(verification):
            guard case let .verified(transaction) = verification else { throw StoreError.unverifiedTransaction }
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    public func restore() async throws {
        try await AppStore.sync()
    }

    /// Products load on demand and are cached; a failure here never affects entitlements.
    public func product(for plan: PremiumPlan) async throws -> Product {
        if let cached = products[plan] { return cached }
        let loaded = try await Product.products(for: PremiumPlan.allCases.map(\.productID))
        for product in loaded {
            if let match = PremiumPlan.allCases.first(where: { $0.productID == product.id }) { products[match] = product }
        }
        guard let product = products[plan] else { throw StoreError.productUnavailable(plan) }
        return product
    }
}
