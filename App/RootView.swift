import DesignSystem
import SwiftUI

struct RootView: View {
    var body: some View {
        #if DEBUG
        // Review aids: `-catalog <page>` shows the design system, `-tab <name>` opens a tab,
        // `-now 2026-10-10T12:00:00Z` pretends it's that moment (to review other cycle stages).
        let defaults = UserDefaults.standard
        let catalogPage = defaults.integer(forKey: "catalog")
        if catalogPage > 0 {
            DesignSystemCatalog(page: catalogPage)
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
