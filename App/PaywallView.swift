import DesignSystem
import Entitlements
import Observation
import SwiftUI

/// Opens the Premium paywall from anywhere (locked tasks, the Premium card, locked calendar days).
@MainActor
@Observable
final class PaywallPresenter {
    var isPresented = false

    func present() { isPresented = true }

    #if DEBUG
    /// The live presenter, for the screenshot tour in RetrogradeTests.
    static weak var current: PaywallPresenter?
    #endif
}

/// The approved paywall: artwork, benefits, Lifetime (default, BEST VALUE) and Yearly with live
/// StoreKit prices, the purchase button for the selected plan with its terms, Continue free,
/// Restore, Terms and Privacy. Purchase logic lives in `PurchaseFlow`.
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementStore.self) private var entitlements
    @State private var flow: PurchaseFlow?

    var body: some View {
        // Sized so the plans and the purchase button fit on the first screen: the artwork window
        // and spacing tighten as screens get shorter (e.g. iPhone 17e); the rest scrolls.
        GeometryReader { screen in
            let roomy = screen.size.height + screen.safeAreaInsets.top + screen.safeAreaInsets.bottom >= 920
            content(heroRatio: roomy ? 0.86 : 0.78, headlineOverlap: roomy ? 56 : 44, spacing: roomy ? 16 : 13, benefitSpacing: roomy ? 11 : 9)
        }
        .task {
            let flow = self.flow ?? PurchaseFlow(store: entitlements)
            self.flow = flow
            #if DEBUG
            PaywallDebug.flow = flow
            #endif
            await flow.load()
        }
        // Premium arrived (purchase, approval of a pending purchase, restore): close.
        .onChange(of: entitlements.isPremium) { _, isPremium in
            if isPremium { dismiss() }
        }
        .onChange(of: flow?.phase) { _, phase in
            if let message = phase.flatMap(StatusBanner.message) {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }

    private func content(heroRatio: CGFloat, headlineOverlap: CGFloat, spacing: CGFloat, benefitSpacing: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    PaywallHero(windowRatio: heroRatio)
                    VStack(alignment: .leading, spacing: spacing) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RETROGRADE PREMIUM").retroText(.mono).foregroundStyle(RetroColor.pink)
                            Text("FULL BACKUP,\nEVERY CYCLE.").retroText(.hero).foregroundStyle(RetroColor.text).accessibilityAddTraits(.isHeader)
                        }
                        Text("The whole Survival Kit and every day of the calendar. Same cosmos, a lot more backup.")
                            .retroText(.bodyLarge).foregroundStyle(RetroColor.textMuted)

                        VStack(alignment: .leading, spacing: benefitSpacing) {
                            benefit(RetroSymbol.firstAid, "All 27 Survival Kit tasks", "Not just the first one in each section.")
                            benefit(RetroSymbol.planning, "Every calendar day, in detail", "Plan past the next four days — weeks ahead.")
                            benefit(RetroSymbol.moon, "The cosmic details behind each day", "Retrogrades, shadows and moon phases, explained.")
                            benefit(RetroSymbol.heart, "No ads. No account needed.", "Your progress stays on your phone.")
                        }

                        PlanList(flow: flow)
                        if let message = flow.flatMap({ StatusBanner.message(for: $0.phase) }) {
                            StatusBanner(phase: flow!.phase, message: message)
                        }
                        PurchaseButton(flow: flow) { await buy() }

                        Button("Continue free") { dismiss() }
                            .retroText(.bodyStrong)
                            .foregroundStyle(RetroColor.text)
                            .frame(maxWidth: .infinity, minHeight: 44)

                        LegalRow(flow: flow) { await restore() }
                            .id(Self.bottomID)
                    }
                    .padding(.horizontal, RetroMetrics.screenPadding)
                    .padding(.top, -headlineOverlap) // the headline sits on the artwork's faded edge
                    .padding(.bottom, 24)
                }
            }
            #if DEBUG
            .onAppear {
                PaywallDebug.scrollToBottom = { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                // `-scrollPaywall bottom` scrolls to the plans and links, for review screenshots.
                if UserDefaults.standard.string(forKey: "scrollPaywall") == "bottom" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                }
            }
            #endif
        }
        .ignoresSafeArea(edges: .top)
        .retroScreenBackground()
        // Pinned so it's always reachable, even after scrolling past the artwork.
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: RetroSymbol.close)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RetroColor.text)
                    .frame(width: 36, height: 36)
                    .background(RetroColor.background.opacity(0.7), in: Circle())
                    .overlay(Circle().strokeBorder(RetroColor.line, lineWidth: 1))
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .padding(.trailing, RetroMetrics.screenPadding - 4)
            .padding(.top, 4)
        }
    }

    private static let bottomID = "paywall-bottom"

    private func buy() async {
        guard let flow, await flow.purchase() else { return }
        dismiss()
    }

    private func restore() async {
        guard let flow, await flow.restore() else { return }
        dismiss()
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(spacing: 12) {
            IconChip(systemImage: icon)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
/// Hooks for the screenshot tour (RetrogradeTests); not compiled into release builds.
@MainActor
enum PaywallDebug {
    static weak var flow: PurchaseFlow?
    static var scrollToBottom: (() -> Void)?
}
#endif

/// Lifetime and Yearly cards with live prices; placeholders while loading; a retry when unavailable.
private struct PlanList: View {
    let flow: PurchaseFlow?

    var body: some View {
        let phase = flow?.phase ?? .loading
        VStack(spacing: 10) {
            switch phase {
            case .loading:
                ForEach(PremiumPlan.paywallOrder, id: \.self) { plan in
                    PlanCard(plan: plan, offer: nil, selected: plan == .lifetime, enabled: false) {}
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading prices")
            case .unavailable:
                Unavailable { Task { await flow?.load() } }
            default:
                if let flow {
                    ForEach(PremiumPlan.paywallOrder, id: \.self) { plan in
                        PlanCard(plan: plan, offer: flow.offers[plan], selected: flow.selectedPlan == plan, enabled: !flow.isBusy && flow.offers[plan] != nil) {
                            flow.select(plan)
                        }
                    }
                }
            }
        }
    }
}

private struct PlanCard: View {
    let plan: PremiumPlan
    let offer: PlanOffer?
    let selected: Bool
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        let bestValue = plan == .lifetime
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(selected ? RetroColor.pink : RetroColor.textMuted, lineWidth: selected ? 6 : 1.5)
                    .frame(width: 20, height: 20)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { labels(bestValue: bestValue); Spacer(minLength: 8); price }
                    VStack(alignment: .leading, spacing: 6) {
                        labels(bestValue: bestValue)
                        price.frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? RetroColor.wine : RetroColor.surface, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.card).strokeBorder(selected ? RetroColor.pink : RetroColor.line, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(offer.map { PaywallCopy.accessibilityLabel($0, bestValue: bestValue) } ?? "\(PaywallCopy.planName(plan)), unavailable")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private func labels(bestValue: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            let name = Text(PaywallCopy.planName(plan)).retroText(.button).foregroundStyle(RetroColor.text)
            // Badge beside the name where it fits; below it at large text sizes, never truncating the name.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    name.fixedSize()
                    if bestValue { Badge("BEST VALUE").fixedSize() }
                }
                VStack(alignment: .leading, spacing: 4) {
                    name
                    if bestValue { Badge("BEST VALUE").fixedSize() }
                }
            }
            Text(offer.map(PaywallCopy.planDetail) ?? "Loading price…")
                .retroText(.body)
                .foregroundStyle(RetroColor.textMuted)
                .redacted(reason: offer == nil ? .placeholder : [])
        }
    }

    /// Price large and right-aligned; the frequency ("/ yr") smaller underneath it. Never truncated:
    /// longer localized prices push the card to the stacked layout instead.
    @ViewBuilder private var price: some View {
        if let offer {
            VStack(alignment: .trailing, spacing: 1) {
                Text(offer.displayPrice).retroText(.price).foregroundStyle(RetroColor.text)
                if let unit = PaywallCopy.priceUnit(offer) {
                    Text(unit).retroText(.monoSmall).foregroundStyle(RetroColor.textMuted)
                }
            }
            .lineLimit(1)
            .fixedSize()
        } else {
            ProgressView().tint(RetroColor.textMuted)
        }
    }
}

private struct Unavailable: View {
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prices aren’t available right now").retroText(.bodyStrong).foregroundStyle(RetroColor.text)
            Text("We couldn’t reach the App Store. Check your connection and try again — nothing has been charged.")
                .retroText(.body).foregroundStyle(RetroColor.textMuted)
            SecondaryButton("Try again", systemImage: RetroSymbol.restart, action: retry)
        }
        .retroCard()
    }
}

/// Pending approval, failed purchase or restore, nothing to restore.
private struct StatusBanner: View {
    let phase: PurchaseFlow.Phase
    let message: String

    static func message(for phase: PurchaseFlow.Phase) -> String? {
        switch phase {
        case .pending: "Waiting for approval. Premium unlocks automatically as soon as it’s approved."
        case .purchaseFailed: "The purchase didn’t go through and you haven’t been charged. Please try again."
        case .restoreFailed: "Couldn’t reach the App Store to restore. Check your connection and try again."
        case .nothingToRestore: "No Premium purchase was found for this Apple Account."
        default: nil
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: phase == .pending ? "hourglass" : "exclamationmark.circle")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(phase == .pending ? RetroColor.yellow : RetroColor.pink)
            Text(message).retroText(.body).foregroundStyle(RetroColor.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(RetroColor.surface, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.button))
        .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.button).strokeBorder(RetroColor.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// The purchase button for the selected plan, with that plan's terms underneath.
private struct PurchaseButton: View {
    let flow: PurchaseFlow?
    let action: () async -> Void

    var body: some View {
        let purchasing: Bool = if case .purchasing = flow?.phase { true } else { false }
        let enabled = flow?.canPurchase ?? false
        let plan = flow?.selectedPlan ?? .lifetime
        VStack(spacing: 8) {
            PrimaryButton(purchasing ? "Processing…" : PaywallCopy.buttonTitle(plan, offer: flow?.selectedOffer)) {
                Task { await action() }
            }
            .overlay(alignment: .leading) {
                if purchasing { ProgressView().tint(RetroColor.text).padding(.leading, 20) }
            }
            .disabled(!enabled)
            .opacity(enabled || purchasing ? 1 : 0.55)
            .accessibilityHint(purchasing ? "Processing your purchase" : "")
            if let offer = flow?.selectedOffer, flow?.phase != .unavailable {
                Text(PaywallCopy.disclosure(offer))
                    .retroText(.disclosure)
                    .foregroundStyle(RetroColor.text.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

/// Restore Purchases · Terms · Privacy (Privacy appears once its URL is configured).
private struct LegalRow: View {
    let flow: PurchaseFlow?
    let restore: () async -> Void

    var body: some View {
        let restoring = flow?.phase == .restoring
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { links(restoring: restoring, separator: true) }
            VStack(spacing: 8) { links(restoring: restoring, separator: false) }
        }
        .retroText(.monoSmall)
        .foregroundStyle(RetroColor.textMuted)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func links(restoring: Bool, separator: Bool) -> some View {
        Button(restoring ? "RESTORING…" : "RESTORE PURCHASES") { Task { await restore() } }
            .disabled(flow?.isBusy ?? true)
            .frame(minHeight: 44)
        if separator { Text("·").accessibilityHidden(true) }
        Link("TERMS", destination: AppLinks.termsOfUse).frame(minHeight: 44)
        if let privacy = AppLinks.privacyPolicy {
            if separator { Text("·").accessibilityHidden(true) }
            Link("PRIVACY", destination: privacy).frame(minHeight: 44)
        } else {
            #if DEBUG
            if separator { Text("·").accessibilityHidden(true) }
            Text("PRIVACY (URL NOT SET)").foregroundStyle(RetroColor.pink).frame(minHeight: 44)
            #endif
        }
    }
}

/// The approved Premium artwork, edge to edge: the whole moon, the girl and the icons stay in
/// view below the status bar; the empty foreground is cropped and both edges fade into the app
/// background. Scales with the screen width, so proportions hold on every iPhone.
private struct PaywallHero: View {
    /// Artwork is 1199 × 1312 px.
    private static let aspect: CGFloat = 1312 / 1199
    /// The artwork starts this far down (as a fraction of its height), clearing the status bar;
    /// the gap above is the same deep purple as the artwork's sky.
    private static let topInset: CGFloat = 0.05
    /// Visible height as a fraction of width. Even the shorter window (0.78) keeps the moon,
    /// the girl and all three icons clear of the fade; the taller one shows more of the grid.
    let windowRatio: CGFloat

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(1 / windowRatio, contentMode: .fit)
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    let height = geo.size.width * Self.aspect
                    Image("PaywallHero")
                        .resizable()
                        .frame(width: geo.size.width, height: height)
                        .offset(y: height * Self.topInset)
                        .overlay(alignment: .top) {
                            // Soften the artwork's top edge into the background.
                            LinearGradient(colors: [RetroColor.background, RetroColor.background.opacity(0)], startPoint: .top, endPoint: .bottom)
                                .frame(height: height * Self.topInset + 40)
                        }
                }
            }
            .overlay(alignment: .bottom) {
                // Fade the bottom 38 % into the background so the artwork has no hard edge.
                GeometryReader { geo in
                    LinearGradient(
                        stops: [.init(color: RetroColor.background.opacity(0), location: 0), .init(color: RetroColor.background, location: 1)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: geo.size.height * 0.38)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}

#Preview {
    PaywallView().onAppear(perform: RetroFonts.register)
}
