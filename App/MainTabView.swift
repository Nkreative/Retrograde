import DesignSystem
import Entitlements
import Notifications
import Persistence
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
    @State private var router: AppRouter
    @State private var paywall: PaywallPresenter
    @Environment(NotificationHistory.self) private var history
    @Environment(NotificationRoutes.self) private var notificationRoutes
    @Environment(WidgetPrompt.self) private var widgetPrompt
    /// Debug-only clock override for reviewing other cycle stages.
    private let now: Date?
    init(initialTab: AppTab = .overview, now: Date? = nil) {
        let router = AppRouter(tab: initialTab)
        self.now = now
        let paywall = PaywallPresenter()
        #if DEBUG
        // `-showPaywall YES` opens the paywall on launch, for review.
        paywall.isPresented = UserDefaults.standard.bool(forKey: "showPaywall")
        // `-openSettings YES` / `-openNotifications YES` open them on launch, for review.
        router.showsSettings = UserDefaults.standard.bool(forKey: "openSettings")
        router.showsNotificationCenter = UserDefaults.standard.bool(forKey: "openNotifications")
        // `-openShareInvite YES` opens the header's share screen.
        router.showsShareInvite = UserDefaults.standard.bool(forKey: "openShareInvite")
        // `-openWidgetHowTo YES` opens the widget how-to.
        router.showsWidgetHowTo = UserDefaults.standard.bool(forKey: "openWidgetHowTo")
        #endif
        _router = State(initialValue: router)
        _paywall = State(initialValue: paywall)
        #if DEBUG
        PaywallPresenter.current = paywall
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            AppHeader(onShare: router.openShareInvite, onNotifications: router.openNotificationCenter, onSettings: router.openSettings,
                      hasUnreadNotifications: history.unreadCount > 0)
            ZStack {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    screen(for: tab)
                        .opacity(tab == router.tab ? 1 : 0)
                        .allowsHitTesting(tab == router.tab)
                        .accessibilityHidden(tab != router.tab)
                }
            }
            .frame(maxHeight: .infinity)
            // Stacked below the content (not floating over it) so nothing can scroll underneath.
            RetroTabBar(items: AppTab.allCases.map(\.item), selection: $router.tab)
        }
        .retroScreenBackground()
        .environment(paywall)
        .environment(router)
        .fullScreenCover(isPresented: $paywall.isPresented) { PaywallView() }
        // A tapped notification: open where it leads, whether the app was open, in the background
        // or launched by the tap (then it waited until this screen appeared).
        .task(id: notificationRoutes.pending) {
            guard let destination = notificationRoutes.pending else { return }
            try? await Task.sleep(for: .milliseconds(300)) // let the tabs appear first on a cold launch
            notificationRoutes.pending = nil
            paywall.isPresented = false
            router.open(destination)
        }
        // The Home Screen widget opens the Overview.
        .onOpenURL { url in
            guard WidgetLink.opensOverview(url) else { return }
            paywall.isPresented = false
            router.openOverview()
        }
        .sheet(isPresented: $router.showsSettings) { SettingsView().environment(paywall) }
        .sheet(isPresented: $router.showsNotificationCenter) { NotificationCenterView().environment(router) }
        .sheet(isPresented: $router.showsShareInvite) { ShareInviteView() }
        .sheet(isPresented: $router.showsWidgetHowTo, onDismiss: { WidgetPresence.check(into: widgetPrompt) }) { WidgetHowToSheet() }
    }

    @ViewBuilder
    private func screen(for tab: AppTab) -> some View {
        switch tab {
        case .overview: OverviewScreen(now: now)
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
