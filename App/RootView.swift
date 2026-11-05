import DesignSystem
import Persistence
import SwiftUI

/// First launch shows the onboarding (splash, then notifications); after that, the app itself.
/// Finishing onboarding crossfades to the app, which then offers Premium once.
struct RootView: View {
    @Environment(OnboardingProgress.self) private var onboarding
    @State private var offersPremium = false

    var body: some View {
        ZStack {
            if onboarding.isComplete {
                main.transition(.opacity)
            } else {
                OnboardingView { offersPremium = true }.transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: onboarding.isComplete)
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
                now: defaults.string(forKey: "now").flatMap { try? Date($0, strategy: .iso8601) },
                offersPremium: $offersPremium
            )
        }
        #else
        MainTabView(offersPremium: $offersPremium)
        #endif
    }
}
