#if os(iOS)
import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Entitlements

/// End-to-end tests against Apple's StoreKit test environment, using the same configuration
/// file as the app (StoreKit/Retrograde.storekit). StoreKit testing needs a host app, so these
/// live in the app-hosted RetrogradeTests target: `xcodebuild test -scheme Retrograde …`.
@MainActor
@Suite(.serialized) final class StoreKitEntitlementTests {
    let session: SKTestSession
    let source = StoreKitEntitlementSource()
    let store: EntitlementStore

    init() throws {
        let config = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("StoreKit/Retrograde.storekit")
        session = try SKTestSession(contentsOf: config)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        store = EntitlementStore(source: source)
    }

    private var yearlyID: String { PremiumPlan.yearly.productID }
    private var lifetimeID: String { PremiumPlan.lifetime.productID }

    /// StoreKit's test environment applies expiries, refunds and purchases a moment after the call
    /// returns; re-read for up to 2 s per attempt. A wrong mapping still fails once the state has settled.
    private func settle(_ expected: @escaping (PremiumStatus) -> Bool) async -> PremiumStatus {
        for _ in 0..<20 {
            await store.refresh()
            if expected(store.status) { break }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return store.status
    }

    /// Test setup purchase via StoreKit's test tool. The Xcode test environment occasionally fails
    /// one with an internal service error (SKServiceErrorDomain 2) before any app code runs; retry.
    @discardableResult
    private func buy(_ productID: String) async throws -> Transaction {
        for attempt in 1...3 {
            do { return try await session.buyProduct(identifier: productID) } catch where attempt < 3 {
                try await Task.sleep(for: .milliseconds(300))
            }
        }
        fatalError("unreachable")
    }

    /// The test environment occasionally ignores an expire request; repeat it until StoreKit's own
    /// records show the subscription expired, then let the app's status settle.
    private func expireYearly() async throws -> PremiumStatus {
        for _ in 0..<5 {
            do {
                try session.expireSubscription(productIdentifier: yearlyID)
            } catch where Self.isTransientTestEnvironmentError(error) {
                // Known intermittent Xcode StoreKit test-environment failure; retry (max 5 attempts).
            }
            let status = await settle { if case .yearlyExpired = $0 { true } else { false } }
            if case .yearlyExpired = status { return status }
        }
        return store.status
    }

    /// The Xcode StoreKit test environment's intermittent internal failure: SKServiceErrorDomain 2
    /// wrapping SKInternalErrorDomain 17. Anything else is a real error and still fails the test.
    private static func isTransientTestEnvironmentError(_ error: Error) -> Bool {
        let e = error as NSError
        guard e.domain == "SKServiceErrorDomain", e.code == 2,
              let underlying = e.userInfo[NSUnderlyingErrorKey] as? NSError
        else { return false }
        return underlying.domain == "SKInternalErrorDomain" && underlying.code == 17
    }

    private func transaction(_ productID: String) throws -> SKTestTransaction {
        try #require(session.allTransactions().last { $0.productIdentifier == productID })
    }

    @Test func startsFree() async {
        await store.refresh()
        #expect(store.status == .free)
    }

    @Test func productsLoadWithLocalizedPricesAndTrial() async throws {
        let yearly = try await source.product(for: .yearly)
        let lifetime = try await source.product(for: .lifetime)
        #expect(yearly.displayPrice == "$9.99")
        #expect(lifetime.displayPrice == "$19.99")
        #expect(lifetime.type == .nonConsumable)
        let offer = try #require(yearly.subscription?.introductoryOffer)
        #expect(offer.paymentMode == .freeTrial)
        #expect(offer.period.unit == .day && offer.period.value == 3)
        let period = try #require(yearly.subscription?.subscriptionPeriod)
        #expect(period.unit == .year && period.value == 1)
    }

    @Test func purchaseLifetimeThroughTheStore() async throws {
        #expect(try await store.purchase(.lifetime) == .purchased)
        #expect(store.status == .lifetime(yearlyStillRenewing: false))
    }

    @Test func purchaseYearlyUsesTheVerifiedExpiry() async throws {
        #expect(try await store.purchase(.yearly) == .purchased)
        let expiry = try #require(transaction(yearlyID).expirationDate)
        guard case let .yearly(until, willRenew) = store.status, let until else { Issue.record("\(store.status)"); return }
        // Apple's verified expiry — the end of the 7-day free trial here — not a computed year.
        #expect(abs(until.timeIntervalSince(expiry)) < 1)
        #expect(until.timeIntervalSinceNow < 8 * 86_400)
        #expect(willRenew)
    }

    @Test func cancellingAutoRenewKeepsPremiumUntilTheEnd() async throws {
        try await buy(yearlyID)
        try session.disableAutoRenewForTransaction(identifier: transaction(yearlyID).identifier)
        let status = await settle { if case .yearly(_, false) = $0 { true } else { false } }
        guard case let .yearly(_, willRenew) = status else { Issue.record("\(status)"); return }
        #expect(!willRenew && status.isPremium)
    }

    @Test func expiryEndsPremium() async throws {
        try await buy(yearlyID)
        let status = try await expireYearly()
        guard case .yearlyExpired = status else { Issue.record("\(status)"); return }
    }

    @Test func billingRetryWithoutGraceLocks() async throws {
        session.shouldEnterBillingRetryOnRenewal = true
        session.billingGracePeriodIsEnabled = false
        try await buy(yearlyID)
        try session.forceRenewalOfSubscription(productIdentifier: yearlyID)
        #expect(await settle { $0 == .yearlyBillingIssue } == .yearlyBillingIssue)
        // Payment fixed: back to an active subscription.
        try session.resolveIssueForTransaction(identifier: transaction(yearlyID).identifier)
        #expect(await settle { $0.isPremium }.isPremium)
    }

    @Test func gracePeriodKeepsPremium() async throws {
        session.shouldEnterBillingRetryOnRenewal = true
        session.billingGracePeriodIsEnabled = true
        try await buy(yearlyID)
        try session.forceRenewalOfSubscription(productIdentifier: yearlyID)
        let status = await settle { if case .yearlyGracePeriod = $0 { true } else { false } }
        guard case .yearlyGracePeriod = status else { Issue.record("\(status)"); return }
        #expect(status.isPremium)
    }

    @Test func refundsRevokeEachPlan() async throws {
        try await buy(lifetimeID)
        try session.refundTransaction(identifier: transaction(lifetimeID).identifier)
        #expect(await settle { $0 == .free } == .free)

        try await buy(yearlyID)
        try session.refundTransaction(identifier: transaction(yearlyID).identifier)
        #expect(await settle { $0 == .free } == .free)
    }

    @Test func lifetimeWinsAndFlagsAStillRenewingYearly() async throws {
        try await buy(yearlyID)
        #expect(try await store.purchase(.lifetime) == .purchased)
        let status = await settle { $0 == .lifetime(yearlyStillRenewing: true) }
        #expect(status == .lifetime(yearlyStillRenewing: true), "settled on \(status)")
    }

    @Test func lifetimeTakesOverFromAnExpiredYearly() async throws {
        try await buy(yearlyID)
        let expired = try await expireYearly()
        guard case .yearlyExpired = expired else { Issue.record("\(expired)"); return }
        #expect(try await store.purchase(.lifetime) == .purchased)
        let status = await settle { $0 == .lifetime(yearlyStillRenewing: false) }
        #expect(status == .lifetime(yearlyStillRenewing: false), "settled on \(status)")
    }

    @Test func askToBuyIsPendingUntilApproved() async throws {
        session.askToBuyEnabled = true
        await store.start()
        #expect(try await store.purchase(.lifetime) == .pending)
        #expect(store.isPurchasePending && !store.isPremium)
        try session.approveAskToBuyTransaction(identifier: transaction(lifetimeID).identifier)
        for _ in 0..<200 where !store.isPremium { try await Task.sleep(for: .milliseconds(25)) }
        #expect(store.isPremium && !store.isPurchasePending)
    }

    @Test func purchasesFromElsewhereArriveWithoutARefresh() async throws {
        await store.start()
        try await buy(lifetimeID) // as if bought on another device
        for _ in 0..<200 where !store.isPremium { try await Task.sleep(for: .milliseconds(25)) }
        #expect(store.isPremium)
    }

    @Test func productLoadingFailureNeverRevokesPremium() async throws {
        try await buy(yearlyID)
        #expect(await settle { $0.isPremium }.isPremium)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        await #expect(throws: (any Error).self) { _ = try await self.store.purchase(.lifetime) }
        await store.refresh()
        #expect(store.isPremium)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
    }

    @Test func subscriptionStatusOutageFallsBackToVerifiedDates() async throws {
        try await buy(yearlyID)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .subscriptionStatus)
        #expect(await settle { $0.isPremium }.isPremium) // still Premium from the verified transaction's own expiry
        try await session.setSimulatedError(nil, forAPI: .subscriptionStatus)
    }

    // MARK: Paywall offers and purchase flow (M9b)

    @Test func offersShowLocalizedPricesAndTheThreeDayTrialForNewSubscribers() async throws {
        let offers = Dictionary(uniqueKeysWithValues: try await store.offers().map { ($0.plan, $0) })
        let lifetime = try #require(offers[.lifetime])
        #expect(lifetime.displayPrice == "$19.99" && lifetime.price == Decimal(string: "19.99"))
        #expect(lifetime.currencyCode == "USD" && lifetime.storefront == "USA")
        // The configured launch promotion isn't active (no start date), so nothing is labelled.
        #expect(LaunchPromotion.launch.status(for: lifetime, at: .now) == .notConfigured)
        let yearly = try #require(offers[.yearly])
        #expect(yearly.displayPrice == "$9.99")
        #expect(yearly.billingPeriod == BillingPeriod(value: 1, unit: .year))
        #expect(yearly.freeTrial == BillingPeriod(value: 3, unit: .day))
        #expect(PaywallCopy.planDetail(yearly) == "3 days free, then $9.99/year")
        #expect(PaywallCopy.buttonTitle(.yearly, offer: yearly) == "Start 3-day free trial")
    }

    @Test func launchBadgeNeverAppearsWhileStoreKitChargesTheRegularPrice() async throws {
        let active = LaunchPromotion(plan: .lifetime, start: .now - 3_600, durationDays: 14, percentOff: 50, prices: LaunchPromotion.launch.prices)
        let flow = PurchaseFlow(store: store, promotion: active)
        await flow.load()
        #expect(flow.offers[.lifetime]?.displayPrice == "$19.99")
        #expect(flow.promotion(for: .lifetime) == nil) // StoreKit says $19.99, so no "50% off"
    }

    @Test func noTrialForSomeoneWhoAlreadySubscribed() async throws {
        try await buy(yearlyID)
        _ = try await expireYearly()
        let yearly = try #require(try await store.offers().first { $0.plan == .yearly })
        #expect(yearly.freeTrial == nil)
        #expect(!PaywallCopy.planDetail(yearly).localizedCaseInsensitiveContains("free"))
    }

    @Test func purchaseFlowEndToEnd() async throws {
        let flow = PurchaseFlow(store: store)
        await flow.load()
        #expect(flow.phase == .ready && flow.selectedPlan == .lifetime)
        flow.select(.yearly)
        #expect(await flow.purchase())
        #expect(store.isPremium)
        guard case .yearly = store.status else { Issue.record("\(store.status)"); return }
    }

    @Test func productsUnavailableThenRetry() async throws {
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let flow = PurchaseFlow(store: store)
        await flow.load()
        #expect(flow.phase == .unavailable && !flow.canPurchase)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await flow.load()
        #expect(flow.phase == .ready && flow.canPurchase)
    }

    @Test func purchaseErrorLeavesTheFlowRecoverable() async throws {
        let flow = PurchaseFlow(store: store)
        await flow.load()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        #expect(await flow.purchase() == false)
        #expect(flow.phase == .purchaseFailed && !store.isPremium)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        #expect(await flow.purchase())
    }

    /// Restore's App Store sync asks the person to sign in, so it can't run unattended; these cover
    /// what it relies on. The sign-in itself is checked by hand in Sandbox (see the M9 test plan).
    @Test func purchasesAreReadFromStoreKitNotFromTheApp() async throws {
        try await buy(lifetimeID)
        // A brand-new store and source, as after reinstalling: nothing is kept by the app itself.
        _ = await settle { $0.isPremium } // the purchase has landed in StoreKit
        let reinstalled = EntitlementStore(source: StoreKitEntitlementSource())
        await reinstalled.refresh()
        #expect(reinstalled.status == .lifetime(yearlyStillRenewing: false))
    }

    @Test func failedRestoreNeverRevokesPremium() async throws {
        try await buy(lifetimeID)
        _ = await settle { $0.isPremium }
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        await #expect(throws: (any Error).self) { try await self.store.restorePurchases() }
        #expect(store.status == .lifetime(yearlyStillRenewing: false))
        try await session.setSimulatedError(nil, forAPI: .appStoreSync)
    }
}
#endif
