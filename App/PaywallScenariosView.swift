#if DEBUG
import DesignSystem
import Entitlements
import SwiftUI

/// Settings › Developer › Paywall scenarios (debug builds only): opens the real paywall in each
/// pricing scenario, with a throwaway simulated store, so no device date or launch argument
/// changes are needed. Nothing here touches StoreKit or the app's real Premium state.
struct PaywallScenariosView: View {
    @State private var open: PromotionPreview?

    var body: some View {
        List {
            Section {
                ForEach(PromotionPreview.allCases) { scenario in
                    Button { open = scenario } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scenario.title).retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                            Text(scenario.expected).retroText(.body).foregroundStyle(RetroColor.textMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }
            } footer: {
                Text("Simulated prices. Purchases in these previews go to an in-memory simulator and are thrown away: no StoreKit transaction, no change to Premium.")
            }
            .listRowBackground(RetroColor.surface)
        }
        .retroSettingsStyle()
        .navigationTitle("Paywall scenarios")
        .fullScreenCover(item: $open) { PaywallScenarioPreview(scenario: $0) }
        .onAppear {
            // `-paywallScenario mercury` opens one directly, for review screenshots.
            if open == nil, let name = UserDefaults.standard.string(forKey: "paywallScenario") {
                open = PromotionPreview(rawValue: name)
            }
        }
    }
}

/// The real `PaywallView` with the scenario's promotion and its own simulated store, labelled.
private struct PaywallScenarioPreview: View {
    let scenario: PromotionPreview
    @State private var store: EntitlementStore

    init(scenario: PromotionPreview) {
        self.scenario = scenario
        _store = State(initialValue: AppEntitlements.previewStore(for: scenario))
    }

    var body: some View {
        PaywallView(previewPromotion: scenario.promotion())
            .environment(store)
            .overlay(alignment: .top) {
                Text("SIMULATED · \(scenario.title.uppercased())")
                    .retroText(.monoSmall)
                    .foregroundStyle(RetroColor.background)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(RetroColor.pink, in: Capsule())
                    .padding(.top, 8)
                    .padding(.horizontal, 60) // clear of the ✕
                    .allowsHitTesting(false)
                    .accessibilityLabel("Simulated preview: \(scenario.title)")
            }
    }
}
#endif
