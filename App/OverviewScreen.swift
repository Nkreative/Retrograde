import DesignSystem
import Editorial
import RetroCore
import SwiftUI

/// Mercury dashboard: countdown and progress for the current cycle stage, then what it means
/// and three practical tips. Everything date-related comes from the verified ephemeris.
struct OverviewScreen: View {
    /// Debug-only clock override for reviewing other cycle stages; nil uses the real time.
    var now: Date?
    var onOpenSurvivalKit: () -> Void = {}
    var onAddToHomeScreen: () -> Void = {}

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = now ?? context.date
            ScrollView {
                if let status = SkyData.calculator?.status(of: .mercury, at: date),
                   let copy = OverviewCopy.for(.mercury, status.stage) {
                    content(status, copy)
                } else {
                    MissingSkyData()
                }
            }
        }
    }

    private func content(_ status: CycleStatus, _ copy: OverviewCopy) -> some View {
        // Progress group, then the headline + artwork group close beneath it (tightened ~50 pt
        // after review so the hero reads as part of the same story).
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                CountdownRow(status: status, copy: copy)
                LabeledProgress(progress: status.progress, start: copy.barStart, current: "YOU ARE HERE", end: copy.barEnd)
                HStack {
                    Spacer()
                    PillButton("ADD TO HOME SCREEN", systemImage: RetroSymbol.add, action: onAddToHomeScreen)
                }
                .padding(.top, -6) // sits just under the bar labels
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
                HeroCard(headline: copy.heroHeadline)
                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.sectionTitle)
                        .retroText(.section)
                        .foregroundStyle(RetroColor.text)
                        .accessibilityAddTraits(.isHeader)
                    (Text(status.planet.displayName).font(RetroTextStyle.bodyHeavy.font)
                        + Text(" " + copy.explanation).font(RetroTextStyle.body.font))
                        .lineSpacing(2)
                        .foregroundStyle(RetroColor.textMuted)
                }
                VStack(alignment: .leading, spacing: 13) {
                    ForEach(copy.tips, id: \.title) { TipRow(tip: $0) }
                }
                PrimaryButton(copy.callToAction, systemImage: RetroSymbol.firstAid, layout: .leading, showsArrow: true, action: onOpenSurvivalKit)
            }
            .padding(.bottom, 18)
        }
        .padding(.horizontal, RetroMetrics.screenPadding)
    }
}

/// "10 days to exhale ······ DAY 12 / 22", or "TODAY Mercury turns direct" on the day itself.
private struct CountdownRow: View {
    let status: CycleStatus
    let copy: OverviewCopy

    var body: some View {
        let days = status.daysUntilTarget
        let unit = days == 0 ? copy.countdownToday : copy.countdownUnit(for: days)
        let dayLabel = copy.dayLabel(day: status.day, of: status.totalDays)
        let countdown = HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(days == 0 ? "TODAY" : "\(days)")
                .retroText(.display)
                .foregroundStyle(RetroColor.yellow)
            Text(unit)
                .retroText(.monoLarge)
                .foregroundStyle(RetroColor.text)
        }
        Group {
            if let dayLabel {
                let day = Text(dayLabel)
                    .retroText(.mono)
                    .foregroundStyle(RetroColor.textMuted)
                // Figma's single row where it fits; on narrow phones or large text the day label drops below.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        countdown
                        Spacer(minLength: 12)
                        day
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        countdown
                        day
                    }
                }
            } else {
                countdown.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(days == 0 ? "Today, \(unit)" : "\(days) \(unit)")
        .accessibilityValue(dayLabel?.capitalized ?? "")
    }
}

/// The approved "cosmic chaos" artwork, shown whole at its 2:1 proportions (so the girl, the
/// tangled orbits and every icon stay in frame). The stage headline is live text in a dark band
/// that blends into the artwork's night sky, overlapping only the empty top edge.
private struct HeroCard: View {
    let headline: String
    /// Height of the dark band above the artwork; the headline dips just into the sky below it.
    @ScaledMetric(relativeTo: .title) private var band: CGFloat = 60

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: band)
            Image("OverviewHero")
                .resizable()
                .aspectRatio(2, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) {
                    // The artwork's top rows are already near the background colour; this removes the seam.
                    LinearGradient(colors: [RetroColor.background, RetroColor.background.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 24)
                }
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topLeading) {
            Text(headline)
                .retroText(.hero)
                .foregroundStyle(RetroColor.text)
                .shadow(color: .black.opacity(0.5), radius: 8)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

private struct TipRow: View {
    let tip: OverviewCopy.Tip

    var body: some View {
        HStack(spacing: 12) {
            IconChip(systemImage: tip.topic.symbol)
            VStack(alignment: .leading, spacing: 3) {
                Text(tip.title).retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                Text(tip.action).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shown if the date is outside the bundled data (it covers 2025–2030).
private struct MissingSkyData: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WE’RE STILL MAPPING THIS STRETCH OF SKY.")
                .retroText(.cardTitle)
                .foregroundStyle(RetroColor.text)
            Text("Retrograde only shows verified dates. Update the app to see the latest cycles.")
                .retroText(.body)
                .foregroundStyle(RetroColor.textMuted)
        }
        .retroCard()
        .padding(.horizontal, RetroMetrics.screenPadding)
        .padding(.top, 6)
    }
}

private extension OverviewCopy.Topic {
    var symbol: String {
        switch self {
        case .communication: RetroSymbol.communication
        case .techBackup: RetroSymbol.techBackup
        case .planning: RetroSymbol.planning
        }
    }
}

extension Planet {
    var displayName: String { rawValue.capitalized }
}

#Preview {
    OverviewScreen().onAppear(perform: RetroFonts.register).retroScreenBackground()
}
