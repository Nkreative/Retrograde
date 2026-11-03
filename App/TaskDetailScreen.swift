import DesignSystem
import Persistence
import SurvivalKit
import SwiftUI

/// Task screen. M5 provides the frame and "Mark as done"; the guided experiences
/// (timers, checklists, copyable messages, journal prompts) arrive in M6.
struct TaskDetailScreen: View {
    let task: KitTask
    let now: Date
    @Environment(CompletionStore.self) private var completions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let cycleID = KitCycle.id(at: now)
        let isDone = completions.isDone(task.id, in: cycleID)
        let section = SurvivalKit.for(.mercury)?.sections.first { $0.tasks.contains(task) }
        ScrollView {
            VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
                Button { dismiss() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: RetroSymbol.back).font(.system(size: 13, weight: .medium))
                        Text("Survival kit").retroText(.body)
                    }
                    .foregroundStyle(RetroColor.textMuted)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    if let section {
                        Text(section.label).retroText(.monoSmall).foregroundStyle(RetroColor.pink)
                    }
                    Text(task.title.trimmingCharacters(in: CharacterSet(charactersIn: ".")).uppercased())
                        .retroText(.cardTitle)
                        .foregroundStyle(RetroColor.text)
                        .accessibilityAddTraits(.isHeader)
                }

                Text("The guided version of this task arrives in M6.")
                    .retroText(.mono)
                    .foregroundStyle(RetroColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: RetroMetrics.Radius.card)
                            .strokeBorder(RetroColor.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )

                VStack(spacing: 14) {
                    if isDone {
                        PrimaryButton("Done for this cycle", systemImage: RetroSymbol.checkCircle, style: .completed) {}
                            .allowsHitTesting(false)
                        Button("Mark as not done") { completions.markNotDone(task.id, in: cycleID) }
                            .retroText(.bodyStrong)
                            .foregroundStyle(RetroColor.textMuted)
                    } else {
                        PrimaryButton("Mark as done", systemImage: RetroSymbol.checkCircle) {
                            completions.markDone(task.id, in: cycleID)
                            dismiss()
                        }
                    }
                }

                Text("Astrology is a reflection prompt, not a prediction.\nThese good habits work in any orbit.")
                    .retroText(.finePrint)
                    .foregroundStyle(RetroColor.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        .retroScreenBackground()
    }
}
