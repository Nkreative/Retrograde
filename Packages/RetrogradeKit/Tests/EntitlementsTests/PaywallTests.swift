import Foundation
import Testing
@testable import Entitlements

@Suite struct PaywallCopyTests {
    let lifetime = PlanOffer(plan: .lifetime, displayPrice: "$19.99")
    let yearlyTrial = PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year), introOffer: .freeTrial(.init(value: 1, unit: .week)))
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
        let monthly = PlanOffer(plan: .yearly, displayPrice: "$1", billingPeriod: .init(value: 1, unit: .month), introOffer: .freeTrial(.init(value: 1, unit: .month)))
        #expect(PaywallCopy.planDetail(monthly) == "1 month free, then $1/month")
    }

    @Test func buttonFollowsThePlanAndTrialEligibility() {
        #expect(PaywallCopy.buttonTitle(.lifetime, offer: lifetime) == "Get lifetime access")
        #expect(PaywallCopy.buttonTitle(.yearly, offer: yearlyTrial) == "Start 7-day free trial")
        #expect(PaywallCopy.buttonTitle(.yearly, offer: yearlyNoTrial) == "Start Premium")
        #expect(PaywallCopy.buttonTitle(.yearly, offer: nil) == "Start Premium")
    }

    @Test func priceAndFrequencyAreSeparate() {
        #expect(PaywallCopy.priceUnit(yearlyTrial) == "/ yr")
        #expect(PaywallCopy.priceUnit(lifetime) == nil)
    }

    // MARK: Paid introductory offers (v1.0: $6.99 for the first year, then $9.99/year)

    let usd = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
    var firstYear: PlanOffer {
        PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year),
                  introOffer: IntroOffer(payment: .payUpFront, displayPrice: "$6.99", price: Decimal(string: "6.99")!, period: .init(value: 1, unit: .year)),
                  price: Decimal(string: "9.99")!, priceFormat: usd, storefront: "USA")
    }

    @Test func payUpFrontShowsTheFirstYearThenTheRenewal() {
        let offer = firstYear
        #expect(PaywallCopy.planDetail(offer) == "$6.99 for the first year, then $9.99/year")
        #expect(PaywallCopy.price(offer) == "$6.99")
        #expect(PaywallCopy.priceUnit(offer) == "first yr")
        #expect(PaywallCopy.priceLabel(offer) == "$6.99 first yr")
        #expect(PaywallCopy.buttonTitle(.yearly, offer: offer) == "Start Premium")
        #expect(PaywallCopy.disclosure(offer) == "$6.99 for the first year, charged to your Apple Account at confirmation. Then $9.99 per year. Renews automatically unless cancelled at least 24 hours before the current period ends. Manage or cancel anytime in Settings › Apple Account › Subscriptions.")
        for text in [PaywallCopy.planDetail(offer), PaywallCopy.disclosure(offer), PaywallCopy.accessibilityLabel(offer, bestValue: false)] {
            #expect(!text.localizedCaseInsensitiveContains("trial"), "\(text)")
        }
    }

    @Test func discountComesOnlyFromStoreKitsTwoPrices() {
        // (9.99 − 6.99) / 9.99 = 30.03 %, rounded down so it's never overstated.
        #expect(firstYear.introPercentOff == 30)
        #expect(PaywallCopy.introBadge(firstYear) == "FIRST YEAR · 30% OFF")
        #expect(PaywallCopy.regularPriceStruck(firstYear) == "$9.99")
        #expect(PaywallCopy.accessibilityLabel(firstYear, bestValue: false) == "Yearly, 30% off the first year, $6.99 for the first year, then $9.99 per year")
        // No regular price from StoreKit to compare with: no badge, nothing crossed out.
        let unverified = PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year), introOffer: firstYear.introOffer)
        #expect(unverified.introPercentOff == nil && PaywallCopy.introBadge(unverified) == nil && PaywallCopy.regularPriceStruck(unverified) == nil)
        // A trial isn't a discount badge.
        #expect(yearlyTrial.introPercentOff == nil && PaywallCopy.introBadge(yearlyTrial) == nil)
    }

    @Test func introThatIsntCheaperOrSpansOtherPeriodsGetsNoBadge() {
        let same = PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year),
                             introOffer: IntroOffer(payment: .payUpFront, displayPrice: "$9.99", price: Decimal(string: "9.99")!, period: .init(value: 1, unit: .year)),
                             price: Decimal(string: "9.99")!, priceFormat: usd)
        #expect(same.introPercentOff == nil)
        let sixMonths = PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year),
                                  introOffer: IntroOffer(payment: .payUpFront, displayPrice: "$2.99", price: Decimal(string: "2.99")!, period: .init(value: 6, unit: .month)),
                                  price: Decimal(string: "9.99")!, priceFormat: usd)
        #expect(sixMonths.introPercentOff == nil)
        #expect(PaywallCopy.planDetail(sixMonths) == "$2.99 for the first 6 months, then $9.99/year")
    }

    @Test func payAsYouGoShowsThePerPeriodPrice() {
        let offer = PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year),
                              introOffer: IntroOffer(payment: .payAsYouGo, displayPrice: "$0.99", price: Decimal(string: "0.99")!, period: .init(value: 1, unit: .month), periodCount: 3),
                              price: Decimal(string: "9.99")!, priceFormat: usd)
        #expect(PaywallCopy.planDetail(offer) == "$0.99/month for the first 3 months, then $9.99/year")
        #expect(PaywallCopy.priceLabel(offer) == "$0.99 / mo")
        #expect(PaywallCopy.disclosure(offer).hasPrefix("$0.99/month for the first 3 months, charged to your Apple Account at confirmation and at the start of each period. Then $9.99 per year."))
        #expect(offer.introPercentOff == nil)
    }

    @Test func ineligibleSubscribersSeeTheRegularPrice() {
        // StoreKit's eligibility check leaves `introOffer` empty for them.
        #expect(PaywallCopy.priceLabel(yearlyNoTrial) == "$9.99 / yr")
        #expect(PaywallCopy.introBadge(yearlyNoTrial) == nil)
    }

    @Test func voiceOverReadsFullPriceAndFrequency() {
        #expect(PaywallCopy.accessibilityLabel(yearlyTrial, bestValue: false) == "Yearly, $9.99 per year, 7-day free trial")
        #expect(PaywallCopy.accessibilityLabel(yearlyNoTrial, bestValue: false) == "Yearly, $9.99 per year")
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
