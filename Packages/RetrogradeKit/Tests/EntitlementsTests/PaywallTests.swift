import Foundation
import Testing
@testable import Entitlements

@Suite struct PaywallCopyTests {
    let lifetime = PlanOffer(plan: .lifetime, displayPrice: "$19.99")
    let yearlyTrial = PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year), freeTrial: .init(value: 1, unit: .week))
    let yearlyNoTrial = PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year))

    @Test func eligibleYearlyShowsTheTrialThenThePrice() {
        #expect(PaywallCopy.planDetail(yearlyTrial) == "7 days free, then $9.99/year")
        #expect(PaywallCopy.priceLabel(yearlyTrial) == "$9.99 / yr")
        let terms = PaywallCopy.disclosure(yearlyTrial)
        #expect(terms.contains("Free for 7 days, then $9.99 per year"))
        #expect(terms.contains("Renews automatically yearly"))
        #expect(terms.contains("24 hours"))
    }

    @Test func ineligibleYearlyHasNoTrialLanguage() {
        for text in [PaywallCopy.planDetail(yearlyNoTrial), PaywallCopy.disclosure(yearlyNoTrial), PaywallCopy.accessibilityLabel(yearlyNoTrial, bestValue: false)] {
            #expect(!text.localizedCaseInsensitiveContains("free"), "\(text)")
            #expect(!text.localizedCaseInsensitiveContains("trial"), "\(text)")
        }
        #expect(PaywallCopy.disclosure(yearlyNoTrial).hasPrefix("$9.99 per year, charged to your Apple Account at confirmation."))
    }

    @Test func lifetimeIsAOneTimePurchase() {
        #expect(PaywallCopy.planDetail(lifetime) == "One-time purchase. No renewal.")
        #expect(PaywallCopy.priceLabel(lifetime) == "$19.99")
        #expect(PaywallCopy.disclosure(lifetime).contains("One-time payment of $19.99"))
        #expect(PaywallCopy.accessibilityLabel(lifetime, bestValue: true) == "Lifetime access, Best value, $19.99, one-time purchase")
    }

    @Test func usesWhateverStoreKitLocalizes() {
        let euro = PlanOffer(plan: .yearly, displayPrice: "9,99 €", billingPeriod: .init(value: 1, unit: .year))
        #expect(PaywallCopy.priceLabel(euro) == "9,99 € / yr")
    }

    @Test func periodWording() {
        #expect(BillingPeriod(value: 1, unit: .week).length == "7 days")
        #expect(BillingPeriod(value: 3, unit: .day).length == "3 days")
        #expect(BillingPeriod(value: 1, unit: .month).length == "1 month")
        let monthly = PlanOffer(plan: .yearly, displayPrice: "$1", billingPeriod: .init(value: 1, unit: .month), freeTrial: .init(value: 1, unit: .month))
        #expect(PaywallCopy.planDetail(monthly) == "1 month free, then $1/month")
    }

    @Test func buttonFollowsThePlan() {
        #expect(PaywallCopy.buttonTitle(.lifetime) == "Get lifetime access")
        #expect(PaywallCopy.buttonTitle(.yearly) == "Start Premium")
    }
}

@MainActor
@Suite struct PurchaseFlowTests {
    private func make() -> (ScriptedSource, EntitlementStore, PurchaseFlow) {
        let source = ScriptedSource()
        let store = EntitlementStore(source: source, now: { t0 })
        return (source, store, PurchaseFlow(store: store))
    }

    @Test func loadsOffersWithLifetimeSelected() async {
        let (_, _, flow) = make()
        #expect(flow.phase == .loading && !flow.canPurchase)
        await flow.load()
        #expect(flow.phase == .ready)
        #expect(flow.selectedPlan == .lifetime)
        #expect(flow.offers[.yearly]?.freeTrial != nil)
        #expect(flow.canPurchase)
    }

    @Test func unavailableProductsBlockPurchaseUntilRetry() async {
        let (source, _, flow) = make()
        source.failOffers = true
        await flow.load()
        #expect(flow.phase == .unavailable && !flow.canPurchase)
        #expect(await flow.purchase() == false)
        #expect(source.purchaseCalls == 0)
        source.failOffers = false
        await flow.load()
        #expect(flow.phase == .ready && flow.canPurchase)
    }

    @Test func aFailedReloadAfterSuccessStillBlocksPurchase() async {
        let (source, _, flow) = make()
        await flow.load()
        source.failOffers = true
        flow.debugShow(.unavailable)
        #expect(!flow.canPurchase && flow.selectedOffer == nil)
    }

    @Test func fallsBackToAnAvailablePlan() async {
        let (source, _, flow) = make()
        source.offerList = [PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year))]
        await flow.load()
        #expect(flow.selectedPlan == .yearly)
        flow.select(.lifetime) // not available: ignored
        #expect(flow.selectedPlan == .yearly)
    }

    @Test func purchaseUnlocksPremiumImmediately() async {
        let (_, store, flow) = make()
        await flow.load()
        flow.select(.yearly)
        #expect(await flow.purchase())
        #expect(store.isPremium && flow.phase == .ready)
    }

    @Test func duplicatePurchaseAttemptsAreIgnoredWhileProcessing() async {
        let (source, _, flow) = make()
        await flow.load()
        source.holdPurchases = true
        let first = Task { await flow.purchase() }
        #expect(await eventually { flow.phase == .purchasing(.lifetime) })
        #expect(!flow.canPurchase)
        #expect(await flow.purchase() == false) // second tap
        flow.select(.yearly) // can't switch plans mid-purchase
        #expect(flow.selectedPlan == .lifetime)
        #expect(await flow.restore() == false)
        source.purchaseGate?.resume()
        #expect(await first.value)
        #expect(source.purchaseCalls == 1)
    }

    @Test func pendingWaitsForApproval() async {
        let (source, store, flow) = make()
        await store.start()
        await flow.load()
        source.purchaseOutcome = .pending
        #expect(await flow.purchase() == false)
        #expect(flow.phase == .pending && !flow.canPurchase)
        source.snapshot = EntitlementSnapshot(ownsLifetime: true) // approved
        source.continuation.yield()
        #expect(await eventually { store.isPremium })
    }

    @Test func cancellingChangesNothing() async {
        let (source, store, flow) = make()
        await flow.load()
        source.purchaseOutcome = .cancelled
        #expect(await flow.purchase() == false)
        #expect(flow.phase == .ready && !store.isPremium && flow.canPurchase)
    }

    @Test func purchaseErrorIsReportedAndRecoverable() async {
        let (source, store, flow) = make()
        await flow.load()
        source.failPurchase = true
        #expect(await flow.purchase() == false)
        #expect(flow.phase == .purchaseFailed && !store.isPremium && flow.canPurchase)
        flow.select(.yearly)
        #expect(flow.phase == .ready)
    }

    @Test func restoreOutcomes() async {
        let (source, store, flow) = make()
        await flow.load()
        #expect(await flow.restore() == false)
        #expect(flow.phase == .nothingToRestore)
        source.failRestore = true
        #expect(await flow.restore() == false)
        #expect(flow.phase == .restoreFailed)
        source.failRestore = false
        source.snapshot = EntitlementSnapshot(ownsLifetime: true)
        #expect(await flow.restore())
        #expect(store.isPremium && flow.phase == .ready)
    }
}
