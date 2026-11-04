/// Paywall wording built from StoreKit's localized prices and periods — never hardcoded amounts.
public enum PaywallCopy {
    public static func planName(_ plan: PremiumPlan) -> String {
        switch plan {
        case .lifetime: "Lifetime access"
        case .yearly: "Yearly"
        }
    }

    /// Line under the plan name, e.g. "7 days free, then $9.99/year".
    public static func planDetail(_ offer: PlanOffer) -> String {
        guard let period = offer.billingPeriod else { return "One-time purchase. No renewal." }
        if let trial = offer.freeTrial {
            return "\(trial.length) free, then \(offer.displayPrice)\(period.slashFrequency)"
        }
        return "Renews \(period.adverb). Cancel anytime."
    }

    /// Right-hand price, e.g. "$19.99" or "$9.99 / yr".
    public static func priceLabel(_ offer: PlanOffer) -> String {
        guard let unit = priceUnit(offer) else { return offer.displayPrice }
        return "\(offer.displayPrice) \(unit)"
    }

    /// The smaller frequency shown after the price ("/ yr"); nil for Lifetime.
    public static func priceUnit(_ offer: PlanOffer) -> String? {
        offer.billingPeriod.map { "/ \($0.abbreviation)" }
    }

    /// Lifetime: "Get lifetime access". Yearly: "Start 7-day free trial" when StoreKit offers this
    /// person a trial, otherwise "Start Premium".
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
        return "\(offer.displayPrice) \(period.perFrequency), charged to your Apple Account at confirmation. Renews automatically \(period.adverb) unless cancelled at least 24 hours before the current period ends. \(manage)"
    }

    /// VoiceOver label for a plan card: name, Best value (Lifetime only), full price and frequency, trial.
    public static func accessibilityLabel(_ offer: PlanOffer, bestValue: Bool) -> String {
        var parts = [planName(offer.plan)]
        if bestValue { parts.append("Best value") }
        if let period = offer.billingPeriod {
            parts.append("\(offer.displayPrice) \(period.perFrequency)")
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
