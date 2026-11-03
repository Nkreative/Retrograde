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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                CountdownRow(status: status, copy: copy)
                LabeledProgress(progress: status.progress, start: copy.barStart, current: "YOU ARE HERE", end: copy.barEnd)
                HStack {
                    Spacer()
                    PillButton("ADD TO HOME SCREEN", systemImage: RetroSymbol.add, action: onAddToHomeScreen)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 20)

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
            .padding(.top, 4)
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

/// Synthwave artwork from Figma with the stage headline on top.
private struct HeroCard: View {
    let headline: String

    var body: some View {
        Image("OverviewHero")
            .resizable()
            .scaledToFill()
            .accessibilityHidden(true)
            .frame(maxWidth: .infinity)
            .aspectRatio(382 / 147, contentMode: .fit)
            .clipped()
            .overlay(alignment: .topLeading) {
                Text(headline)
                    .retroText(.hero)
                    .foregroundStyle(RetroColor.text)
                    .shadow(color: .black.opacity(0.35), radius: 6)
                    .padding(24)
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
