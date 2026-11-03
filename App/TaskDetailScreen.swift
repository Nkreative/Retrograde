import DesignSystem
import Persistence
import SurvivalKit
import SwiftUI
import UIKit

/// A Survival Kit task: what to do, the guided practice, and Mark as done.
/// A finished task can be reopened and marked not done.
struct TaskDetailScreen: View {
    let task: KitTask
    let now: Date
    @Environment(CompletionStore.self) private var completions
    @Environment(\.dismiss) private var dismiss
    @State private var copiedAt: Date?

    private let kit = SurvivalKit.for(.mercury)!

    var body: some View {
        let cycleID = KitCycle.id(at: now)
        let isDone = completions.isDone(task.id, in: cycleID)
        let section = kit.sections.first { $0.tasks.contains(task) }
        let guide = kit.guide(for: task)
        ScrollView {
            VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
                Button { dismiss() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: RetroSymbol.back).font(.system(size: 13, weight: .medium))
                        Text("Survival kit").retroText(.body)
                    }
                    .foregroundStyle(RetroColor.textMuted)
                    .frame(minHeight: 32)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    if let section {
                        Text(section.label).retroText(.monoSmall).foregroundStyle(RetroColor.pink)
                    }
                    Text(guide?.title ?? task.title.uppercased())
                        .retroText(.cardTitle)
                        .foregroundStyle(RetroColor.text)
                        .accessibilityAddTraits(.isHeader)
                    if let guide {
                        Text(guide.instruction).retroText(.bodyLarge).foregroundStyle(RetroColor.textMuted)
                    }
                }

                if let guide {
                    PracticeCard(guide: guide, onCopy: copy)
                    if case let .reflection(_, prompt, _) = guide.practice {
                        WriteElsewhere(prompt: prompt, onCopy: copy)
                    }
                }

                VStack(spacing: 14) {
                    if isDone {
                        PrimaryButton("Done for this cycle", systemImage: RetroSymbol.checkCircle, style: .completed) {}
                            .allowsHitTesting(false)
                        Button("Mark as not done") { completions.markNotDone(task.id, in: cycleID) }
                            .retroText(.bodyStrong)
                            .foregroundStyle(RetroColor.textMuted)
                            .frame(minHeight: 44)
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
        .overlay(alignment: .bottom) { CopiedToast(copiedAt: $copiedAt) }
        .sensoryFeedback(.success, trigger: copiedAt) { _, new in new != nil }
    }

    private func copy(_ text: String) {
        UIPasteboard.general.string = text
        copiedAt = .now
        AccessibilityNotification.Announcement("Copied").post()
    }
}

/// Journal tasks: copy the prompt or open the iOS share sheet to write it in Notes, WhatsApp, etc.
/// Nothing the person writes ever comes back into Retrograde.
private struct WriteElsewhere: View {
    let prompt: String
    let onCopy: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { buttons }
                VStack(spacing: 10) { buttons }
            }
            HStack(spacing: 6) {
                Image(systemName: RetroSymbol.lock).font(.system(size: 9))
                Text("Your words stay in your own app. Retrograde never sees them.").retroText(.finePrint)
            }
            .foregroundStyle(RetroColor.textMuted)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var buttons: some View {
        SecondaryButton("Copy prompt", systemImage: RetroSymbol.copy) { onCopy(prompt) }
        ShareLink(item: prompt) {
            SecondaryButtonLabel("Open in…", systemImage: RetroSymbol.share)
        }
        .buttonStyle(.plain)
    }
}

/// Brief "Copied" confirmation at the bottom of the screen.
private struct CopiedToast: View {
    @Binding var copiedAt: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if copiedAt != nil {
                Label("Copied", systemImage: RetroSymbol.check)
                    .retroText(.bodyStrong)
                    .foregroundStyle(RetroColor.background)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(RetroColor.text, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityHidden(true) // announced separately
            }
        }
        .animation(.easeOut(duration: 0.2), value: copiedAt)
        .task(id: copiedAt) {
            guard copiedAt != nil else { return }
            try? await Task.sleep(for: .seconds(1.6))
            copiedAt = nil
        }
    }
}
