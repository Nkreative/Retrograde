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
    /// returns; re-read for up to 2 s (by default). A wrong mapping still fails once the state has settled.
    private func settle(seconds: Int = 2, _ expected: @escaping (PremiumStatus) -> Bool) async -> PremiumStatus {
        for _ in 0..<(seconds * 10) {
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

    /// Buys Yearly and lets it run out on its own, then waits for the app to see the expiry.
    ///
    /// Forcing an expiry (`expireSubscription`) proved unreliable: StoreKit kept returning the
    /// pre-expiry transaction (renewing, a year ahead) to the app for 10 s or more (see
    /// docs/STOREKIT.md), so the result depended on timing. Here the session runs one billing period
    /// every 2 s and auto-renew is turned off, so the period simply ends: the verified transaction
    /// StoreKit returns then carries an expiry in the past. The wait follows that expiry (a renewal
    /// can slip in before auto-renew is off, adding one more 2 s period), never a longer timeout.
    private func buyYearlyAndLetItExpire() async throws -> PremiumStatus {
        session.timeRate = .oneRenewalEveryTwoSeconds
        try await buy(yearlyID)
        try session.disableAutoRenewForTransaction(identifier: transaction(yearlyID).identifier)
        for _ in 0..<3 {
            guard let expiry = try transaction(yearlyID).expirationDate, expiry > .now else { break }
            try await Task.sleep(for: .seconds(expiry.timeIntervalSinceNow + 0.2))
        }
        return await settle { if case .yearlyExpired = $0 { true } else { false } }
    }

    private func transaction(_ productID: String) throws -> SKTestTransaction {
        try #require(session.allTransactions().last { $0.productIdentifier == productID })
    }

    @Test func startsFree() async {
        await store.refresh()
        #expect(store.status == .free)
    }

    @Test func productsLoadWithLocalizedPricesAndTheFirstYearOffer() async throws {
        let yearly = try await source.product(for: .yearly)
        let lifetime = try await source.product(for: .lifetime)
        #expect(yearly.displayPrice == "$9.99")
        #expect(lifetime.displayPrice == "$19.99")
        #expect(lifetime.type == .nonConsumable)
        let offer = try #require(yearly.subscription?.introductoryOffer)
        #expect(offer.paymentMode == .payUpFront)
        #expect(offer.displayPrice == "$6.99" && offer.price == Decimal(string: "6.99"))
        #expect(offer.period.unit == .year && offer.period.value == 1)
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
        // Apple's verified expiry (the end of the $6.99 first year here), not one the app works out.
        #expect(abs(until.timeIntervalSince(expiry)) < 1)
        #expect(until.timeIntervalSinceNow > 360 * 86_400 && until.timeIntervalSinceNow < 367 * 86_400)
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
        let status = try await buyYearlyAndLetItExpire()
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
        let expired = try await buyYearlyAndLetItExpire()
        guard case .yearlyExpired = expired else { Issue.record("\(expired)"); return }
        #expect(try await store.purchase(.lifetime) == .purchased)
        let status = await settle { $0 == .lifetime(yearlyStillRenewing: false) }
        #expect(status == .lifetime(yearlyStillRenewing: false), "settled on \(status)")
    }

    @Test func askToBuyIsPendingUntilApproved() async throws {
        session.askToBuyEnabled = true
        await store.start()
        // Intermittent (1 in 46 repetitions): the store is clean and Free here, yet the test
        // environment reports the Ask to Buy purchase as both pending and owned. Not retried; this
        // check shows a recurrence isn't leftover state from an earlier test.
        #expect(store.status == .free, "not free before the purchase: \(store.status), transactions: \(session.allTransactions().map(\.productIdentifier))")
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

    @Test func offersShowLocalizedPricesAndTheFirstYearOfferForNewSubscribers() async throws {
        let offers = Dictionary(uniqueKeysWithValues: try await store.offers().map { ($0.plan, $0) })
        let lifetime = try #require(offers[.lifetime])
        #expect(lifetime.displayPrice == "$19.99" && lifetime.price == Decimal(string: "19.99"))
        #expect(lifetime.currencyCode == "USD" && lifetime.storefront == "USA")
        // The configured launch promotion isn't active (no start date), so nothing is labelled.
        #expect(LaunchPromotion.launch.status(for: lifetime, at: .now) == .notConfigured)
        let yearly = try #require(offers[.yearly])
        #expect(yearly.displayPrice == "$9.99")
        #expect(yearly.billingPeriod == BillingPeriod(value: 1, unit: .year))
        #expect(yearly.freeTrial == nil)
        #expect(yearly.paidIntro?.payment == .payUpFront && yearly.paidIntro?.displayPrice == "$6.99")
        #expect(PaywallCopy.planDetail(yearly) == "$6.99 for the first year, then $9.99/year")
        // The badge comes from StoreKit's two prices, not from the app.
        #expect(PaywallCopy.introBadge(yearly) == "FIRST YEAR · 30% OFF")
        #expect(PaywallCopy.buttonTitle(.yearly, offer: yearly) == "Start Premium")
    }

    @Test func launchBadgeNeverAppearsWhileStoreKitChargesTheRegularPrice() async throws {
        let active = LaunchPromotion(plan: .lifetime, start: .now - 3_600, durationDays: 14, percentOff: 50, prices: LaunchPromotion.launch.prices)
        let flow = PurchaseFlow(store: store, promotion: active)
        await flow.load()
        #expect(flow.offers[.lifetime]?.displayPrice == "$19.99")
        #expect(flow.promotion(for: .lifetime) == nil) // StoreKit says $19.99, so no "50% off"
    }

    @Test func noFirstYearOfferForSomeoneWhoAlreadySubscribed() async throws {
        _ = try await buyYearlyAndLetItExpire()
        let yearly = try #require(try await store.offers().first { $0.plan == .yearly })
        #expect(yearly.introOffer == nil)
        #expect(PaywallCopy.priceLabel(yearly) == "$9.99 / yr" && PaywallCopy.introBadge(yearly) == nil)
        #expect(!PaywallCopy.planDetail(yearly).contains("$6.99"))
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
