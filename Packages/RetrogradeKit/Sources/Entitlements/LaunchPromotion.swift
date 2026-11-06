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

    /// Which promotional period is running. Both charge the same promotional price; they never stack.
    public enum Kind: Equatable, Sendable {
        /// The 14 days from the public App Store release.
        case launch
        /// The 7 days leading up to a Mercury direct station.
        case mercury
    }

    /// One scheduled period of the promotional price, [start, end).
    public struct Window: Equatable, Sendable {
        public let kind: Kind
        public let start: Date
        public let end: Date
    }

    /// What the paywall shows while the promotion is valid.
    public struct Display: Equatable, Sendable {
        /// Mercury whenever a Mercury window is running (also when it overlaps the launch window).
        public var kind: Kind = .launch
        public let percentOff: Int
        /// The regular price in the storefront's currency format, shown crossed out.
        public let regularPrice: String
        /// When the regular price returns: the end of the unbroken run of promotional windows
        /// containing now (overlapping or back-to-back windows are one price period).
        public let endsAt: Date

        /// The last day of the promotion in App Store Connect's pricing time zone: the day before
        /// the regular price returns at midnight Pacific.
        public var lastDay: Date { endsAt - 1 }
    }

    public enum Status: Equatable, Sendable {
        case active(Display)
        /// No launch date and no Mercury dates configured.
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
    /// Verified Mercury direct stations (from the bundled sky data); each gives a Mercury window.
    public let mercuryStations: [Date]

    /// Calendar days before a Mercury direct station that the Mercury promotion runs.
    public static let mercuryLeadDays = 7

    public init(plan: PremiumPlan, start: Date?, durationDays: Int, percentOff: Int, prices: [String: StorefrontPrice], mercuryStations: [Date] = []) {
        self.plan = plan
        self.start = start
        self.durationDays = durationDays
        self.percentOff = percentOff
        self.prices = prices
        self.mercuryStations = mercuryStations
    }

    /// The same promotion with the Mercury windows for these station-direct instants.
    public func withMercuryStations(_ stations: [Date]) -> LaunchPromotion {
        LaunchPromotion(plan: plan, start: start, durationDays: durationDays, percentOff: percentOff, prices: prices, mercuryStations: stations)
    }

    private static var pacific: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = scheduleTimeZone
        return c
    }

    /// The Mercury window for a station: the 7 calendar days before the station's Pacific date,
    /// midnight to midnight Pacific (as App Store Connect price changes run). A station at 7:54 am
    /// Pacific on Nov 13 gives Nov 6 00:00 – Nov 13 00:00 Pacific.
    public static func mercuryWindow(station: Date) -> Window? {
        let day = pacific.startOfDay(for: station)
        guard let start = pacific.date(byAdding: .day, value: -mercuryLeadDays, to: day) else { return nil }
        return Window(kind: .mercury, start: start, end: day)
    }

    /// Every promotional window, earliest first.
    public var windows: [Window] {
        var all = mercuryStations.compactMap(Self.mercuryWindow)
        if let start, let end { all.append(Window(kind: .launch, start: start, end: end)) }
        return all.sorted { $0.start < $1.start }
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
        let windows = windows
        guard !windows.isEmpty else { return .notConfigured }
        let running = windows.filter { $0.start <= now && now < $0.end }
        guard !running.isEmpty else { return windows.contains { $0.start > now } ? .upcoming : .ended }
        // One price period: extend through any window that overlaps or follows on without a gap.
        var end = running.map(\.end).max()!
        for w in windows where w.start <= end && w.end > end { end = w.end }
        let kind: Kind = running.contains { $0.kind == .mercury } ? .mercury : .launch
        guard let offer, offer.plan == plan, let price = offer.price, let format = offer.priceFormat, let storefront = offer.storefront
        else { return .unverifiable }
        guard let configured = prices[storefront] else { return .notOffered }
        // The configuration must be internally consistent and match what StoreKit will charge.
        let expected = configured.regular * Decimal(100 - percentOff) / 100
        guard format.currencyCode == configured.currencyCode, price == configured.promotional,
              abs(NSDecimalNumber(decimal: expected - configured.promotional).doubleValue) < 0.011
        else { return .priceMismatch }
        return .active(Display(kind: kind, percentOff: percentOff, regularPrice: configured.regular.formatted(format), endsAt: end))
    }
}
