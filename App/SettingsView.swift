import DesignSystem
import Entitlements
import Notifications
import StoreKit
import SwiftUI

/// Settings, opened from the gear in the header: Premium, notification choices, how Retrograde
/// works, and About & Support. Native list and navigation, in Retrograde's dark style.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlements
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(NotificationPreferences.self) private var notifications

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                PremiumSection(onUpgrade: openPaywall)
                NotificationsSection(preferences: notifications)
                Section {
                    NavigationLink { MethodologyView() } label: { Text("How we rate each day").retroText(.bodyLarge) }
                    NavigationLink { SourcesView() } label: { Text("Where our sky data comes from").retroText(.bodyLarge) }
                } header: {
                    SectionHeader("How it works")
                }
                .listRowBackground(RetroColor.surface)
                AboutSection().id(Self.aboutID)
                #if DEBUG
                Section {
                    NavigationLink("Premium simulator") { PremiumSimulatorView() }
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .tint(RetroColor.pink)
        .preferredColorScheme(.dark)
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

// MARK: - Notifications

private struct NotificationsSection: View {
    @Bindable var preferences: NotificationPreferences

    var body: some View {
        Section {
            toggle(.retrogradeStarts, "Retrograde begins", "When a planet turns retrograde.")
            toggle(.retrogradeEnds, "Retrograde ends", "When a planet turns direct again.")
            toggle(.dailyGuidance, "Daily cosmic guidance", "One note a day with the intensity and a habit.")
        } header: {
            SectionHeader("Notifications")
        } footer: {
            Text("Alerts arrive in an upcoming update. Your choices are saved now, and we’ll only ask for notification permission once alerts are ready.")
                .retroText(.body).foregroundStyle(RetroColor.textMuted)
        }
        .listRowBackground(RetroColor.surface)
    }

    private func toggle(_ kind: NotificationKind, _ title: String, _ detail: String) -> some View {
        Toggle(isOn: Binding(get: { preferences.isEnabled(kind) }, set: { preferences.set(kind, $0) })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).retroText(.bodyLarge).foregroundStyle(RetroColor.text)
                Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
        }
        .padding(.vertical, 2)
        .accessibilityHint("Saved for when alerts are available")
    }
}

// MARK: - About & Support

private struct AboutSection: View {
    var body: some View {
        Section {
            if let privacy = AppLinks.privacyPolicy {
                linkRow("Privacy Policy", privacy)
            } else {
                missing("Privacy Policy")
            }
            linkRow("Terms of Use", AppLinks.termsOfUse)
            if let support = AppLinks.support {
                linkRow("Contact Support", support)
            } else {
                missing("Contact Support")
            }
            LabeledContent {
                Text(AppLinks.versionDescription).retroText(.bodyLarge).foregroundStyle(RetroColor.textMuted)
            } label: {
                Text("Version").retroText(.bodyLarge).foregroundStyle(RetroColor.text)
            }
            .accessibilityElement(children: .combine)
        } header: {
            SectionHeader("About & Support")
        } footer: {
            Text("Retrograde is operated by \(AppLinks.appOperator). Astrology is a reflection prompt, not a prediction.")
                .retroText(.body).foregroundStyle(RetroColor.textMuted)
        }
        .listRowBackground(RetroColor.surface)
    }

    private func linkRow(_ title: String, _ url: URL) -> some View {
        Link(destination: url) {
            HStack {
                Text(title).retroText(.bodyLarge).foregroundStyle(RetroColor.text)
                Spacer()
                Image(systemName: RetroSymbol.externalLink).font(.footnote).foregroundStyle(RetroColor.textMuted).accessibilityHidden(true)
            }
            .frame(minHeight: 44)
        }
        .accessibilityHint("Opens in Safari")
    }

    /// A link without its URL yet: shown in debug builds as a reminder, hidden in release builds.
    @ViewBuilder private func missing(_ title: String) -> some View {
        #if DEBUG
        HStack {
            Text(title).retroText(.bodyLarge).foregroundStyle(RetroColor.textMuted)
            Spacer()
            Text("URL NOT SET").retroText(.monoSmall).foregroundStyle(RetroColor.pink)
        }
        .frame(minHeight: 44)
        #endif
    }
}

// MARK: - Information screens

private struct MethodologyView: View {
    var body: some View {
        InfoPage(title: "How we rate each day", paragraphs: [
            "Each day gets an intensity — Calm, Mild, Elevated or Intense — from the sky events that fall on it in your time zone.",
            "Mercury retrograde adds the most, and its turning days (when it appears to stop and change direction) add more. The days around a turning point, Mercury’s shadow periods, Venus or Mars retrograde, other planets changing direction, New and Full Moons, and Mercury moving into a new sign each add a little.",
            "The points add up: none is Calm, 1–2 Mild, 3–4 Elevated, 5 or more Intense. The same day always gets the same rating.",
            "It’s an astrology-inspired reflection score built from verified astronomical events — a prompt to slow down and plan kindly, not a prediction of what will happen.",
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
