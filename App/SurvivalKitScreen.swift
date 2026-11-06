import DesignSystem
import Editorial
import Entitlements
import Persistence
import RetroCore
import SurvivalKit
import SwiftUI

/// The Survival Kit tab: cycle and task progress, then the four sections. Free users see the
/// first task of each section unlocked, two locked previews, and the rest blurred.
struct SurvivalKitTab: View {
    var now: Date?
    @State private var path: [KitTask] = []
    @Environment(AppRouter.self) private var router

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
        // Back to the list when a notification points at a section.
        .onChange(of: router.kitFocus) { _, id in if id != nil { path = [] } }
        // The Overview asked for a task: show it over the list.
        .onChange(of: router.kitTask) { _, task in
            guard let task else { return }
            path = [task]
            router.kitTask = nil
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
    @Environment(EntitlementStore.self) private var premium
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Sections the person has expanded; all start collapsed.
    @State private var expanded: Set<String> = Self.initiallyExpanded

    private let kit = SurvivalKit.for(.mercury)!
    private let policy = TaskAccessPolicy.launch

    var body: some View {
        let cycleID = KitCycle.id(at: now)
        let done = completions.completedTaskIDs(in: cycleID)
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SMALL MOVES. YOU’LL GET IT DONE.")
                            .retroText(.cardTitle)
                            .foregroundStyle(RetroColor.text)
                            .accessibilityAddTraits(.isHeader)
                        Text(KitCopy.introduction(planet: kit.planet, taskCount: kit.tasks.count))
                            .retroText(.body)
                            .foregroundStyle(RetroColor.textMuted)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        KitProgress(status: SkyData.calculator?.status(of: .mercury, at: now), done: done.count, total: kit.tasks.count)
                        ForEach(kit.sections) { section in
                            SectionCard(
                                section: section, done: done, isPremium: premium.isPremium, policy: policy,
                                isExpanded: expanded.contains(section.id),
                                onToggle: { toggle(section.id) },
                                onLocked: paywall.present
                            )
                            .id(section.id)
                        }
                        if !premium.isPremium {
                            PremiumNudge(lockedCount: policy.lockedCount(in: kit, isPremium: false), action: paywall.present)
                        }
                    }
                }
                .padding(.horizontal, RetroMetrics.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .id(Self.contentID)
            }
            // A tapped notification asked for a section: expand it and scroll to it.
            .onChange(of: router.kitFocus) { _, id in
                guard let id else { return }
                expanded.insert(id)
                withAnimation(reduceMotion ? nil : .easeInOut) { proxy.scrollTo(id, anchor: .top) }
                router.kitFocus = nil
            }
            #if DEBUG
            .onAppear {
                // `-scrollKit bottom` opens the kit scrolled to the end, for review screenshots.
                if UserDefaults.standard.string(forKey: "scrollKit") == "bottom" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { proxy.scrollTo(Self.contentID, anchor: .bottom) }
                }
            }
            #endif
        }
        .retroScreenBackground()
    }

    private static let contentID = "kit-content"

    private func toggle(_ id: String) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        }
    }

    private static var initiallyExpanded: Set<String> {
        #if DEBUG
        // `-expandSections communication,journal` (or `all`) for review screenshots.
        if let list = UserDefaults.standard.string(forKey: "expandSections") {
            return list == "all" ? Set(SurvivalKit.for(.mercury)!.sections.map(\.id)) : Set(list.split(separator: ",").map(String.init))
        }
        #endif
        return []
    }
}

/// Which cycle's kit is current: the latest Mercury retrograde to have begun.
enum KitCycle {
    static func id(at date: Date) -> String {
        SkyData.calculator?.currentCycle(of: .mercury, at: date)?.id ?? "mercury-before-data"
    }
}

/// Cycle progress (pink) and kit progress (green).
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
        // Two separate groups, each bar with its labels underneath, coloured to match:
        // pink for where Mercury is, green for how much of the kit is done.
        VStack(spacing: 18) {
            if let status, let copy {
                VStack(spacing: 7) {
                    CycleProgressBar(progress: status.progress, markerSize: 9)
                    MarkerLabels(progress: status.progress, start: copy.barStart, current: cycleLabel, end: copy.barEnd, currentColor: RetroColor.pink, followsMarker: false)
                }
            }
            VStack(spacing: 7) {
                CycleProgressBar(progress: kitProgress, fill: RetroColor.green, marker: RetroColor.green, markerSize: 9)
                MarkerLabels(progress: kitProgress, start: "CONFUSED", current: "\(done) of \(total) done", end: "SURVIVED", currentColor: RetroColor.green, followsMarker: false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) of \(total) tasks done this cycle")
    }
}

/// A section card. Collapsed, it shows the first two tasks (for free users, the free one and the
/// first locked one); expanded, all of them, in order.
private struct SectionCard: View {
    static let collapsedCount = 2

    let section: KitSection
    let done: Set<String>
    let isPremium: Bool
    let policy: TaskAccessPolicy
    let isExpanded: Bool
    let onToggle: () -> Void
    let onLocked: () -> Void

    var body: some View {
        let shown = isExpanded ? section.tasks.count : min(Self.collapsedCount, section.tasks.count)
        let hiddenCount = section.tasks.count - shown
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
            // Rows meet edge to edge, each at least 44 pt tall to tap.
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(section.tasks.prefix(shown).enumerated()), id: \.element.id) { index, task in
                    TaskRow(task: task, visibility: policy.visibility(ofTaskAt: index, isPremium: isPremium), isDone: done.contains(task.id), onLocked: onLocked)
                        .transition(.opacity)
                }
            }
            .padding(.vertical, -6)
            if section.tasks.count > Self.collapsedCount {
                // While expanded it reads "Show less"; the count is of the tasks it would hide.
                ExpandCollapseButton(isExpanded: isExpanded, hiddenCount: isExpanded ? section.tasks.count - Self.collapsedCount : hiddenCount, action: onToggle)
                    .frame(maxWidth: .infinity)
                    .padding(.top, -4)
                    .padding(.bottom, -10)
            }
        }
        .retroCard()
    }
}

private struct TaskRow: View {
    let task: KitTask
    let visibility: TaskVisibility
    let isDone: Bool
    let onLocked: () -> Void

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
            Button(action: onLocked) {
                row(checkbox: .locked, textColor: RetroColor.text, textOpacity: 0.4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(task.title) Premium task, locked")
            .accessibilityHint("Shows Premium")
        case .hidden:
            Button(action: onLocked) {
                row(checkbox: .locked, textColor: RetroColor.text, textOpacity: 0.4)
                    .blur(radius: 3)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Premium task, locked")
            .accessibilityHint("Shows Premium")
            .accessibilityAddTraits(.isButton)
        }
    }

    /// Half the cap height of 15 pt Inter: centres the checkbox on the first line of text.
    @ScaledMetric(relativeTo: .subheadline) private var firstLineCentre: CGFloat = 5.5

    private func row(checkbox: TaskCheckbox.State, textColor: Color, textOpacity: Double = 1) -> some View {
        let centre = firstLineCentre
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            TaskCheckbox(checkbox)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + centre }
            Text(task.title)
                .retroText(.body)
                .foregroundStyle(textColor)
                .opacity(textOpacity)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Tappable across the full width, at least 44 pt tall.
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// "23 more tasks in Premium" card under the sections (free users only). Opens the paywall.
private struct PremiumNudge: View {
    let lockedCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
        case .journal: RetroSymbol.journal
        }
    }
}
