import Foundation
import StoreKit
#if DEBUG
import os
#endif

/// Production purchases via StoreKit 2. Only cryptographically verified transactions count;
/// StoreKit keeps those signed records on the device, so entitlements also work offline.
public actor StoreKitEntitlementSource: EntitlementSource {
    public enum StoreError: Error, Equatable {
        case productUnavailable(PremiumPlan)
        case unverifiedTransaction
    }

    private var products: [PremiumPlan: Product] = [:]
    #if DEBUG
    private var loggedEnvironment = false
    #endif

    public init() {}

    public func currentSnapshot() async throws -> EntitlementSnapshot {
        #if DEBUG
        if !loggedEnvironment {
            loggedEnvironment = true
            await StoreKitLog.appEnvironment()
        }
        #endif
        var ownsLifetime = false
        for await result in Transaction.currentEntitlements {
            #if DEBUG
            StoreKitLog.note("Entitlement: \(StoreKitLog.describe(result))")
            #endif
            guard case let .verified(transaction) = result, transaction.revocationDate == nil else { continue }
            if transaction.productID == PremiumPlan.lifetime.productID { ownsLifetime = true }
        }
        let snapshot = EntitlementSnapshot(ownsLifetime: ownsLifetime, yearly: await yearlySubscription())
        #if DEBUG
        StoreKitLog.note("Snapshot: lifetime \(snapshot.ownsLifetime), yearly \(snapshot.yearly.map { "\($0.state)" } ?? "none")")
        #endif
        return snapshot
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
                    #if DEBUG
                    StoreKitLog.note("Unfinished transaction: \(StoreKitLog.describe(result))")
                    #endif
                    continuation.yield()
                    if case let .verified(transaction) = result { await transaction.finish() }
                }
                // Renewals, refunds, Ask to Buy approvals, purchases on other devices.
                for await result in Transaction.updates {
                    #if DEBUG
                    StoreKitLog.note("Transaction update: \(StoreKitLog.describe(result))")
                    #endif
                    continuation.yield()
                    if case let .verified(transaction) = result { await transaction.finish() }
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func purchase(_ plan: PremiumPlan) async throws -> PurchaseOutcome {
        let product = try await product(for: plan)
        let result = try await product.purchase()
        #if DEBUG
        StoreKitLog.note("Purchase \(plan): \(StoreKitLog.describe(result))")
        #endif
        switch result {
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
        #if DEBUG
        await StoreKitLog.entitlements("Restore: entitlements before sync")
        #endif
        do {
            try await AppStore.sync()
        } catch {
            #if DEBUG
            StoreKitLog.note("Restore: AppStore.sync failed: \(error)")
            #endif
            throw error
        }
        #if DEBUG
        StoreKitLog.note("Restore: AppStore.sync finished")
        await StoreKitLog.entitlements("Restore: entitlements after sync")
        #endif
    }

    public func offers() async throws -> [PlanOffer] {
        var result: [PlanOffer] = []
        let storefront = await Storefront.current?.countryCode
        for plan in PremiumPlan.allCases {
            guard let product = try? await product(for: plan) else { continue }
            // The introductory offer only for someone StoreKit says is eligible (one per subscription
            // group, ever); everyone else is shown the regular price.
            var intro: IntroOffer?
            if let subscription = product.subscription, let offer = subscription.introductoryOffer,
               await subscription.isEligibleForIntroOffer {
                intro = IntroOffer(offer)
            }
            result.append(PlanOffer(
                plan: plan, displayPrice: product.displayPrice,
                billingPeriod: product.subscription.map { BillingPeriod($0.subscriptionPeriod) }, introOffer: intro,
                price: product.price, priceFormat: product.priceFormatStyle, storefront: storefront
            ))
        }
        guard !result.isEmpty else { throw StoreError.productUnavailable(.lifetime) }
        return result
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

extension IntroOffer {
    /// Nil for a payment mode this version doesn't know, so it's never described wrongly.
    init?(_ offer: Product.SubscriptionOffer) {
        let payment: Payment
        switch offer.paymentMode {
        case .freeTrial: payment = .freeTrial
        case .payUpFront: payment = .payUpFront
        case .payAsYouGo: payment = .payAsYouGo
        default: return nil
        }
        self.init(payment: payment, displayPrice: offer.displayPrice, price: offer.price, period: BillingPeriod(offer.period), periodCount: offer.periodCount)
    }
}

extension BillingPeriod {
    init(_ period: Product.SubscriptionPeriod) {
        let unit: Unit = switch period.unit {
        case .day: .day
        case .week: .week
        case .month: .month
        default: .year
        }
        self.init(value: period.value, unit: unit)
    }
}

#if DEBUG
/// Temporary purchase diagnostics, debug builds only (Xcode console / Console app, category
/// "StoreKit"). Logs which StoreKit environment answered (Xcode, Sandbox, Production), product IDs,
/// purchase dates and verification results; never account details or transaction identifiers.
enum StoreKitLog {
    private static let logger = Logger(subsystem: "com.nkreative.retrograde", category: "StoreKit")

    static func note(_ message: String) {
        logger.notice("\(message, privacy: .public)")
    }

    /// The environment of the app's own signed record: Xcode (local StoreKit configuration file),
    /// Sandbox or Production.
    static func appEnvironment() async {
        do {
            switch try await AppTransaction.shared {
            case let .verified(app): note("App transaction environment: \(app.environment.rawValue)")
            case let .unverified(app, error): note("App transaction UNVERIFIED (\(error)), environment: \(app.environment.rawValue)")
            }
        } catch {
            note("App transaction unavailable: \(error)")
        }
    }

    static func entitlements(_ label: String) async {
        var lines: [String] = []
        for await result in Transaction.currentEntitlements { lines.append(describe(result)) }
        note("\(label): \(lines.isEmpty ? "none" : lines.joined(separator: "; "))")
    }

    static func describe(_ result: VerificationResult<Transaction>) -> String {
        switch result {
        case let .verified(t): describe(t)
        case let .unverified(t, error): "UNVERIFIED \(describe(t)) (\(error))"
        }
    }

    static func describe(_ result: Product.PurchaseResult) -> String {
        switch result {
        case let .success(verification): "success, \(describe(verification))"
        case .pending: "pending"
        case .userCancelled: "cancelled"
        @unknown default: "unknown result"
        }
    }

    private static func describe(_ t: Transaction) -> String {
        "\(t.productID) [\(t.environment.rawValue)] purchased \(t.purchaseDate.formatted(.iso8601))\(t.revocationDate == nil ? "" : " REVOKED")"
    }
}
#endif
