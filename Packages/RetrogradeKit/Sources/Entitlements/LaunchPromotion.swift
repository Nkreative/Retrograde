import Foundation

/// A time-limited price promotion configured in App Store Connect (e.g. Lifetime at 50% off for
/// launch). The app never decides the price: StoreKit's price is what's charged. This only decides
/// whether to *label* that price as a promotion — and only when StoreKit's price, currency and
/// storefront match what was configured, inside the configured window.
public struct LaunchPromotion: Equatable, Sendable {
    public struct StorefrontPrice: Equatable, Sendable {
        public let currencyCode: String
        public let regular: Decimal
        public let promotional: Decimal

        public init(currencyCode: String, regular: Decimal, promotional: Decimal) {
            self.currencyCode = currencyCode
            self.regular = regular
            self.promotional = promotional
        }
    }

    /// What the paywall shows while the promotion is valid.
    public struct Display: Equatable, Sendable {
        public let percentOff: Int
        /// The regular price in the storefront's currency format, shown crossed out.
        public let regularPrice: String
        /// When the regular price returns (start + duration, from the configured schedule).
        public let endsAt: Date

        /// The last day of the promotion in App Store Connect's pricing time zone: the day before
        /// the regular price returns at midnight Pacific.
        public var lastDay: Date { endsAt - 1 }
    }

    public enum Status: Equatable, Sendable {
        case active(Display)
        /// No start date configured yet.
        case notConfigured
        case upcoming
        case ended
        /// This storefront has no verified promotional price (other countries, other currencies).
        case notOffered
        /// StoreKit's price or currency doesn't match the configuration.
        case priceMismatch
        /// No StoreKit price to check against (unavailable, offline).
        case unverifiable
    }

    public let plan: PremiumPlan
    /// The exact moment the promotional price takes effect in App Store Connect. Nil = off.
    public let start: Date?
    public let durationDays: Int
    public let percentOff: Int
    /// Keyed by StoreKit storefront code (ISO 3166-1 alpha-3).
    public let prices: [String: StorefrontPrice]

    public init(plan: PremiumPlan, start: Date?, durationDays: Int, percentOff: Int, prices: [String: StorefrontPrice]) {
        self.plan = plan
        self.start = start
        self.durationDays = durationDays
        self.percentOff = percentOff
        self.prices = prices
    }

    /// Launch special: Lifetime 50% off for 14 calendar days, US only ($19.99 → $9.99).
    /// Set `start` to the App Store Connect launch-price start (see docs/STOREKIT.md) — until then it's off.
    public static let launch = LaunchPromotion(
        plan: .lifetime, start: nil, durationDays: 14, percentOff: 50,
        prices: ["USA": StorefrontPrice(currencyCode: "USD", regular: Decimal(string: "19.99")!, promotional: Decimal(string: "9.99")!)]
    )

    /// App Store Connect schedules price changes in Pacific time.
    public static let scheduleTimeZone = TimeZone(identifier: "America/Los_Angeles")!

    /// 14 calendar days after `start`, counted in Pacific time.
    public var end: Date? {
        guard let start else { return nil }
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = Self.scheduleTimeZone
        return pacific.date(byAdding: .day, value: durationDays, to: start)
    }

    public func status(for offer: PlanOffer?, at now: Date) -> Status {
        guard let start, let end else { return .notConfigured }
        if now < start { return .upcoming }
        if now >= end { return .ended }
        guard let offer, offer.plan == plan, let price = offer.price, let format = offer.priceFormat, let storefront = offer.storefront
        else { return .unverifiable }
        guard let configured = prices[storefront] else { return .notOffered }
        // The configuration must be internally consistent and match what StoreKit will charge.
        let expected = configured.regular * Decimal(100 - percentOff) / 100
        guard format.currencyCode == configured.currencyCode, price == configured.promotional,
              abs(NSDecimalNumber(decimal: expected - configured.promotional).doubleValue) < 0.011
        else { return .priceMismatch }
        return .active(Display(percentOff: percentOff, regularPrice: configured.regular.formatted(format), endsAt: end))
    }
}
