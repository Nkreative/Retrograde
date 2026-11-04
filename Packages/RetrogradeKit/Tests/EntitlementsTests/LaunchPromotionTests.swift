import Foundation
import Testing
@testable import Entitlements

@Suite struct LaunchPromotionTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)
    let usd = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
    var promo: LaunchPromotion {
        LaunchPromotion(plan: .lifetime, start: start, durationDays: 14, percentOff: 50, prices: LaunchPromotion.launch.prices)
    }

    private func lifetime(_ price: String, format: Decimal.FormatStyle.Currency? = nil, storefront: String? = "USA") -> PlanOffer {
        let f = format ?? usd
        let amount = Decimal(string: price)!
        return PlanOffer(plan: .lifetime, displayPrice: amount.formatted(f), price: amount, priceFormat: f, storefront: storefront)
    }

    @Test func activeWhenStoreKitChargesTheConfiguredPrice() {
        guard case let .active(display) = promo.status(for: lifetime("9.99"), at: start + 3_600) else { Issue.record("not active"); return }
        #expect(display.percentOff == 50 && display.regularPrice == "$19.99")
        #expect(display.endsAt.timeIntervalSince(start) >= 13 * 86_400 && display.endsAt.timeIntervalSince(start) <= 15 * 86_400)
    }

    /// The end date comes from the configured schedule: a sale starting at midnight Pacific on
    /// Dec 1 runs 14 full days, through Dec 14, and the regular price returns at midnight on Dec 15.
    @Test func endDateFollowsTheConfiguredSchedule() {
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = LaunchPromotion.scheduleTimeZone
        let launch = pacific.date(from: DateComponents(year: 2026, month: 12, day: 1))!
        let p = LaunchPromotion(plan: .lifetime, start: launch, durationDays: 14, percentOff: 50, prices: LaunchPromotion.launch.prices)
        #expect(p.end == pacific.date(from: DateComponents(year: 2026, month: 12, day: 15)))
        guard case let .active(display) = p.status(for: lifetime("9.99"), at: launch + 60) else { Issue.record("not active"); return }
        #expect(PaywallCopy.promotionDetail(display, locale: Locale(identifier: "en_US")) == "Launch special through Dec 14. One-time purchase.")
        // Same last day for someone in another time zone or language.
        #expect(PaywallCopy.promotionDetail(display, locale: Locale(identifier: "en_GB")) == "Launch special through 14 Dec. One-time purchase.")
        // Daylight saving doesn't shift it: a March sale crossing the switch still ends at midnight.
        let spring = pacific.date(from: DateComponents(year: 2027, month: 3, day: 1))!
        let q = LaunchPromotion(plan: .lifetime, start: spring, durationDays: 14, percentOff: 50, prices: LaunchPromotion.launch.prices)
        #expect(q.end == pacific.date(from: DateComponents(year: 2027, month: 3, day: 15)))
    }

    @Test func offBeforeConfigurationOrOutsideTheWindow() {
        #expect(LaunchPromotion.launch.status(for: lifetime("9.99"), at: start) == .notConfigured)
        #expect(promo.status(for: lifetime("9.99"), at: start - 1) == .upcoming)
        #expect(promo.status(for: lifetime("9.99"), at: promo.end!) == .ended)
    }

    @Test func neverInfersADiscountFromThePriceAlone() {
        // Regular price still in StoreKit during the window (e.g. ASC schedule not applied): no badge.
        #expect(promo.status(for: lifetime("19.99"), at: start + 60) == .priceMismatch)
        // A $9.99 price outside the window isn't labelled either.
        #expect(promo.status(for: lifetime("9.99"), at: start - 60) == .upcoming)
    }

    @Test func otherStorefrontsAndCurrencies() {
        let eur = Decimal.FormatStyle.Currency(code: "EUR", locale: Locale(identifier: "fr_FR"))
        #expect(promo.status(for: lifetime("9.99", format: eur, storefront: "FRA"), at: start + 60) == .notOffered)
        #expect(promo.status(for: lifetime("9.99", format: eur, storefront: "USA"), at: start + 60) == .priceMismatch)
    }

    @Test func unavailableStoreKitIsUnverifiable() {
        #expect(promo.status(for: nil, at: start + 60) == .unverifiable)
        #expect(promo.status(for: PlanOffer(plan: .lifetime, displayPrice: "$9.99"), at: start + 60) == .unverifiable)
    }

    @Test func inconsistentConfigurationIsRejected() {
        let wrong = LaunchPromotion(plan: .lifetime, start: start, durationDays: 14, percentOff: 50,
                                    prices: ["USA": .init(currencyCode: "USD", regular: Decimal(string: "19.99")!, promotional: Decimal(string: "14.99")!)])
        #expect(wrong.status(for: lifetime("14.99"), at: start + 60) == .priceMismatch)
    }

    @Test func onlyAppliesToItsPlan() {
        let yearly = PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year),
                               price: Decimal(string: "9.99")!, priceFormat: usd, storefront: "USA")
        #expect(promo.status(for: yearly, at: start + 60) == .unverifiable)
    }

    @Test func copyAndVoiceOver() {
        let d = LaunchPromotion.Display(percentOff: 50, regularPrice: "$19.99", endsAt: start)
        #expect(PaywallCopy.promotionBadge(d) == "LAUNCH · 50% OFF")
        #expect(PaywallCopy.promotionDetail(d, locale: Locale(identifier: "en_US")).hasPrefix("Launch special through "))
        #expect(PaywallCopy.accessibilityLabel(lifetime("9.99"), bestValue: true, promotion: d)
            == "Lifetime access, Launch special, 50% off, regular price $19.99, $9.99, one-time purchase")
        #expect(PaywallCopy.buttonTitle(.yearly, offer: PlanOffer(plan: .yearly, displayPrice: "$9.99", billingPeriod: .init(value: 1, unit: .year), freeTrial: .init(value: 3, unit: .day))) == "Start 3-day free trial")
    }
}

@MainActor
@Suite struct PurchaseFlowPromotionTests {
    @Test func flowShowsPromotionOnlyWhenVerified() async {
        let source = ScriptedSource()
        let usd = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
        source.offerList = [PlanOffer(plan: .lifetime, displayPrice: "$9.99", price: Decimal(string: "9.99")!, priceFormat: usd, storefront: "USA")]
        let start = t0 - 86_400
        let promo = LaunchPromotion(plan: .lifetime, start: start, durationDays: 14, percentOff: 50, prices: LaunchPromotion.launch.prices)
        var clock = t0
        let flow = PurchaseFlow(store: EntitlementStore(source: source, now: { t0 }), promotion: promo, now: { clock })
        await flow.load()
        #expect(flow.promotion(for: .lifetime)?.regularPrice == "$19.99")
        #expect(flow.promotion(for: .yearly) == nil)
        clock = t0 + 20 * 86_400 // ended
        #expect(flow.promotion(for: .lifetime) == nil)
    }
}
