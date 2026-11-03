import DesignSystem
import Observation
import SwiftUI

/// Opens the Premium paywall from anywhere (locked tasks, the Premium card, later locked calendar days).
@MainActor
@Observable
final class PaywallPresenter {
    var isPresented = false

    func present() { isPresented = true }
}

/// The approved paywall layout (Lifetime selected by default, Yearly alternative).
/// Until StoreKit arrives in M9 this is a preview: plans can be chosen but nothing is bought.
struct PaywallView: View {
    enum Plan { case lifetime, yearly }

    @Environment(\.dismiss) private var dismiss
    @State private var plan: Plan = .lifetime

    var body: some View {
        // Sized so the plans and the purchase button fit on the first screen: the artwork window
        // and spacing tighten as screens get shorter (e.g. iPhone 17e); the rest scrolls.
        GeometryReader { screen in
            let roomy = screen.size.height + screen.safeAreaInsets.top + screen.safeAreaInsets.bottom >= 920
            content(heroRatio: roomy ? 0.86 : 0.78, headlineOverlap: roomy ? 56 : 44, spacing: roomy ? 16 : 13, benefitSpacing: roomy ? 11 : 9)
        }
    }

    private func content(heroRatio: CGFloat, headlineOverlap: CGFloat, spacing: CGFloat, benefitSpacing: CGFloat) -> some View {
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
                        benefit(RetroSymbol.moon, "The full sky behind each day", "Retrogrades, shadows and moon phases, explained.")
                        benefit(RetroSymbol.heart, "No ads. No account. Ever.", "Your progress stays on your phone.")
                    }

                    VStack(spacing: 10) {
                        planCard(.lifetime, "Lifetime access", "One-time purchase. No renewal.", price: "$—.—", badge: "BEST VALUE")
                        planCard(.yearly, "Yearly", "[Intro offer] then billed yearly", price: "$—.— / yr", badge: nil)
                    }

                    VStack(spacing: 6) {
                        PrimaryButton(plan == .lifetime ? "Get lifetime access" : "Start Premium") {}
                            .disabled(true)
                            .opacity(0.55)
                        Text("Preview — purchases connect in the next milestone.")
                            .retroText(.finePrint)
                            .foregroundStyle(RetroColor.textMuted)
                    }
                    Button("Continue free") { dismiss() }
                        .retroText(.bodyStrong)
                        .foregroundStyle(RetroColor.text)
                        .frame(maxWidth: .infinity, minHeight: 44)

                    VStack(spacing: 8) {
                        Text("RESTORE PURCHASES  ·  TERMS  ·  PRIVACY").retroText(.monoSmall)
                        Text("Yearly access auto-renews until cancelled. Lifetime access is a one-time purchase. Cancel Yearly anytime in Settings › Apple Account › Subscriptions.")
                            .retroText(.finePrint)
                            .multilineTextAlignment(.center)
                    }
                    .foregroundStyle(RetroColor.textMuted)
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, RetroMetrics.screenPadding)
                .padding(.top, -headlineOverlap) // the headline sits on the artwork's faded edge
                .padding(.bottom, 24)
            }
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

    private func planCard(_ option: Plan, _ name: String, _ detail: String, price: String, badge: String?) -> some View {
        let selected = plan == option
        return Button { plan = option } label: {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(selected ? RetroColor.pink : RetroColor.textMuted, lineWidth: selected ? 6 : 1.5)
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(name).retroText(.button).foregroundStyle(RetroColor.text)
                        if let badge { Badge(badge) }
                    }
                    Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                Spacer(minLength: 8)
                Text(price).font(RetroTextStyle.monoBold.font).foregroundStyle(RetroColor.text)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(selected ? RetroColor.wine : RetroColor.surface, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.card).strokeBorder(selected ? RetroColor.pink : RetroColor.line, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
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
