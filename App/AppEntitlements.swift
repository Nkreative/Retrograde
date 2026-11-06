import Entitlements
import Foundation

/// Builds the app's single `EntitlementStore`.
///
/// Production: StoreKit 2 verified transactions only.
/// Debug: StoreKit too — against `StoreKit/Retrograde.storekit` when run from Xcode — unless the
/// M8 simulator is explicitly requested with `-entitlementSource simulated`, or a throwaway state
/// with `-entitlement free|yearly|lifetime|lifetimeAndYearly|expiredYearly|gracePeriod|billingIssue` (`-premium YES`
/// = lifetime). The simulator is not compiled into release builds.
@MainActor
enum AppEntitlements {
    #if DEBUG
    /// The simulator, when the debug build is using it.
    private(set) static var simulator: SimulatedEntitlementSource?
    #endif

    static func make() -> EntitlementStore {
        #if DEBUG
        let defaults = UserDefaults.standard
        if let preset = defaults.string(forKey: "entitlement") ?? (defaults.bool(forKey: "premium") ? "lifetime" : nil) {
            let sim = SimulatedEntitlementSource(storage: InMemoryAccountStorage())
            if let promotionPreview { sim.lifetimePrice = promotionPreview.lifetimePrice }
            apply(preset: preset, to: sim)
            simulator = sim
            return EntitlementStore(source: sim)
        }
        if defaults.string(forKey: "entitlementSource") == "simulated" {
            let sim = SimulatedEntitlementSource(storage: DefaultsAccountStorage(key: "debug.simulatedAppStoreAccount"))
            simulator = sim
            scheduleScriptedActions(on: sim)
            return EntitlementStore(source: sim)
        }
        #endif
        return EntitlementStore(source: StoreKitEntitlementSource())
    }

    /// The Lifetime promotion the paywall checks: the launch window (from `LaunchPromotion.launch`)
    /// and a Mercury window before every verified Mercury direct station in the bundled sky data.
    /// Either shows only while StoreKit charges the promotional price.
    /// Debug `-promotionPreview <scenario>` (with `-entitlement`, YES = launch) previews one of the
    /// `PromotionPreview` scenarios; Settings › Developer › Paywall scenarios shows them all.
    static var promotion: LaunchPromotion {
        let stations = SkyData.ephemeris?.retrogrades(of: .mercury).map(\.stationDirect) ?? []
        #if DEBUG
        if let promotionPreview { return promotionPreview.promotion() }
        #endif
        return LaunchPromotion.launch.withMercuryStations(stations)
    }

    #if DEBUG
    private static var promotionPreview: PromotionPreview? {
        let value = UserDefaults.standard.string(forKey: "promotionPreview")
        return value == "YES" ? .launch : value.flatMap(PromotionPreview.init(rawValue:))
    }

    /// A throwaway store for a scenario preview: an in-memory simulator charging the scenario's
    /// Lifetime price. Never StoreKit, never the app's real Premium state.
    static func previewStore(for scenario: PromotionPreview) -> EntitlementStore {
        let sim = SimulatedEntitlementSource(storage: InMemoryAccountStorage())
        sim.lifetimePrice = scenario.lifetimePrice
        return EntitlementStore(source: sim)
    }

    private static func apply(preset: String, to sim: SimulatedEntitlementSource) {
        let buyYearly = { Task { _ = try? await sim.purchase(.yearly) } }
        switch preset {
        case "yearly": _ = buyYearly()
        case "lifetime": Task { _ = try? await sim.purchase(.lifetime) }
        case "lifetimeAndYearly": Task { _ = try? await sim.purchase(.yearly); _ = try? await sim.purchase(.lifetime) }
        case "expiredYearly": Task { _ = try? await sim.purchase(.yearly); sim.expireYearly() }
        case "gracePeriod": Task { _ = try? await sim.purchase(.yearly); sim.enterGracePeriod() }
        case "billingIssue": Task { _ = try? await sim.purchase(.yearly); sim.enterBillingRetry() }
        default: break
        }
    }

    /// `-simulatorScript "buyYearly@5,expireYearly@10"` runs simulator actions that many seconds
    /// after launch (`@0` = immediately). Actions: buyYearly, buyLifetime, expireYearly, grace,
    /// billingRetry, cancelRenewal, refundYearly, refundLifetime, reset.
    private static func scheduleScriptedActions(on sim: SimulatedEntitlementSource) {
        guard let script = UserDefaults.standard.string(forKey: "simulatorScript") else { return }
        for step in script.split(separator: ",") {
            let parts = step.split(separator: "@")
            let action = String(parts[0])
            let delay = parts.count > 1 ? Double(parts[1]) ?? 0 : 0
            Task { @MainActor in
                if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
                switch action {
                case "buyYearly": _ = try? await sim.purchase(.yearly)
                case "buyLifetime": _ = try? await sim.purchase(.lifetime)
                case "expireYearly": sim.expireYearly()
                case "grace": sim.enterGracePeriod()
                case "billingRetry": sim.enterBillingRetry()
                case "cancelRenewal": sim.turnOffAutoRenew()
                case "refundYearly": sim.refund(.yearly)
                case "refundLifetime": sim.refund(.lifetime)
                case "reset": sim.reset()
                default: assertionFailure("Unknown simulator action \(action)")
                }
            }
        }
    }
    #endif
}

#if DEBUG
/// The paywall's pricing scenarios, for review on a phone or simulator (debug builds only): what
/// the simulated App Store charges for Lifetime and which promotion windows are running, relative
/// to now. Launch windows start at midnight Pacific like an App Store Connect price change.
enum PromotionPreview: String, CaseIterable, Identifiable {
    case regular, launch, mercury, both, mercuryNoDiscount, expired

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regular: "Regular pricing"
        case .launch: "Launch promotion"
        case .mercury: "Mercury promotion"
        case .both: "Launch + Mercury overlap"
        case .mercuryNoDiscount: "Mercury window, no StoreKit discount"
        case .expired: "Expired promotion"
        }
    }

    /// What the paywall should show.
    var expected: String {
        switch self {
        case .regular: "BEST VALUE, $19.99, evergreen headline."
        case .launch: "LAUNCH OFFER, $19.99 crossed out, $9.99, ends in 13 days."
        case .mercury: "MERCURY OFFER, $19.99 crossed out, $9.99, Mercury headline, ends in 2–3 days."
        case .both: "MERCURY OFFER, $9.99 (no extra discount), Mercury headline, ends with the launch window in 13 days."
        case .mercuryNoDiscount: "StoreKit still charges $19.99: BEST VALUE, evergreen headline, no offer."
        case .expired: "Launch and Mercury windows over: BEST VALUE, $19.99, evergreen headline."
        }
    }

    /// The simulated StoreKit Lifetime price.
    var lifetimePrice: Decimal {
        switch self {
        case .launch, .mercury, .both: Decimal(string: "9.99")!
        case .regular, .mercuryNoDiscount, .expired: Decimal(string: "19.99")!
        }
    }

    func promotion(now: Date = .now) -> LaunchPromotion {
        var pacific = Calendar(identifier: .gregorian)
        pacific.timeZone = LaunchPromotion.scheduleTimeZone
        let today = pacific.startOfDay(for: now)
        let launchStart: Date?, stations: [Date]
        switch self {
        case .regular: (launchStart, stations) = (nil, [])
        case .launch: (launchStart, stations) = (pacific.date(byAdding: .day, value: -1, to: today), [])
        case .mercury, .mercuryNoDiscount: (launchStart, stations) = (nil, [now.addingTimeInterval(3 * 86_400)])
        case .both: (launchStart, stations) = (pacific.date(byAdding: .day, value: -1, to: today), [now.addingTimeInterval(3 * 86_400)])
        // The launch window ended at midnight; Mercury turned direct two days ago.
        case .expired: (launchStart, stations) = (pacific.date(byAdding: .day, value: -LaunchPromotion.launch.durationDays, to: today), [now.addingTimeInterval(-2 * 86_400)])
        }
        let l = LaunchPromotion.launch
        return LaunchPromotion(plan: l.plan, start: launchStart, durationDays: l.durationDays, percentOff: l.percentOff, prices: l.prices, mercuryStations: stations)
    }
}
#endif
