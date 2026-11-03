import Entitlements
import Foundation

/// Builds the app's single `EntitlementStore`.
///
/// Production (until StoreKit in M9): only the device record, no purchase account — always Free.
/// Debug: a simulated App Store account kept in UserDefaults, so purchases, expiry and restore
/// survive relaunches. `-entitlement free|yearly|lifetime|expiredYearly` (or the older
/// `-premium YES`) starts in that state using throwaway in-memory storage for screenshots.
@MainActor
enum AppEntitlements {
    static func make() -> EntitlementStore {
        #if DEBUG
        if let preset = launchPreset() {
            let store = EntitlementStore(device: InMemoryEntitlementPersistence(), account: InMemoryEntitlementPersistence())
            switch preset {
            case "yearly":
                store.purchase(.yearly)
            case "lifetime":
                store.purchase(.lifetime)
            case "expiredYearly":
                store.purchase(.yearly)
                store.simulateYearlyExpiry()
            default:
                break
            }
            return store
        }
        let store = EntitlementStore(
            device: DefaultsEntitlementPersistence(key: "entitlements.device"),
            account: DefaultsEntitlementPersistence(key: "debug.simulatedAppStoreAccount")
        )
        scheduleScriptedActions(on: store)
        return store
        #else
        return EntitlementStore(device: DefaultsEntitlementPersistence(key: "entitlements.device"), account: nil)
        #endif
    }

    #if DEBUG
    /// `-simulatorScript "buyLifetime@4,expireYearly@8"` runs simulator actions on the persistent
    /// store that many seconds after launch, to demonstrate live changes without restarting.
    /// `@0` runs immediately. Actions: buyYearly, buyLifetime, expireYearly, reinstall, restore, reset.
    private static func scheduleScriptedActions(on store: EntitlementStore) {
        guard let script = UserDefaults.standard.string(forKey: "simulatorScript") else { return }
        for step in script.split(separator: ",") {
            let parts = step.split(separator: "@")
            let action = String(parts[0])
            let delay = parts.count > 1 ? Double(parts[1]) ?? 0 : 0
            let run = {
                switch action {
                case "buyYearly": store.purchase(.yearly)
                case "buyLifetime": store.purchase(.lifetime)
                case "expireYearly": store.simulateYearlyExpiry()
                case "reinstall": store.simulateReinstall()
                case "restore": store.restorePurchases()
                case "reset": store.simulateReset()
                default: assertionFailure("Unknown simulator action \(action)")
                }
            }
            if delay == 0 {
                run()
            } else {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(delay))
                    run()
                }
            }
        }
    }

    private static func launchPreset() -> String? {
        let defaults = UserDefaults.standard
        if let preset = defaults.string(forKey: "entitlement") { return preset }
        return defaults.bool(forKey: "premium") ? "lifetime" : nil
    }
    #endif
}
