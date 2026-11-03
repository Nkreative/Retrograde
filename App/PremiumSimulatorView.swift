#if DEBUG
import DesignSystem
import Entitlements
import SwiftUI

/// Debug-only controls for the simulated App Store account (M8). Not compiled into release builds.
/// Opened from the gear button until Settings arrives in M9.
struct PremiumSimulatorView: View {
    @Environment(EntitlementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Current status") {
                    LabeledContent("Status", value: store.status.debugName)
                    LabeledContent("Unlocks Premium", value: store.isPremium ? "Yes" : "No")
                    LabeledContent("Transactions", value: "\(store.transactions.count)")
                }
                Section("Simulate") {
                    Button("Buy Yearly") { store.purchase(.yearly) }
                    Button("Buy Lifetime") { store.purchase(.lifetime) }
                    Button("Expire Yearly now") { store.simulateYearlyExpiry() }
                    Button("Reinstall (forget this device's record)") { store.simulateReinstall() }
                    Button("Restore purchases") { store.restorePurchases() }
                    Button("Reset to Free", role: .destructive) { store.simulateReset() }
                }
                Section {
                    Text("Simulated purchases persist across relaunches. Nothing here talks to the App Store; real purchases arrive in M9.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Premium simulator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

extension PremiumStatus {
    var debugName: String {
        switch self {
        case .free: "Free"
        case let .yearly(renewsOn): "Yearly · renews \(renewsOn.formatted(date: .abbreviated, time: .omitted))"
        case .lifetime: "Lifetime"
        case let .yearlyExpired(on): "Yearly expired \(on.formatted(date: .abbreviated, time: .shortened))"
        }
    }
}
#endif
