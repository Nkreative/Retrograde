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
            if promotionPreview { sim.lifetimePrice = Decimal(string: "9.99")! }
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

    /// The launch promotion the paywall checks. Debug `-promotionPreview YES` runs it from yesterday
    /// (with the simulator charging the promotional price) so it can be reviewed before launch.
    static var promotion: LaunchPromotion {
        #if DEBUG
        if promotionPreview {
            // Started at midnight Pacific yesterday, like an App Store Connect price change.
            var pacific = Calendar(identifier: .gregorian)
            pacific.timeZone = LaunchPromotion.scheduleTimeZone
            let start = pacific.date(byAdding: .day, value: -1, to: pacific.startOfDay(for: .now))
            let l = LaunchPromotion.launch
            return LaunchPromotion(plan: l.plan, start: start, durationDays: l.durationDays, percentOff: l.percentOff, prices: l.prices)
        }
        #endif
        return .launch
    }

    #if DEBUG
    private static var promotionPreview: Bool { UserDefaults.standard.bool(forKey: "promotionPreview") }

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
