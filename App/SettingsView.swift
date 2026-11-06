import DesignSystem
import Entitlements
import Persistence
import Sharing
import StoreKit
import SwiftUI

/// Where Settings can navigate. Routes (not inline links) keep navigation testable and let debug
/// builds open a page directly.
enum SettingsRoute: Hashable {
    case notifications
    case methodology
    case sources
    case legal(LegalPage)
    case support
    case widgets
    #if DEBUG
    case premiumSimulator
    case widgetStatus
    case sharingStatus
    #endif

    /// The page shown for a route, or nil if it isn't available (e.g. a URL not yet configured).
    static func availability(of route: SettingsRoute) -> Bool {
        switch route {
        case let .legal(page): page.url != nil
        case .support: SupportContact.configured.isAvailable
        default: true
        }
    }
}

/// Settings, opened from the gear in the header: Premium, Notifications, how Retrograde works,
/// and About & Support. Native list and navigation, in Retrograde's dark style.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(OnboardingProgress.self) private var onboarding
    @Environment(SharingActivity.self) private var sharing
    @Environment(SurvivalKitActivation.self) private var kitActivation
    @State private var path: [SettingsRoute] = Self.initialPath

    var body: some View {
        NavigationStack(path: $path) {
            ScrollViewReader { proxy in
            List {
                PremiumSection(onUpgrade: openPaywall)
                Section {
                    row(.notifications, "Notifications", icon: RetroSymbol.notifications)
                    // Opens the iOS share sheet directly (the header's share button shows the invite first).
                    Button { ShareSheet.shareApp(recordingIn: sharing) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: RetroSymbol.share).frame(width: 22).foregroundStyle(RetroColor.pink).accessibilityHidden(true)
                            Text("Share Retrograde").retroText(.bodyLarge).foregroundStyle(RetroColor.text)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .accessibilityHint("Opens the share sheet")
                    // Sizes, adding and removing; always here, whatever iOS reports about placed widgets.
                    NavigationLink(value: SettingsRoute.widgets) {
                        HStack(spacing: 12) {
                            Image(systemName: RetroSymbol.widget).frame(width: 22).foregroundStyle(RetroColor.pink).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Widgets").retroText(.bodyLarge).foregroundStyle(RetroColor.text)
                                Text("Small and Medium. Free, no account.").retroText(.body).foregroundStyle(RetroColor.textMuted)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                } header: {
                    SectionHeader("General")
                }
                .listRowBackground(RetroColor.surface)
                Section {
                    row(.methodology, "How we rate each day")
                    row(.sources, "Where our sky data comes from")
                } header: {
                    SectionHeader("How it works")
                }
                .listRowBackground(RetroColor.surface)
                AboutSection(row: { route, title, icon in row(route, title, icon: icon) }).id(Self.aboutID)
                #if DEBUG
                Section {
                    row(.premiumSimulator, "Premium simulator")
                    NavigationLink { ScheduledAlertsView() } label: { Text("Scheduled alerts") }
                        .frame(minHeight: 44)
                    row(.widgetStatus, "Widget status")
                    row(.sharingStatus, "Sharing history")
                    Button("Replay onboarding") {
                        onboarding.reset()
                        kitActivation.reset()
                        dismiss()
                    }
                    .frame(minHeight: 44)
                } header: {
                    SectionHeader("Developer (debug builds only)")
                }
                .listRowBackground(RetroColor.surface)
                #endif
            }
            .retroSettingsStyle()
            #if DEBUG
            .onAppear {
                // `-scrollSettings about` scrolls to About & Support, for review screenshots.
                if UserDefaults.standard.string(forKey: "scrollSettings") == "about" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { proxy.scrollTo(Self.aboutID, anchor: .top) }
                }
            }
            #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: SettingsRoute.self, destination: destination)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .tint(RetroColor.pink)
        .preferredColorScheme(.dark)
    }

    private func row(_ route: SettingsRoute, _ title: String, icon: String? = nil) -> some View {
        NavigationLink(value: route) {
            HStack(spacing: 12) {
                if let icon { Image(systemName: icon).frame(width: 22).foregroundStyle(RetroColor.pink).accessibilityHidden(true) }
                Text(title).retroText(.bodyLarge).foregroundStyle(RetroColor.text)
            }
            .frame(minHeight: 44)
        }
    }

    @ViewBuilder private func destination(_ route: SettingsRoute) -> some View {
        switch route {
        case .notifications: NotificationPreferencesView()
        case .methodology: MethodologyView()
        case .sources: SourcesView()
        case let .legal(page):
            if let url = page.url { WebPageView(title: page.title, url: url) }
        case .support: SupportView(contact: .configured)
        case .widgets: WidgetsSettingsView()
        #if DEBUG
        case .premiumSimulator: PremiumSimulatorView()
        case .widgetStatus: WidgetStatusView()
        case .sharingStatus: SharingStatusView()
        #endif
        }
    }

    private static var initialPath: [SettingsRoute] {
        #if DEBUG
        // `-settingsPath notifications|terms|privacy|support|widgets|widgetStatus|sharingStatus` opens a page directly, for review.
        switch UserDefaults.standard.string(forKey: "settingsPath") {
        case "notifications": return [.notifications]
        case "terms": return [.legal(.terms)]
        case "privacy": return [.legal(.privacy)]
        case "support": return [.support]
        case "widgets": return [.widgets]
        case "widgetStatus": return [.widgetStatus]
        case "sharingStatus": return [.sharingStatus]
        default: return []
        }
        #else
        return []
        #endif
    }

    private static let aboutID = "about"

    /// Close Settings, then open the paywall over the app.
    private func openPaywall() {
        dismiss()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            paywall.present()
        }
    }
}

// MARK: - Premium

private struct PremiumSection: View {
    let onUpgrade: () -> Void
    @Environment(EntitlementStore.self) private var entitlements
    @State private var showsManage = false
    @State private var refundTransaction: UInt64?
    @State private var restoreMessage: String?
    @State private var isRestoring = false

    var body: some View {
        let summary = PremiumSummary.make(status: entitlements.status, hasLoaded: entitlements.hasLoaded) {
            $0.formatted(date: .abbreviated, time: .omitted)
        }
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text("YOUR PLAN").retroText(.monoSmall).foregroundStyle(RetroColor.pink)
                Text(summary.title).retroText(.title).foregroundStyle(RetroColor.text)
                if let detail = summary.detail {
                    Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                if let notice = summary.notice {
                    Label {
                        Text(notice).retroText(.body).foregroundStyle(RetroColor.text)
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(RetroColor.yellow)
                    }
                    .padding(10)
                    .background(RetroColor.background.opacity(0.6), in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.button))
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 6)
            .accessibilityElement(children: .combine)

            ForEach(summary.actions, id: \.self) { action in
                actionRow(action)
            }
            if let restoreMessage {
                Text(restoreMessage).retroText(.body).foregroundStyle(RetroColor.textMuted)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        } header: {
            SectionHeader("Premium")
        }
        .listRowBackground(RetroColor.surface)
        .manageSubscriptionsSheet(isPresented: $showsManage)
        .refundRequestSheet(for: refundTransaction ?? 0, isPresented: Binding(
            get: { refundTransaction != nil }, set: { if !$0 { refundTransaction = nil } }
        ))
    }

    @ViewBuilder private func actionRow(_ action: PremiumSummary.Action) -> some View {
        switch action {
        case .upgrade:
            Button(action: onUpgrade) { row("Upgrade to Premium", icon: RetroSymbol.star, emphasised: true) }
        case .restore:
            Button { Task { await restore() } } label: {
                row(isRestoring ? "Restoring…" : "Restore Purchases", icon: "arrow.clockwise")
            }
            .disabled(isRestoring)
        case .manageSubscription:
            Button { showsManage = true } label: { row("Manage Subscription", icon: "creditcard", external: true) }
        case .requestRefund:
            if Self.usesStoreKit {
                Button { Task { refundTransaction = await latestPremiumTransactionID() } } label: {
                    row("Request a Refund", icon: "arrow.uturn.backward.circle", external: true)
                }
            }
        }
    }

    private func row(_ title: String, icon: String, emphasised: Bool = false, external: Bool = false) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(RetroColor.pink).accessibilityHidden(true)
            Text(title).retroText(emphasised ? .bodyStrong : .bodyLarge).foregroundStyle(RetroColor.text)
            Spacer(minLength: 0)
            if external {
                Image(systemName: RetroSymbol.externalLink).font(.footnote).foregroundStyle(RetroColor.textMuted).accessibilityHidden(true)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private func restore() async {
        isRestoring = true
        restoreMessage = nil
        do {
            try await entitlements.restorePurchases()
            restoreMessage = entitlements.isPremium ? "Purchases restored." : "No Premium purchase was found for this Apple Account."
        } catch {
            restoreMessage = "Couldn’t reach the App Store. Check your connection and try again."
        }
        isRestoring = false
        if let restoreMessage { AccessibilityNotification.Announcement(restoreMessage).post() }
    }

    /// The transaction a refund request would cover: Lifetime if owned, else the latest Yearly.
    private func latestPremiumTransactionID() async -> UInt64? {
        for plan in [PremiumPlan.lifetime, .yearly] {
            if case let .verified(transaction)? = await Transaction.latest(for: plan.productID), transaction.revocationDate == nil {
                return transaction.id
            }
        }
        return nil
    }

    /// Refund requests need real StoreKit transactions; hidden while a debug simulator is in use.
    private static var usesStoreKit: Bool {
        #if DEBUG
        AppEntitlements.simulator == nil
        #else
        true
        #endif
    }
}

// MARK: - About & Support

private struct AboutSection<Row: View>: View {
    let row: (SettingsRoute, String, String?) -> Row

    var body: some View {
        Section {
            if SettingsRoute.availability(of: .legal(.privacy)) {
                row(.legal(.privacy), "Privacy Policy", nil)
            } else {
                missing("Privacy Policy")
            }
            row(.legal(.terms), "Terms of Use", nil)
            if SettingsRoute.availability(of: .support) {
                row(.support, "Contact Support", nil)
            } else {
                missing("Contact Support")
            }
            LabeledContent {
                Text(AppLinks.versionDescription).retroText(.bodyLarge).foregroundStyle(RetroColor.textMuted)
            } label: {
                Text("Version").retroText(.bodyLarge).foregroundStyle(RetroColor.text)
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .combine)
        } header: {
            SectionHeader("About & Support")
        } footer: {
            Text("Retrograde is operated by \(AppLinks.appOperator). Astrology is a reflection prompt, not a prediction.")
                .retroText(.body).foregroundStyle(RetroColor.textMuted)
        }
        .listRowBackground(RetroColor.surface)
    }

    /// A page without its URL/contact yet: flagged in debug builds, hidden in release builds.
    @ViewBuilder private func missing(_ title: String) -> some View {
        #if DEBUG
        HStack {
            Text(title).retroText(.bodyLarge).foregroundStyle(RetroColor.textMuted)
            Spacer()
            Text("NOT SET").retroText(.monoSmall).foregroundStyle(RetroColor.pink)
        }
        .frame(minHeight: 44)
        #endif
    }
}

// MARK: - Information screens

private struct MethodologyView: View {
    var body: some View {
        InfoPage(title: "How we rate each day", paragraphs: [
            "Each day gets an intensity (Calm, Mild, Elevated or Intense) from the sky events that fall on it in your time zone.",
            "Mercury retrograde adds the most, and its turning days (when it appears to stop and change direction) add more. The days around a turning point, Mercury’s shadow periods, Venus or Mars retrograde, other planets changing direction, New and Full Moons, and Mercury moving into a new sign each add a little.",
            "The points add up: none is Calm, 1–2 Mild, 3–4 Elevated, 5 or more Intense. The same day always gets the same rating.",
            "It’s an astrology-inspired reflection score built from verified astronomical events: a prompt to slow down and plan kindly, not a prediction of what will happen.",
        ])
    }
}

private struct SourcesView: View {
    var body: some View {
        InfoPage(title: "Where our sky data comes from", paragraphs: [
            "Planet positions, retrograde dates and shadow periods: NASA/JPL Horizons, the Jet Propulsion Laboratory’s solar-system ephemeris service.",
            "Moon phases: the US Naval Observatory, Astronomical Applications Department.",
            "Signs use the tropical zodiac. Dates cover 2025 to 2030 and are checked against independent calculations before each update.",
            "Fonts: Archivo Black, Space Mono and Inter, under the SIL Open Font License.",
        ])
    }
}

private struct InfoPage: View {
    let title: String
    let paragraphs: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(paragraphs, id: \.self) { Text($0).retroText(.bodyLarge).foregroundStyle(RetroColor.text) }
            }
            .padding(RetroMetrics.screenPadding)
        }
        .retroScreenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SectionHeader: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased()).retroText(.mono).foregroundStyle(RetroColor.textMuted)
    }
}

private extension View {
    func retroSettingsStyle() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(RetroColor.background.ignoresSafeArea())
            .environment(\.defaultMinListRowHeight, 44)
    }
}
