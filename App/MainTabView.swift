import DesignSystem
import SwiftUI

enum AppTab: String, CaseIterable {
    case overview, survivalKit, calendar

    var item: RetroTabItem<AppTab> {
        switch self {
        case .overview: RetroTabItem(id: self, title: "Overview", glyph: .orbit)
        case .survivalKit: RetroTabItem(id: self, title: "Survival kit", glyph: .survivalKit)
        case .calendar: RetroTabItem(id: self, title: "Calendar", glyph: .calendar)
        }
    }
}

/// App shell: header on top, the three destinations, custom tab bar at the bottom.
/// Every tab stays alive when hidden so scroll position and state survive switching.
struct MainTabView: View {
    @State private var selection: AppTab
    @State private var paywall: PaywallPresenter
    #if DEBUG
    @State private var showsSimulator = false
    #endif
    /// Debug-only clock override for reviewing other cycle stages.
    private let now: Date?

    init(initialTab: AppTab = .overview, now: Date? = nil) {
        _selection = State(initialValue: initialTab)
        self.now = now
        let paywall = PaywallPresenter()
        #if DEBUG
        // `-showPaywall YES` opens the paywall on launch, for review.
        paywall.isPresented = UserDefaults.standard.bool(forKey: "showPaywall")
        // `-openSimulator YES` opens the Premium simulator on launch, for review.
        _showsSimulator = State(initialValue: UserDefaults.standard.bool(forKey: "openSimulator"))
        #endif
        _paywall = State(initialValue: paywall)
        #if DEBUG
        PaywallPresenter.current = paywall
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(onShare: {}, onNotifications: {}, onSettings: openSettings)
            ZStack {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    screen(for: tab)
                        .opacity(tab == selection ? 1 : 0)
                        .allowsHitTesting(tab == selection)
                        .accessibilityHidden(tab != selection)
                }
            }
            .frame(maxHeight: .infinity)
            // Stacked below the content (not floating over it) so nothing can scroll underneath.
            RetroTabBar(items: AppTab.allCases.map(\.item), selection: $selection)
        }
        .retroScreenBackground()
        .environment(paywall)
        .fullScreenCover(isPresented: $paywall.isPresented) { PaywallView() }
        #if DEBUG
        .sheet(isPresented: $showsSimulator) { PremiumSimulatorView() }
        #endif
    }

    /// Settings arrives in M9. Debug builds open the Premium simulator here instead.
    private func openSettings() {
        #if DEBUG
        showsSimulator = true
        #endif
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .overview: OverviewScreen(now: now, onOpenSurvivalKit: { selection = .survivalKit })
        case .survivalKit: SurvivalKitTab(now: now)
        case .calendar:
            TimelineView(.everyMinute) { context in
                CalendarScreen(now: now ?? context.date)
            }
        }
    }
}

#Preview {
    MainTabView().onAppear(perform: RetroFonts.register)
}
