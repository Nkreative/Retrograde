import Foundation

/// Paywall wording built from StoreKit's localized prices and periods — never hardcoded amounts.
public enum PaywallCopy {
    public static func planName(_ plan: PremiumPlan) -> String {
        switch plan {
        case .lifetime: "Lifetime access"
        case .yearly: "Yearly"
        }
    }

    /// Line under the plan name, e.g. "3 days free, then $9.99/year" or "$6.99 for the first year,
    /// then $9.99/year".
    public static func planDetail(_ offer: PlanOffer) -> String {
        guard let period = offer.billingPeriod else { return "One-time purchase. No renewal." }
        if let trial = offer.freeTrial {
            return "\(trial.length) free, then \(offer.displayPrice)\(period.slashFrequency)"
        }
        if let intro = offer.paidIntro {
            return "\(introTerms(intro)), then \(offer.displayPrice)\(period.slashFrequency)"
        }
        return "Renews \(period.adverb). Cancel anytime."
    }

    /// "$6.99 for the first year" or "$1.99/month for the first 3 months".
    private static func introTerms(_ intro: IntroOffer) -> String {
        switch intro.payment {
        case .payAsYouGo: "\(intro.displayPrice)\(intro.period.slashFrequency) for the first \(intro.duration.firstLength)"
        default: "\(intro.displayPrice) for the first \(intro.duration.firstLength)"
        }
    }

    /// The price being charged first: a paid introductory price, else the regular one.
    public static func price(_ offer: PlanOffer) -> String {
        offer.paidIntro?.displayPrice ?? offer.displayPrice
    }

    /// Right-hand price, e.g. "$19.99", "$9.99 / yr" or "$6.99 first yr".
    public static func priceLabel(_ offer: PlanOffer) -> String {
        guard let unit = priceUnit(offer) else { return price(offer) }
        return "\(price(offer)) \(unit)"
    }

    /// The smaller text after the price ("/ yr", "first yr", "/ mo"); nil for Lifetime.
    public static func priceUnit(_ offer: PlanOffer) -> String? {
        if let intro = offer.paidIntro {
            return intro.payment == .payUpFront ? "first \(intro.duration.abbreviation)" : "/ \(intro.period.abbreviation)"
        }
        return offer.billingPeriod.map { "/ \($0.abbreviation)" }
    }

    /// The regular price shown crossed out beside a discounted first period; only when
    /// `PlanOffer.introPercentOff` confirms StoreKit's two prices are comparable.
    public static func regularPriceStruck(_ offer: PlanOffer) -> String? {
        offer.introPercentOff == nil ? nil : offer.displayPrice
    }

    /// Badge for a discounted first period, e.g. "FIRST YEAR · 30% OFF"; nil when StoreKit's prices
    /// don't support one.
    public static func introBadge(_ offer: PlanOffer) -> String? {
        guard let percent = offer.introPercentOff, let intro = offer.paidIntro else { return nil }
        return "FIRST \(intro.duration.firstLength.uppercased()) · \(percent)% OFF"
    }

    /// Lifetime: "Get lifetime access". Yearly: "Start 3-day free trial" when StoreKit offers this
    /// person a trial, otherwise "Start Premium" (a paid first year's price is on the card and in
    /// the terms beneath the button).
    public static func buttonTitle(_ plan: PremiumPlan, offer: PlanOffer?) -> String {
        switch plan {
        case .lifetime: return "Get lifetime access"
        case .yearly:
            if let trial = offer?.freeTrial { return "Start \(trial.compactLength) free trial" }
            return "Start Premium"
        }
    }

    /// Terms shown under the purchase button for the selected plan.
    public static func disclosure(_ offer: PlanOffer) -> String {
        guard let period = offer.billingPeriod else {
            return "One-time payment of \(offer.displayPrice), charged to your Apple Account. No subscription, no renewal."
        }
        let manage = "Manage or cancel anytime in Settings › Apple Account › Subscriptions."
        if let trial = offer.freeTrial {
            return "Free for \(trial.length), then \(offer.displayPrice) \(period.perFrequency), charged to your Apple Account when the trial ends. Renews automatically \(period.adverb) unless cancelled at least 24 hours before the trial or current period ends. \(manage)"
        }
        if let intro = offer.paidIntro {
            let charged = intro.payment == .payUpFront ? "charged to your Apple Account at confirmation" : "charged to your Apple Account at confirmation and at the start of each period"
            return "\(introTerms(intro)), \(charged). Then \(offer.displayPrice) \(period.perFrequency). Renews automatically unless cancelled at least 24 hours before the current period ends. \(manage)"
        }
        return "\(offer.displayPrice) \(period.perFrequency), charged to your Apple Account at confirmation. Renews automatically \(period.adverb) unless cancelled at least 24 hours before the current period ends. \(manage)"
    }

    /// Badge text for a verified promotion, e.g. "LAUNCH · 50% OFF".
    public static func promotionBadge(_ promotion: LaunchPromotion.Display) -> String {
        "LAUNCH · \(promotion.percentOff)% OFF"
    }

    /// Plan line during a promotion: its last day from the configured schedule ("Nov 17"), in the
    /// person's language but on App Store Connect's Pacific calendar, so the date is the same everywhere.
    public static func promotionDetail(_ promotion: LaunchPromotion.Display, locale: Locale = .autoupdatingCurrent) -> String {
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day().locale(locale)
        style.timeZone = LaunchPromotion.scheduleTimeZone
        return "Launch special through \(promotion.lastDay.formatted(style)). One-time purchase."
    }

    /// VoiceOver label for a plan card: name, Best value (Lifetime only) or a verified discount,
    /// the price being charged first, then the regular price and frequency, trial.
    public static func accessibilityLabel(_ offer: PlanOffer, bestValue: Bool, promotion: LaunchPromotion.Display? = nil) -> String {
        var parts = [planName(offer.plan)]
        if let promotion {
            parts.append("Launch special, \(promotion.percentOff)% off, regular price \(promotion.regularPrice)")
        } else if let percent = offer.introPercentOff, let intro = offer.paidIntro {
            parts.append("\(percent)% off the first \(intro.duration.firstLength)")
        } else if bestValue {
            parts.append("Best value")
        }
        if let period = offer.billingPeriod {
            if let intro = offer.paidIntro {
                parts.append("\(introTerms(intro)), then \(offer.displayPrice) \(period.perFrequency)")
            } else {
                parts.append("\(offer.displayPrice) \(period.perFrequency)")
            }
            if let trial = offer.freeTrial { parts.append("\(trial.compactLength) free trial") }
        } else {
            parts.append("\(offer.displayPrice), one-time purchase")
        }
        return parts.joined(separator: ", ")
    }
}

extension BillingPeriod {
    private var unitName: String {
        switch unit {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        }
    }

    /// "7 days" (weeks are shown as days, as in "7 days free"), "1 month", "2 years".
    public var length: String {
        let (count, name) = unit == .week ? (value * 7, "day") : (value, unitName)
        return "\(count) \(name)\(count == 1 ? "" : "s")"
    }

    /// "year", "month" for one; "2 years", "3 months" otherwise (for "for the first year").
    var firstLength: String { value == 1 && unit != .week ? unitName : length }

    /// "7-day", "1-month" (for "Start 7-day free trial").
    public var compactLength: String {
        let (count, name) = unit == .week ? (value * 7, "day") : (value, unitName)
        return "\(count)-\(name)"
    }

    /// "/year" or " every 2 years".
    var slashFrequency: String { value == 1 ? "/\(unitName)" : " every \(length)" }
    /// "per year" or "every 2 years".
    var perFrequency: String { value == 1 ? "per \(unitName)" : "every \(length)" }
    /// "yearly", "monthly", "every 2 years".
    var adverb: String {
        guard value == 1 else { return "every \(length)" }
        return switch unit {
        case .day: "daily"
        case .week: "weekly"
        case .month: "monthly"
        case .year: "yearly"
        }
    }

    /// "yr", "mo", "wk", "day" (with a count when it isn't 1).
    var abbreviation: String {
        let short = switch unit {
        case .day: "day"
        case .week: "wk"
        case .month: "mo"
        case .year: "yr"
        }
        return value == 1 ? short : "\(value) \(short)"
    }
}
