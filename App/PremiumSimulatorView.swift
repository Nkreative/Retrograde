#if DEBUG
import DesignSystem
import Entitlements
import SwiftUI

/// Debug-only view of the Premium state, with simulator controls when the debug build runs with
/// `-entitlementSource simulated`. Not compiled into release builds. Pushed from Settings › Developer.
struct PremiumSimulatorView: View {
    @Environment(EntitlementStore.self) private var store
    var body: some View {
        List {
            Section("Current status") {
                LabeledContent("Status", value: store.status.debugName)
                LabeledContent("Unlocks Premium", value: store.isPremium ? "Yes" : "No")
                LabeledContent("Source", value: AppEntitlements.simulator == nil ? "StoreKit" : "Simulator")
            }
            if let sim = AppEntitlements.simulator {
                Section("Simulate") {
                    Button("Buy Yearly") { Task { _ = try? await store.purchase(.yearly) } }
                    Button("Buy Lifetime") { Task { _ = try? await store.purchase(.lifetime) } }
                    Button("Turn off auto-renew") { sim.turnOffAutoRenew() }
                    Button("Billing problem (grace period)") { sim.enterGracePeriod() }
                    Button("Billing problem (retry, no grace)") { sim.enterBillingRetry() }
                    Button("Expire Yearly now") { sim.expireYearly() }
                    Button("Refund Yearly") { sim.refund(.yearly) }
                    Button("Refund Lifetime") { sim.refund(.lifetime) }
                    Button("Reset to Free", role: .destructive) { sim.reset() }
                }
            } else {
                Section {
                    Text("Using StoreKit. From Xcode, purchases run against StoreKit/Retrograde.storekit; manage them with Debug › StoreKit › Manage Transactions. Launch with -entitlementSource simulated for the simulator.")
                        .font(.footnote)
                }
            }
            Section {
                Button("Refresh from source") { Task { await store.refresh() } }
                Button("Restore purchases") { Task { try? await store.restorePurchases() } }
            }
        }
    .navigationTitle("Premium (debug)")
    .navigationBarTitleDisplayMode(.inline)
}
}

extension PremiumStatus {
    var debugName: String {
        func day(_ date: Date?) -> String { date?.formatted(date: .abbreviated, time: .omitted) ?? "?" }
        switch self {
        case .free: return "Free"
        case let .lifetime(renewing): return renewing ? "Lifetime (Yearly still renewing)" : "Lifetime"
        case let .yearly(until, willRenew): return willRenew ? "Yearly · renews \(day(until))" : "Yearly · ends \(day(until))"
        case let .yearlyGracePeriod(until): return "Billing issue · grace until \(day(until))"
        case .yearlyBillingIssue: return "Billing issue"
        case let .yearlyExpired(on): return "Yearly ended \(day(on))"
        }
    }
}
#endif
