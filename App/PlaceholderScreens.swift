import AstroData
import DesignSystem
import RetroCore
import SwiftUI

/// Temporary tab content until each screen's milestone; uses the real type and spacing.
struct PlaceholderScreen: View {
    let title: String
    let detail: String
    let milestone: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).retroText(.section).foregroundStyle(RetroColor.text)
                    Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                MilestoneNote(text: milestone)
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.top, 16)
        }
    }
}

/// Overview placeholder: the live countdown from verified data, styled with the design system.
struct OverviewPlaceholder: View {
    private let calculator = (try? BundledEphemeris.load()).map { CycleCalculator(ephemeris: $0) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
                TimelineView(.everyMinute) { context in
                    if let status = calculator?.status(of: .mercury, at: context.date) {
                        countdown(status)
                    } else {
                        Text("Sky data unavailable for this date.").retroText(.body).foregroundStyle(RetroColor.textMuted)
                    }
                }
                MilestoneNote(text: "The rest of Overview arrives in M4.")
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.top, 6)
        }
    }

    private func countdown(_ status: CycleStatus) -> some View {
        let retrograde = status.phase == .retrograde
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(status.daysRemaining)").retroText(.display).foregroundStyle(RetroColor.yellow)
                    Text(retrograde ? "days to exhale" : "days till the next plot twist")
                        .retroText(.monoLarge).foregroundStyle(RetroColor.text)
                }
                Spacer()
                Text(retrograde ? "DAY \(status.day) / \(status.totalDays)" : "DIRECT · DAY \(status.day)")
                    .retroText(.mono).foregroundStyle(RetroColor.textMuted)
            }
            LabeledProgress(
                progress: status.progress,
                start: retrograde ? "RETROGRADE" : "DIRECT",
                current: "YOU ARE HERE",
                end: retrograde ? "DIRECT" : "NEXT RX"
            )
        }
    }
}

struct MilestoneNote: View {
    let text: String

    var body: some View {
        Text(text)
            .retroText(.mono)
            .foregroundStyle(RetroColor.textMuted)
            .frame(maxWidth: .infinity, minHeight: 120)
            .overlay(
                RoundedRectangle(cornerRadius: RetroMetrics.Radius.card)
                    .strokeBorder(RetroColor.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            )
    }
}
