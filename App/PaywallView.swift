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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("RETROGRADE PREMIUM").retroText(.mono).foregroundStyle(RetroColor.pink)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: RetroSymbol.close)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(RetroColor.text)
                            .frame(width: 36, height: 36)
                            .overlay(Circle().strokeBorder(RetroColor.line, lineWidth: 1))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                Image("OverviewHero")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(382 / 120, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: RetroMetrics.Radius.card))
                    .accessibilityHidden(true)

                Text("FULL BACKUP,\nEVERY CYCLE.").retroText(.hero).foregroundStyle(RetroColor.text).accessibilityAddTraits(.isHeader)
                Text("The whole Survival Kit and every day of the calendar. Same cosmos, a lot more backup.")
                    .retroText(.bodyLarge).foregroundStyle(RetroColor.textMuted)

                VStack(alignment: .leading, spacing: 12) {
                    benefit(RetroSymbol.firstAid, "All 27 Survival Kit tasks", "Not just the first one in each section.")
                    benefit(RetroSymbol.planning, "Every calendar day, in detail", "Plan past the next four days — weeks ahead.")
                    benefit(RetroSymbol.moon, "The full sky behind each day", "Retrogrades, shadows and moon phases, explained.")
                    benefit(RetroSymbol.heart, "No ads. No account. Ever.", "Your progress stays on your phone.")
                }

                VStack(spacing: 10) {
                    planCard(.lifetime, "Lifetime access", "One-time purchase. No renewal.", price: "$—.—", badge: "BEST VALUE")
                    planCard(.yearly, "Yearly", "[Intro offer] then billed yearly", price: "$—.— / yr", badge: nil)
                }
                .padding(.top, 4)

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
            .padding(.vertical, 12)
        }
        .retroScreenBackground()
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

#Preview {
    PaywallView().onAppear(perform: RetroFonts.register)
}
