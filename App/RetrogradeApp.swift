import DesignSystem
import SwiftUI

@main
struct RetrogradeApp: App {
    init() {
        RetroFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
