import DesignSystem
import Editorial
import Entitlements
import HomeWidget
import Persistence
import RetroCore
import Sharing
import SurvivalKit
import SwiftUI

/// The Overview once the Survival Kit is started (approved M13.1 Figma, State B): a compact Mercury
/// card, then the person's kit progress, today's Calendar read and their recent shares, and a
/// dismissible widget tip. Every section reads the same data as its own tab.
struct OverviewDashboard: View {
    let now: Date
    /// Nil outside the verified data.
    let status: CycleStatus?
    @Environment(CompletionStore.self) private var completions
    @Environment(EntitlementStore.self) private var premium
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(AppRouter.self) private var router
    @Environment(SharingActivity.self) private var sharing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Hidden while iOS lists a widget, or after ✕; Settings › Widgets keeps the how-to.
    @Environment(WidgetPrompt.self) private var widgetPrompt
    /// Today's card, previewed for sharing from the empty sharing section.
    @State private var sharingCard: InsightShareCard?

    private let kit = SurvivalKit.for(.mercury)!

    var body: some View {
        let today = CalendarDay(now, in: .autoupdatingCurrent)
        let cycleID = KitCycle.id(at: now)
        let progress = KitProgressSummary(kit: kit, done: completions.completedTaskIDs(in: cycleID), isPremium: premium.isPremium)
        // Today is always in the free window, so its details are always unlocked.
        let todayContent = SkyData.intensity().flatMap {
            DayDetailContent.make(day: today, today: today, isPremium: premium.isPremium, policy: .launch, intensity: $0)
        }
        VStack(alignment: .leading, spacing: RetroMetrics.sectionSpacing) {
            if let status, let content = WidgetContent(status: status) {
                MercuryStatusCard(status: status, content: content)
            } else {
                MissingSkyData(padded: false)
            }
            DashboardSection("YOUR SURVIVAL KIT", detail: "THIS CYCLE") {
                KitCard(
                    progress: progress,
                    // A new retrograde has reset the kit; earlier cycles' ticks are still saved.
                    isNewCycle: progress.done == 0 && completions.hasCompletions(outside: cycleID),
                    onOpenTask: { router.openKit(at: $0) },
                    onOpenKit: { router.openKit() },
                    onUnlock: paywall.present
                )
            }
            .id("kit")
            if let todayContent, case let .unlocked(insight, _) = todayContent.details {
                DashboardSection("TODAY", detail: today.mediumTitle.uppercased()) {
                    TodayCard(level: todayContent.level, insight: insight) { router.openCalendar(on: today) }
                }
                .id("today")
            }
            DashboardSection("YOUR SHARING", detail: "ON THIS IPHONE") {
                SharingCard(
                    records: sharing.recent(3), today: today,
                    todayCard: todayContent.flatMap(InsightShareCard.init),
                    onOpenDay: { router.openCalendar(on: $0) },
                    onShareCard: { sharingCard = $0 },
                    onShareApp: { ShareSheet.shareApp(recordingIn: sharing) }
                )
            }
            .id("sharing")
            if widgetPrompt.showsTip {
                WidgetTip(onOpen: router.openWidgetHowTo) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { widgetPrompt.dismissTip() }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, RetroMetrics.screenPadding)
        .padding(.top, 6)
        .padding(.bottom, 20)
        .sheet(item: $sharingCard) { InsightSharePreview(card: $0) }
    }
}

/// "YOUR SURVIVAL KIT ········ THIS CYCLE" above a section's card.
private struct DashboardSection<Content: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let content: Content

    init(_ title: String, detail: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        let titleText = Text(title).retroText(.mono).foregroundStyle(RetroColor.text)
        let detailText = Text(detail).retroText(.monoSmall).foregroundStyle(RetroColor.textMuted)
        VStack(alignment: .leading, spacing: 10) {
            // One row where it fits; with large text, the detail under the title.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    titleText
                    Spacer(minLength: 8)
                    detailText
                }
                .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    titleText
                    detailText
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

// MARK: - Mercury

/// "MERCURY RETROGRADE · DAY 12 / 21", the countdown, where the stage ends, and its bar: the
/// Overview's tracker in the widget's words.
private struct MercuryStatusCard: View {
    let status: CycleStatus
    let content: WidgetContent

    var body: some View {
        let dayLabel = OverviewCopy.for(status.planet, status.stage)?.dayLabel(day: status.day, of: status.totalDays)
        let endDay = CalendarDay(status.countdownTarget, in: .autoupdatingCurrent)
        let ends = "\(content.trailing.capitalized) \(endDay.shortTitle)"
        let countdown = HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(content.countdown).retroText(.display).foregroundStyle(RetroColor.yellow)
            Text(content.countdownText).retroText(.monoLarge).foregroundStyle(RetroColor.text)
        }
        let endLabel = Text(ends).retroText(.monoSmall).foregroundStyle(RetroColor.textMuted)
        let phase = Text("\(content.planetName) \(content.phaseName)").retroText(.monoSmall).foregroundStyle(content.stage.accent)
        let day = dayLabel.map { Text($0).retroText(.monoSmall).foregroundStyle(RetroColor.textMuted) }
        // Figma's two rows where they fit; with large text each label drops onto its own line.
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    phase
                    Spacer(minLength: 8)
                    day
                }
                .lineLimit(1)
                VStack(alignment: .leading, spacing: 2) {
                    phase
                    day
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    countdown
                    Spacer(minLength: 12)
                    endLabel
                }
                .lineLimit(1)
                VStack(alignment: .leading, spacing: 4) {
                    countdown
                    endLabel
                }
            }
            CycleProgressBar(progress: content.progress, fill: content.stage.accent, marker: nil)
        }
        .retroCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(content.accessibilityLabel) \(content.trailing.capitalized) on \(endDay.spokenDate).")
    }
}

// MARK: - Survival Kit

private struct KitCard: View {
    let progress: KitProgressSummary
    let isNewCycle: Bool
    let onOpenTask: (KitTask) -> Void
    let onOpenKit: () -> Void
    let onUnlock: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(progress.done)").retroText(.display).foregroundStyle(RetroColor.text)
                    Text("of \(progress.total) done").retroText(.monoLarge).foregroundStyle(RetroColor.text)
                    Spacer(minLength: 8)
                    Text("\(progress.percent)%").retroText(.monoSmall).foregroundStyle(RetroColor.textMuted)
                }
                .lineLimit(1)
                CycleProgressBar(progress: progress.fraction, marker: nil)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(progress.done) of \(progress.total) tasks done this cycle")
            .accessibilityValue("\(progress.percent) percent")

            switch progress.state {
            case .inProgress:
                if let task = progress.nextTask, let section = progress.nextSection {
                    NextUpRow(task: task, section: section) { onOpenTask(task) }
                }
                PrimaryButton("Continue Survival Kit", systemImage: RetroSymbol.firstAid, layout: .leading, showsArrow: true) {
                    if let task = progress.nextTask { onOpenTask(task) } else { onOpenKit() }
                }
                .accessibilityHint("Opens the next task")
                if isNewCycle {
                    Note(symbol: RetroSymbol.newCycle, text: "New cycle, fresh kit. Your past cycles stay saved.")
                } else if progress.lockedCount > 0 {
                    Button(action: onUnlock) {
                        Note(symbol: RetroSymbol.lock, text: "\(progress.freeTasksLeft) free \(progress.freeTasksLeft == 1 ? "task" : "tasks") left · \(progress.lockedCount) more in Premium")
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, -10) // the 44 pt tap area overhangs the card's spacing
                    .accessibilityHint("Shows Premium")
                }
            case .freeTasksDone:
                Text("Every free task is done. Nice work.").retroText(.body).foregroundStyle(RetroColor.text)
                PrimaryButton("Unlock \(progress.lockedCount) more tasks", systemImage: RetroSymbol.star, layout: .leading, showsArrow: true, action: onUnlock)
                    .accessibilityHint("Shows Premium")
                TextLink("Open Survival Kit", action: onOpenKit)
            case .allDone:
                PrimaryButton("Done for this cycle", systemImage: RetroSymbol.checkCircle, style: .completed) {}
                    .allowsHitTesting(false)
                Note(symbol: RetroSymbol.moon, text: "The next kit arrives with Mercury’s next retrograde.")
            }
        }
        .retroCard()
    }
}

/// The next task the person can open, as a tappable row.
private struct NextUpRow: View {
    let task: KitTask
    let section: KitSection
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                TaskCheckbox(.open)
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEXT UP · \(section.category)").retroText(.monoSmall).foregroundStyle(RetroColor.textMuted)
                    Text(task.title).retroText(.body).foregroundStyle(RetroColor.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(minHeight: 44)
            .background(RetroColor.background, in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next up, \(section.category.capitalized): \(task.title)")
        .accessibilityHint("Opens the task")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Today

/// Today's read from the Calendar: level, summary and good habit, in the Calendar's own views.
private struct TodayCard: View {
    let level: IntensityLevel
    let insight: DailyInsight
    let onOpenCalendar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            IntensityPanel(level: level, summary: insight.summary, framed: false)
            HabitCard(habit: insight.habit)
            TextLink("Open today in Calendar", action: onOpenCalendar)
                .accessibilityHint("Shows today’s full read")
        }
        .retroCard()
    }
}

// MARK: - Sharing

/// The latest finished shares, newest first: a day's card opens that day; an app invitation is
/// listed only. No recipients or destination apps: iOS doesn't tell Retrograde.
private struct SharingCard: View {
    let records: [ShareRecord]
    let today: CalendarDay
    /// Nil outside the verified data.
    let todayCard: InsightShareCard?
    let onOpenDay: (CalendarDay) -> Void
    let onShareCard: (InsightShareCard) -> Void
    let onShareApp: () -> Void

    var body: some View {
        if records.isEmpty {
            empty
        } else {
            VStack(alignment: .leading, spacing: 10) {
                VStack(spacing: 0) {
                    ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                        row(record)
                            .overlay(alignment: .top) {
                                if index > 0 { RetroColor.line.frame(height: 1) }
                            }
                    }
                }
                .padding(.horizontal, RetroMetrics.cardPadding)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(RetroColor.surface, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.card).strokeBorder(RetroColor.line, lineWidth: 1))
                Text("Only shares you finished are listed. iOS doesn’t tell Retrograde who received them.")
                    .retroText(.finePrint)
                    .foregroundStyle(RetroColor.textMuted)
            }
        }
    }

    @ViewBuilder private func row(_ record: ShareRecord) -> some View {
        let when = Self.when(record.sharedAt, today: today)
        if let day = record.item.insightDay {
            Button { onOpenDay(day) } label: {
                rowContent(symbol: RetroSymbol.planning, title: "Daily insight · \(day.mediumTitle)", detail: "Shared \(when)", opens: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Daily insight for \(day.spokenDate), shared \(when)")
            .accessibilityHint("Opens that day in the Calendar")
        } else {
            rowContent(symbol: RetroSymbol.share, title: "Shared Retrograde", detail: "App invitation · \(when)", opens: false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Shared Retrograde, app invitation, \(when)")
        }
    }

    private func rowContent(symbol: String, title: String, detail: String, opens: Bool) -> some View {
        HStack(spacing: 12) {
            IconChip(systemImage: symbol)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                Text(detail).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if opens {
                Image(systemName: RetroSymbol.chevronRight)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RetroColor.textMuted)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 12)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: RetroSymbol.share)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(RetroColor.pink)
                .accessibilityHidden(true)
            VStack(spacing: 6) {
                Text("Nothing shared yet.").retroText(.cardTitle).foregroundStyle(RetroColor.text)
                Text("Send a friend today’s card, or invite someone who needs this. What you share shows up here.")
                    .retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
            .accessibilityElement(children: .combine)
            if let todayCard {
                SecondaryButton("Share today’s card", systemImage: RetroSymbol.share) { onShareCard(todayCard) }
                    .accessibilityHint("Previews today’s card to share")
                    .padding(.top, 4)
            }
            TextLink("Share Retrograde", action: onShareApp)
                .accessibilityHint("Opens the share sheet")
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .retroCard()
    }

    /// "today", "yesterday", "Nov 1" (with the year when it isn't this one).
    private static func when(_ date: Date, today: CalendarDay) -> String {
        let day = CalendarDay(date, in: .autoupdatingCurrent)
        if day == today { return "today" }
        if day.adding(days: 1) == today { return "yesterday" }
        return day.year == today.year ? day.shortTitle : "\(day.shortTitle), \(String(day.year))"
    }
}

// MARK: - Widget

/// "Mercury on your Home Screen": opens the how-to; ✕ hides it for good. iOS doesn't tell apps
/// whether their widget is installed, so it never says it is.
private struct WidgetTip: View {
    let onOpen: () -> Void
    let onHide: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    IconChip(systemImage: RetroSymbol.widget)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mercury on your Home Screen").retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                        Text("See how to add the widget").retroText(.body).foregroundStyle(RetroColor.pink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityHint("Shows how to add the widget")
            Button(action: onHide) {
                Image(systemName: RetroSymbol.close)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(RetroColor.textMuted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide widget tip")
            .accessibilityHint("The how-to stays in Settings")
        }
        .padding(.vertical, 10)
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .overlay(
            RoundedRectangle(cornerRadius: RetroMetrics.Radius.card)
                .strokeBorder(RetroColor.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
        )
    }
}

// MARK: - Small pieces

/// A muted note with a small icon ("New cycle, fresh kit.").
private struct Note: View {
    let symbol: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol).font(.system(size: 11, weight: .medium)).accessibilityHidden(true)
            Text(text).retroText(.body)
        }
        .foregroundStyle(RetroColor.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Pink text with an arrow ("Open today in Calendar →"), 44 pt tall to tap.
private struct TextLink: View {
    let title: String
    let action: () -> Void

    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title).retroText(.bodyStrong)
                Image(systemName: RetroSymbol.forward).font(.system(size: 13, weight: .semibold)).accessibilityHidden(true)
            }
            .foregroundStyle(RetroColor.pink)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, -6)
    }
}
