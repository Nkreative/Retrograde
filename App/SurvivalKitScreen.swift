import DesignSystem
import Editorial
import Persistence
import RetroCore
import SurvivalKit
import SwiftUI

/// The Survival Kit tab: cycle and task progress, then the four sections. Free users see the
/// first task of each section unlocked, two locked previews, and the rest blurred.
struct SurvivalKitTab: View {
    var now: Date?
    @State private var path: [KitTask] = []

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.everyMinute) { context in
                SurvivalKitScreen(now: now ?? context.date)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: KitTask.self) { task in
                TimelineView(.everyMinute) { context in
                    TaskDetailScreen(task: task, now: now ?? context.date)
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        #if DEBUG
        .onAppear {
            // `-openTask <task id>` opens a task directly, for review screenshots.
            if path.isEmpty, let id = UserDefaults.standard.string(forKey: "openTask"),
               let task = SurvivalKit.for(.mercury)?.tasks.first(where: { $0.id == id }) {
                path = [task]
            }
        }
        #endif
    }
}

struct SurvivalKitScreen: View {
    let now: Date
    @Environment(CompletionStore.self) private var completions
    @Environment(PremiumAccess.self) private var premium

    private let kit = SurvivalKit.for(.mercury)!
    private let policy = TaskAccessPolicy.launch

    var body: some View {
        let cycleID = KitCycle.id(at: now)
        let done = completions.completedTaskIDs(in: cycleID)
        ScrollView {
            VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SMALL MOVES. YOU’LL GET IT DONE.")
                        .retroText(.cardTitle)
                        .foregroundStyle(RetroColor.text)
                        .accessibilityAddTraits(.isHeader)
                    Text("Main things you can control. The cosmos can wait.")
                        .retroText(.body)
                        .foregroundStyle(RetroColor.textMuted)
                }
                VStack(alignment: .leading, spacing: 16) {
                    KitProgress(status: SkyData.calculator?.status(of: .mercury, at: now), done: done.count, total: kit.tasks.count)
                    ForEach(kit.sections) { section in
                        SectionCard(section: section, done: done, isPremium: premium.isPremium, policy: policy)
                    }
                    if !premium.isPremium {
                        PremiumNudge(lockedCount: policy.lockedCount(in: kit, isPremium: false))
                    }
                }
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .retroScreenBackground()
    }
}

/// Which cycle's kit is current: the latest Mercury retrograde to have begun.
enum KitCycle {
    static func id(at date: Date) -> String {
        SkyData.calculator?.currentCycle(of: .mercury, at: date)?.id ?? "mercury-before-data"
    }
}

/// Cycle bar (pink) with its labels above, and kit bar (yellow) with its labels below.
private struct KitProgress: View {
    let status: CycleStatus?
    let done: Int
    let total: Int

    var body: some View {
        let copy = status.flatMap { OverviewCopy.for(.mercury, $0.stage) }
        let cycleLabel: String = {
            guard let status, copy?.dayLabel != nil else { return "YOU ARE HERE" }
            return "Day \(status.day) of \(status.totalDays)"
        }()
        let kitProgress = total == 0 ? 0 : Double(done) / Double(total)
        VStack(spacing: 7) {
            if let status, let copy {
                MarkerLabels(progress: status.progress, start: copy.barStart, current: cycleLabel, end: copy.barEnd, currentColor: RetroColor.textMuted, followsMarker: false)
                CycleProgressBar(progress: status.progress)
            }
            CycleProgressBar(progress: kitProgress, fill: RetroColor.yellow)
            MarkerLabels(progress: kitProgress, start: "CONFUSED", current: "\(done) of \(total) done", end: "SAFE", currentColor: RetroColor.yellow, followsMarker: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) tasks done this cycle")
    }
}

private struct SectionCard: View {
    let section: KitSection
    let done: Set<String>
    let isPremium: Bool
    let policy: TaskAccessPolicy

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                IconChip(systemImage: section.topic.symbol)
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.label).retroText(.monoSmall).foregroundStyle(RetroColor.pink)
                    Text(section.title).retroText(.cardTitle).foregroundStyle(RetroColor.text)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Text(section.guidance).retroText(.body).foregroundStyle(RetroColor.textMuted)
            ForEach(Array(section.tasks.enumerated()), id: \.element.id) { index, task in
                TaskRow(task: task, visibility: policy.visibility(ofTaskAt: index, isPremium: isPremium), isDone: done.contains(task.id))
            }
        }
        .retroCard()
    }
}

private struct TaskRow: View {
    let task: KitTask
    let visibility: TaskVisibility
    let isDone: Bool

    var body: some View {
        switch visibility {
        case .unlocked:
            NavigationLink(value: task) {
                row(checkbox: isDone ? .done : .open, textColor: isDone ? RetroColor.textMuted : RetroColor.text)
            }
            .buttonStyle(.plain)
            .accessibilityValue(isDone ? "Done" : "Not done")
            .accessibilityHint("Opens the task")
        case .preview:
            row(checkbox: .locked, textColor: RetroColor.text, textOpacity: 0.4)
                .accessibilityLabel("\(task.title) Premium task, locked")
        case .hidden:
            row(checkbox: .locked, textColor: RetroColor.text, textOpacity: 0.4)
                .blur(radius: 3)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Premium task, locked")
        }
    }

    private func row(checkbox: TaskCheckbox.State, textColor: Color, textOpacity: Double = 1) -> some View {
        HStack(spacing: 10) {
            TaskCheckbox(checkbox)
            Text(task.title)
                .retroText(.body)
                .foregroundStyle(textColor)
                .opacity(textOpacity)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// "23 more tasks in Premium" card under the sections (free users only). Opens the paywall in M9.
private struct PremiumNudge: View {
    let lockedCount: Int

    var body: some View {
        Button {
            // Paywall arrives in M9.
        } label: {
            HStack(spacing: 12) {
                IconChip(systemImage: RetroSymbol.unlock)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(lockedCount) more tasks in Premium").retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                    Text("Unlock the full kit and every calendar day.").retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: RetroSymbol.forward).font(.system(size: 14, weight: .semibold)).foregroundStyle(RetroColor.pink)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(RetroColor.wine, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.card).strokeBorder(RetroColor.pink.opacity(0.5), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

extension KitSection.Topic {
    var symbol: String {
        switch self {
        case .communication: RetroSymbol.communication
        case .techBackup: RetroSymbol.techBackup
        case .planning: RetroSymbol.planning
        // Figma uses the speech bubble here too (flagged for review).
        case .journal: RetroSymbol.communication
        }
    }
}
