import DesignSystem
import Entitlements
import Persistence
import SwiftUI

/// First launch: the onboarding (splash, then notifications), then Premium as its last step, then
/// the app. Each step crossfades into the next; Premium isn't offered again automatically.
/// Onboarding is saved as complete as Premium appears, so a relaunch (or an existing user) goes
/// straight to the app.
struct RootView: View {
    @Environment(OnboardingProgress.self) private var onboarding
    @Environment(EntitlementStore.self) private var entitlements
    /// Premium, as onboarding's last step (first launch only, never for Premium users).
    @State private var offersPremium = false

    private enum Stage { case onboarding, premium, app }

    var body: some View {
        let stage: Stage = offersPremium ? .premium : onboarding.isComplete ? .app : .onboarding
        ZStack {
            switch stage {
            case .onboarding: OnboardingView(onFinished: finishOnboarding).transition(.opacity)
            case .premium: PaywallView(onClose: { offersPremium = false }).transition(.opacity)
            case .app: main.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: stage)
    }

    /// The notifications screen is done: on to Premium (once purchases are known, so Premium users
    /// skip it), saving onboarding as complete in the same step.
    private func finishOnboarding() {
        Task { @MainActor in
            for _ in 0..<30 where !entitlements.hasLoaded { try? await Task.sleep(for: .milliseconds(100)) }
            offersPremium = !entitlements.isPremium
            onboarding.complete()
        }
    }

    @ViewBuilder private var main: some View {
        #if DEBUG
        // Review aids: `-catalog <page>` shows the design system, `-tab <name>` opens a tab,
        // `-now 2026-10-10T12:00:00Z` pretends it's that moment (to review other cycle stages).
        let defaults = UserDefaults.standard
        let catalogPage = defaults.integer(forKey: "catalog")
        if catalogPage > 0 {
            DesignSystemCatalog(page: catalogPage)
        } else if defaults.bool(forKey: "widgetPreview") {
            // `-widgetPreview YES` shows the Home Screen widget in each phase (add `missing` for no data).
            WidgetPreviewScreen(now: defaults.string(forKey: "now").flatMap { try? Date($0, strategy: .iso8601) } ?? .now)
        } else {
            MainTabView(
                initialTab: defaults.string(forKey: "tab").flatMap(AppTab.init) ?? .overview,
                now: defaults.string(forKey: "now").flatMap { try? Date($0, strategy: .iso8601) }
            )
        }
        #else
        MainTabView()
        #endif
    }
}
