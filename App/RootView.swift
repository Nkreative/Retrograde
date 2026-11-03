import DesignSystem
import SwiftUI

struct RootView: View {
    var body: some View {
        #if DEBUG
        // Review aids: `-catalog <page>` shows the design system, `-tab <name>` opens a tab.
        let catalogPage = UserDefaults.standard.integer(forKey: "catalog")
        if catalogPage > 0 {
            DesignSystemCatalog(page: catalogPage)
        } else {
            MainTabView(initialTab: UserDefaults.standard.string(forKey: "tab").flatMap(AppTab.init) ?? .overview)
        }
        #else
        MainTabView()
        #endif
    }
}
