import DesignSystem
import Editorial
import RetroCore
import SwiftUI

/// The Calendar tab: a week strip (or the full month when expanded) with Mercury's status, moon
/// phases and the daily intensity on every day, and the selected day's detail underneath.
/// Free: details for today plus the next three days; every day keeps its markers and level.
struct CalendarScreen: View {
    let now: Date
    @Environment(PremiumAccess.self) private var premium
    @Environment(PaywallPresenter.self) private var paywall
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selected: CalendarDay?
    /// The day the visible week / month is built around.
    @State private var anchor: CalendarDay?
    @State private var expanded = false

    private let policy = CalendarAccessPolicy.launch

    var body: some View {
        let calendar = Calendar.autoupdatingCurrent
        let today = CalendarDay(now, in: calendar)
        let coverage = SkyData.ephemeris?.coverage
        let selectedDay = selected ?? clamp(today, to: coverage)
        let anchorDay = anchor ?? selectedDay
        let model = CalendarModel(today: today, anchor: anchorDay, expanded: expanded, firstWeekday: calendar.firstWeekday)

        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("MERCURY").retroText(.cardTitle).foregroundStyle(RetroColor.text).accessibilityAddTraits(.isHeader)
                    Text("Same orbit. Different days. Tap a date to explore what adds to the noise—and what helps soften it.")
                        .retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
                if let coverage, !coverage.contains(today) {
                    OutOfRangeNote(coverage: coverage)
                }
                CalendarCard(
                    model: model, selected: selectedDay, isPremium: premium.isPremium, policy: policy,
                    canGoBack: coverage.map { model.step(-1).lastShownDay >= $0.lowerBound } ?? false,
                    canGoForward: coverage.map { model.step(1).firstShownDay <= $0.upperBound } ?? false,
                    onSelect: { day in
                        selected = day
                        if !expanded { anchor = day }
                    },
                    onStep: { delta in anchor = model.step(delta).anchor },
                    onToggleExpanded: {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            expanded.toggle()
                            anchor = selectedDay
                        }
                    }
                )
                DayDetail(
                    day: selectedDay, today: today, isPremium: premium.isPremium, policy: policy,
                    onUnlock: paywall.present
                )
                .id(Self.detailID)
                Text("Intensity is an astrology-inspired reflection score built from verified sky events, not a prediction.")
                    .retroText(.finePrint)
                    .foregroundStyle(RetroColor.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, RetroMetrics.screenPadding)
            .padding(.top, 6)
            .padding(.bottom, 20)
        }
        #if DEBUG
        .onAppear {
            // `-scrollCalendar detail` scrolls to the day detail, for review screenshots.
            if UserDefaults.standard.string(forKey: "scrollCalendar") == "detail" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { proxy.scrollTo(Self.detailID, anchor: .top) }
            }
        }
        #endif
        }
        .retroScreenBackground()
        #if DEBUG
        .onAppear {
            // `-selectDay 2026-11-07` selects a day; `-calendarExpanded YES` opens the month view.
            if selected == nil, let iso = UserDefaults.standard.string(forKey: "selectDay"), let day = CalendarDay(iso: iso) {
                selected = day
                anchor = day
            }
            if UserDefaults.standard.bool(forKey: "calendarExpanded") { expanded = true }
        }
        #endif
    }

    private static let detailID = "day-detail"

    private func clamp(_ day: CalendarDay, to coverage: ClosedRange<CalendarDay>?) -> CalendarDay {
        guard let coverage else { return day }
        return min(max(day, coverage.lowerBound), coverage.upperBound)
    }
}

/// What the grid shows: one week, or the whole month, around an anchor day.
private struct CalendarModel {
    let today: CalendarDay
    let anchor: CalendarDay
    let expanded: Bool
    let firstWeekday: Int

    var grid: MonthGrid { MonthGrid(year: anchor.year, month: anchor.month, firstWeekday: firstWeekday) }
    var weeks: [[CalendarDay]] { expanded ? grid.weeks : [grid.week(containing: anchor)!] }
    var firstShownDay: CalendarDay { weeks.first!.first! }
    var lastShownDay: CalendarDay { weeks.last!.last! }

    /// The next or previous week (collapsed) or month (expanded).
    func step(_ delta: Int) -> CalendarModel {
        let next: CalendarDay
        if expanded {
            let id = MonthGrid.ID(anchor).adding(months: delta)
            next = CalendarDay(year: id.year, month: id.month, day: 1)
        } else {
            next = anchor.adding(days: 7 * delta)
        }
        return CalendarModel(today: today, anchor: next, expanded: expanded, firstWeekday: firstWeekday)
    }
}

// MARK: - Calendar card

private struct CalendarCard: View {
    let model: CalendarModel
    let selected: CalendarDay
    let isPremium: Bool
    let policy: CalendarAccessPolicy
    let canGoBack: Bool
    let canGoForward: Bool
    let onSelect: (CalendarDay) -> Void
    let onStep: (Int) -> Void
    let onToggleExpanded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            VStack(spacing: 5) {
                weekdayLabels
                ForEach(model.weeks, id: \.first) { week in
                    weekRow(week)
                }
            }
            .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > abs(value.translation.height) else { return }
                if dx < 0, canGoForward { onStep(1) } else if dx > 0, canGoBack { onStep(-1) }
            })
            CalendarKey(model: model, selected: selected, isPremium: isPremium)
        }
        .padding(16)
        .background(RetroColor.surfaceRaised, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.panel))
        .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.panel).strokeBorder(RetroColor.line, lineWidth: 1))
    }

    private var header: some View {
        let monthTitle = VStack(alignment: .leading, spacing: 5) {
            (Text(model.anchor.monthName + " ").font(RetroTextStyle.section.font).foregroundColor(RetroColor.text)
                + Text(String(model.anchor.year)).font(RetroTextStyle.monoLarge.font).foregroundColor(RetroColor.textMuted))
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Text(MercuryContext.label(for: MonthGrid.ID(model.anchor)))
                .retroText(.monoSmall)
                .foregroundStyle(RetroColor.pink)
        }
        let arrows = HStack(spacing: 4) {
            arrow(RetroSymbol.back, label: model.expanded ? "Previous month" : "Previous week", enabled: canGoBack) { onStep(-1) }
            arrow(RetroSymbol.forward, label: model.expanded ? "Next month" : "Next week", enabled: canGoForward) { onStep(1) }
        }
        let toggle = ExpandCollapseButton(isExpanded: model.expanded, action: onToggleExpanded)
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { monthTitle; Spacer(minLength: 4); arrows; toggle }
            VStack(alignment: .leading, spacing: 4) {
                monthTitle
                HStack { arrows; Spacer(); toggle }
            }
        }
    }

    private func arrow(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RetroColor.text)
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(RetroColor.line, lineWidth: 1))
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }

    private var weekdayLabels: some View {
        let symbols = Calendar.autoupdatingCurrent.veryShortStandaloneWeekdaySymbols
        let ordered = (0..<7).map { symbols[(model.firstWeekday - 1 + $0) % 7] }
        return HStack(spacing: 4) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { _, symbol in
                Text(symbol).retroText(.mono).foregroundStyle(RetroColor.textMuted).frame(maxWidth: .infinity)
            }
        }
        .padding(.bottom, 4)
        .accessibilityHidden(true)
    }

    private func weekRow(_ week: [CalendarDay]) -> some View {
        let window = policy.freeWindow(today: model.today)
        let freeIndices = isPremium ? [] : week.indices.filter { window.contains(week[$0]) }
        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                ForEach(week, id: \.self) { day in
                    DayCell(
                        day: day, inMonth: !model.expanded || model.grid.contains(day), isToday: day == model.today,
                        isSelected: day == selected,
                        isLocked: !policy.detailsUnlocked(day, today: model.today, isPremium: isPremium),
                        onTap: { onSelect(day) }
                    )
                }
            }
            if let first = freeIndices.first, let last = freeIndices.last {
                FreeWindowMarker(first: first, last: last, showsLabel: week.contains(window.lowerBound) || first == 0)
            }
        }
    }
}

/// Yellow line under the free days in a row, labelled where the window starts.
private struct FreeWindowMarker: View {
    let first: Int
    let last: Int
    let showsLabel: Bool

    var body: some View {
        GeometryReader { geo in
            let cell = (geo.size.width - 4 * 6) / 7
            let x = CGFloat(first) * (cell + 4)
            let width = CGFloat(last - first + 1) * (cell + 4) - 4
            VStack(alignment: .leading, spacing: 3) {
                Capsule().fill(RetroColor.yellow).frame(width: width, height: 2)
                if showsLabel {
                    Text("FREE · TODAY + 3 DAYS").retroText(.monoTiny).foregroundStyle(RetroColor.yellow).fixedSize()
                }
            }
            .offset(x: x)
        }
        .frame(height: showsLabel ? 16 : 4)
        .accessibilityHidden(true)
    }
}

private struct DayCell: View {
    let day: CalendarDay
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let isLocked: Bool
    let onTap: () -> Void

    var body: some View {
        let reading = SkyData.intensity()?.intensity(on: day)
        let marker = reading.map(DayMarkerText.init)
        let moon = SkyData.intensity()?.moonPhase(on: day)
        Button(action: onTap) {
            VStack(spacing: 4) {
                HStack(spacing: 2) {
                    Text("\(day.day)")
                        .font(.custom(isSelected ? "SpaceMono-Bold" : "SpaceMono-Regular", size: 13, relativeTo: .footnote))
                        .foregroundStyle(RetroColor.text)
                    if isToday {
                        Circle().fill(RetroColor.yellow).frame(width: 5, height: 5)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                Text(marker?.short ?? " ")
                    .font(RetroTextStyle.monoTiny.font)
                    .foregroundStyle(marker?.color ?? .clear)
                IntensityBars(level: reading?.level, highlighted: isSelected)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? RetroColor.wine : RetroColor.cell, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.cell))
            .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.cell).strokeBorder(isSelected ? RetroColor.pink : RetroColor.line, lineWidth: isSelected ? 2 : 0.5))
            .overlay(alignment: .topTrailing) {
                if isLocked, reading != nil {
                    Image(systemName: RetroSymbol.lock).font(.system(size: 6)).foregroundStyle(RetroColor.textMuted.opacity(0.8)).padding(4)
                }
            }
            .overlay(alignment: .topLeading) {
                if let moon {
                    MoonIcon(phase: moon, size: 7).padding(4)
                }
            }
            .opacity(inMonth ? 1 : 0.35)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText(reading: reading, marker: marker, moon: moon))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func accessibilityText(reading: DailyIntensity?, marker: DayMarkerText?, moon: MoonPhase?) -> String {
        var parts = [day.spokenDate]
        if isToday { parts.append("today") }
        if let marker { parts.append(marker.spoken) }
        if let moon { parts.append(moon.spokenName) }
        if let reading { parts.append(DailyInsightCopy.levelName(reading.level)) } else { parts.append("no sky data") }
        if isLocked, reading != nil { parts.append("details in Premium") }
        return parts.joined(separator: ", ")
    }
}

/// Four 6×3 bars; filled up to the level (Figma's cell indicator).
private struct IntensityBars: View {
    let level: IntensityLevel?
    let highlighted: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...4, id: \.self) { step in
                RoundedRectangle(cornerRadius: 1)
                    .fill(level.map { step <= $0.rawValue } == true ? (highlighted ? RetroColor.pink : RetroColor.pinkSoft) : RetroColor.dim)
                    .frame(width: 6, height: 3)
            }
        }
        .opacity(level == nil ? 0 : 1)
    }
}

/// Rx / Sh / D, derived from the day's influences (the same local-day rules as the score).
private struct DayMarkerText {
    let short: String
    let spoken: String
    let color: Color

    init(_ reading: DailyIntensity) {
        let kinds = reading.influences.map(\.kind)
        if kinds.contains(where: { if case .mercuryRetrograde = $0 { true } else { false } }) {
            self.init(short: "Rx", spoken: "Mercury retrograde", color: RetroColor.pinkSoft)
        } else if kinds.contains(where: { if case .mercuryShadow = $0 { true } else { false } }) {
            self.init(short: "Sh", spoken: "Mercury in shadow", color: RetroColor.mauve)
        } else {
            self.init(short: "D", spoken: "Mercury direct", color: RetroColor.textMuted)
        }
    }

    private init(short: String, spoken: String, color: Color) {
        self.short = short
        self.spoken = spoken
        self.color = color
    }
}

private struct MoonIcon: View {
    let phase: MoonPhase
    let size: CGFloat

    var body: some View {
        Image(systemName: phase.symbol)
            .font(.system(size: size))
            .foregroundStyle(Color(red: 0.95, green: 0.90, blue: 0.79))
            .accessibilityHidden(true)
    }
}

// MARK: - Key

private struct CalendarKey: View {
    let model: CalendarModel
    let selected: CalendarDay
    let isPremium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                HStack(spacing: 5) {
                    Circle().fill(RetroColor.yellow).frame(width: 5, height: 5)
                    Text("Today · \(model.today.day)")
                }
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2).strokeBorder(RetroColor.pink, lineWidth: 1.5).frame(width: 11, height: 11)
                    Text("Selected · \(selected.day)")
                }
                Spacer(minLength: 0)
                if !isPremium {
                    HStack(spacing: 4) {
                        Image(systemName: RetroSymbol.lock).font(.system(size: 7))
                        Text("Premium")
                    }
                } else {
                    Text("Tap any day").foregroundStyle(RetroColor.text)
                }
            }
            .retroText(.monoSmall)
            .foregroundStyle(RetroColor.textMuted)
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            RetroColor.line.frame(height: 1)
            Text("DAILY INTENSITY · CALMER → MORE CHALLENGING").retroText(.mono).foregroundStyle(RetroColor.textMuted)
            HStack(spacing: 16) {
                Text("Rx Retrograde").foregroundStyle(RetroColor.pinkSoft)
                Text("Sh Shadow").foregroundStyle(RetroColor.mauve)
                Text("D Direct").foregroundStyle(RetroColor.textMuted)
            }
            .retroText(.monoSmall)
            if model.expanded {
                HStack(spacing: 12) {
                    ForEach(MoonPhase.allCases, id: \.self) { phase in
                        HStack(spacing: 4) {
                            MoonIcon(phase: phase, size: 9)
                            Text(phase.shortName)
                        }
                    }
                }
                .retroText(.monoSmall)
                .foregroundStyle(RetroColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }
            let others = OtherRetrogrades.chips(for: MonthGrid.ID(model.anchor))
            if !others.isEmpty {
                RetroColor.line.frame(height: 1)
                Text("ALSO RETROGRADE THIS MONTH").retroText(.mono).foregroundStyle(RetroColor.textMuted)
                FlowRow(spacing: 8) {
                    ForEach(others, id: \.name) { chip in
                        HStack(spacing: 6) {
                            Text("\(chip.name) Rx").retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                            Text(chip.span).retroText(.monoSmall).foregroundStyle(RetroColor.textMuted)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .overlay(Capsule().strokeBorder(RetroColor.line, lineWidth: 1))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

/// Wraps chips onto new lines when they don't fit.
private struct FlowRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: rows.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(rows.count - 1, 0)))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [(indices: [Int], width: CGFloat, height: CGFloat)] {
        var rows: [(indices: [Int], width: CGFloat, height: CGFloat)] = []
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if let last = rows.last, last.width + spacing + size.width <= width {
                rows[rows.count - 1] = (last.indices + [index], last.width + spacing + size.width, max(last.height, size.height))
            } else {
                rows.append(([index], size.width, size.height))
            }
        }
        return rows
    }
}

// MARK: - Day detail

private struct DayDetail: View {
    let day: CalendarDay
    let today: CalendarDay
    let isPremium: Bool
    let policy: CalendarAccessPolicy
    let onUnlock: () -> Void

    var body: some View {
        let reading = SkyData.intensity()?.intensity(on: day)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(day == today ? "TODAY" : "YOUR SELECTED DAY").retroText(.monoSmall).foregroundStyle(RetroColor.pink)
                    Text(day.longTitle).retroText(.section).foregroundStyle(RetroColor.text).accessibilityAddTraits(.isHeader)
                }
                Spacer(minLength: 8)
                if let reading {
                    let marker = DayMarkerText(reading)
                    Text(marker.short)
                        .retroText(.monoSmall)
                        .foregroundStyle(marker.color)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(RetroColor.wine, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.cell))
                        .accessibilityLabel(marker.spoken)
                }
            }

            if let reading {
                let insight = DailyInsightCopy.insight(for: reading)
                let unlocked = policy.detailsUnlocked(day, today: today, isPremium: isPremium)
                IntensityPanel(level: reading.level, summary: unlocked ? insight.summary : nil)
                if unlocked {
                    SkyContext(rows: insight.rows)
                    HabitCard(habit: insight.habit)
                } else {
                    LockedInsight(day: day, today: today, policy: policy, preview: insight.rows.first, onUnlock: onUnlock)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("WE’RE STILL MAPPING THIS STRETCH OF SKY.").retroText(.cardTitle).foregroundStyle(RetroColor.text)
                    Text("Retrograde only shows verified dates, currently 2025 to 2030. Update the app for the latest cycles.")
                        .retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
            }
        }
        .padding(16)
        .background(RetroColor.surfaceRaised, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.panel))
        .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.panel).strokeBorder(RetroColor.line, lineWidth: 1))
    }
}

/// "Elevated  03 / 04", the four-step scale, and (when unlocked) the day's summary.
private struct IntensityPanel: View {
    let level: IntensityLevel
    let summary: String?

    private static let stepColors = [RetroColor.calm, RetroColor.mauve, RetroColor.pinkSoft, RetroColor.pink]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(DailyInsightCopy.levelName(level)).retroText(.breathCount).foregroundStyle(RetroColor.text)
                Spacer()
                Text(String(format: "%02d / 04", level.rawValue)).retroText(.monoLarge).foregroundStyle(RetroColor.pink)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Daily intensity: \(DailyInsightCopy.levelName(level)), \(level.rawValue) of 4")
            HStack(spacing: 5) {
                ForEach(IntensityLevel.allCases, id: \.self) { step in
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(step <= level ? Self.stepColors[step.rawValue - 1] : RetroColor.dim)
                            .frame(height: 8)
                        Text(DailyInsightCopy.levelName(step))
                            .font(RetroTextStyle.monoTiny.font)
                            .foregroundStyle(step == level ? RetroColor.pink : RetroColor.textMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .accessibilityHidden(true)
            if let summary {
                Text(summary).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
        }
        .padding(14)
        .background(RetroColor.background, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct SkyContext: View {
    let rows: [DailyInsight.Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("WHAT’S SHAPING THE DAY").retroText(.mono).foregroundStyle(RetroColor.text).padding(.bottom, 6)
            if rows.isEmpty {
                row(symbol: "moon.stars", title: "A quiet sky", tag: nil, text: DailyInsightCopy.quietDayText)
            } else {
                ForEach(rows, id: \.title) { r in
                    row(symbol: r.symbol, title: r.title, tag: r.tag, text: r.text)
                }
            }
        }
    }

    private func row(symbol: String, title: String, tag: String?, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(RetroColor.pinkSoft)
                .frame(width: 34, height: 34)
                .background(RetroColor.cell, in: RoundedRectangle(cornerRadius: 10))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(title).font(.custom("Inter-SemiBold", size: 12, relativeTo: .footnote)).foregroundStyle(RetroColor.text)
                        Spacer(minLength: 8)
                        if let tag { Text(tag).retroText(.monoSmall).foregroundStyle(RetroColor.pinkSoft) }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.custom("Inter-SemiBold", size: 12, relativeTo: .footnote)).foregroundStyle(RetroColor.text)
                        if let tag { Text(tag).retroText(.monoSmall).foregroundStyle(RetroColor.pinkSoft) }
                    }
                }
                Text(text).font(.custom("Inter-Regular", size: 11, relativeTo: .caption)).foregroundStyle(RetroColor.textMuted)
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { RetroColor.line.frame(height: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct HabitCard: View {
    let habit: DailyInsight.Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Good habit for this day").font(.custom("ArchivoBlack-Regular", size: 11, relativeTo: .caption)).foregroundStyle(RetroColor.text)
            Text(habit.text).font(.custom("Inter-Regular", size: 11, relativeTo: .caption)).foregroundStyle(RetroColor.textMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RetroColor.wine, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(RetroColor.line, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Approved locked-day layout: blurred preview, lock note, "Unlock every day".
private struct LockedInsight: View {
    let day: CalendarDay
    let today: CalendarDay
    let policy: CalendarAccessPolicy
    let preview: DailyInsight.Row?
    let onUnlock: () -> Void

    var body: some View {
        let freeFrom = policy.freeFrom(day, today: today)
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("What’s shaping the day").retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                Text(preview?.text ?? DailyInsightCopy.quietDayText).retroText(.body).foregroundStyle(RetroColor.textMuted)
            }
            .blur(radius: 4)
            .accessibilityHidden(true)
            HStack(spacing: 12) {
                Image(systemName: RetroSymbol.lock)
                    .font(.system(size: 14))
                    .foregroundStyle(RetroColor.pink)
                    .frame(width: 34, height: 34)
                    .background(RetroColor.wine, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.chip))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(freeFrom == nil ? "Past days’ full reads are in Premium" : "The full read for \(day.shortTitle) is in Premium")
                        .retroText(.bodyStrong).foregroundStyle(RetroColor.text)
                    Text(freeFrom.map { "Free shows today and the next three days. Come back \($0.shortTitle) and it’s yours." } ?? "Free shows today and the next three days.")
                        .retroText(.body).foregroundStyle(RetroColor.textMuted)
                }
            }
            .accessibilityElement(children: .combine)
            PrimaryButton("Unlock every day", systemImage: RetroSymbol.star, action: onUnlock)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(RetroColor.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(RetroColor.line, lineWidth: 1))
    }
}

/// Shown if today is outside the verified data (after 2030).
private struct OutOfRangeNote: View {
    let coverage: ClosedRange<CalendarDay>

    var body: some View {
        Text("Our verified sky data covers \(String(coverage.lowerBound.year))–\(String(coverage.upperBound.year)). Update the app to see the latest cycles.")
            .retroText(.body)
            .foregroundStyle(RetroColor.text)
            .retroCard()
    }
}

// MARK: - Labels from the sky data

private enum MercuryContext {
    /// "MERCURY RX · OCT 24 – NOV 13" for a month with a retrograde, else the next one.
    static func label(for month: MonthGrid.ID) -> String {
        guard let periods = SkyData.ephemeris?.retrogrades(of: .mercury) else { return "MERCURY" }
        let calendar = Calendar.autoupdatingCurrent
        func local(_ date: Date) -> CalendarDay { CalendarDay(date, in: calendar) }
        let monthStart = CalendarDay(year: month.year, month: month.month, day: 1)
        let monthEnd = MonthGrid.ID(year: month.year, month: month.month).adding(months: 1)
        let nextMonthStart = CalendarDay(year: monthEnd.year, month: monthEnd.month, day: 1)
        if let p = periods.first(where: { local($0.stationRetrograde) < nextMonthStart && local($0.stationDirect) >= monthStart }) {
            return "MERCURY RX · \(local(p.stationRetrograde).shortTitle.uppercased()) – \(local(p.stationDirect).shortTitle.uppercased())"
        }
        if let next = periods.first(where: { local($0.stationRetrograde) >= nextMonthStart }) {
            return "NEXT MERCURY RX · \(local(next.stationRetrograde).shortTitle.uppercased())"
        }
        return "MERCURY"
    }
}

private enum OtherRetrogrades {
    struct Chip { let name: String; let span: String }

    static func chips(for month: MonthGrid.ID) -> [Chip] {
        guard let ephemeris = SkyData.ephemeris else { return [] }
        let calendar = Calendar.autoupdatingCurrent
        func local(_ date: Date) -> CalendarDay { CalendarDay(date, in: calendar) }
        let first = CalendarDay(year: month.year, month: month.month, day: 1)
        let next = month.adding(months: 1)
        let last = CalendarDay(year: next.year, month: next.month, day: 1).adding(days: -1)
        return ephemeris.retrogrades.filter { $0.planet != .mercury }.compactMap { p in
            let rx = local(p.stationRetrograde), direct = local(p.stationDirect)
            guard rx <= last, direct >= first else { return nil }
            let span: String = switch (rx < first, direct > last) {
            case (true, true): "all month"
            case (true, false): "until \(direct.shortTitle)"
            case (false, true): "from \(rx.shortTitle)"
            case (false, false): "\(rx.shortTitle) – \(direct.shortTitle)"
            }
            return Chip(name: p.planet.name, span: span)
        }
    }
}

// MARK: - Formatting

extension CalendarDay {
    private var date: Date { start(in: Calendar.autoupdatingCurrent) }
    /// "November"
    var monthName: String { date.formatted(.dateTime.month(.wide)) }
    /// "Nov 7"
    var shortTitle: String { date.formatted(.dateTime.month(.abbreviated).day()) }
    /// "Saturday, Nov 7"
    var longTitle: String { date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }
    /// "Saturday 7 November 2026" (VoiceOver)
    var spokenDate: String { date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()) }
}

extension MoonPhase {
    var symbol: String {
        switch self {
        case .new: "moonphase.new.moon"
        case .firstQuarter: "moonphase.first.quarter"
        case .full: "moonphase.full.moon"
        case .lastQuarter: "moonphase.last.quarter"
        }
    }

    var shortName: String {
        switch self {
        case .new: "New"
        case .firstQuarter: "First qtr"
        case .full: "Full"
        case .lastQuarter: "Last qtr"
        }
    }

    var spokenName: String {
        switch self {
        case .new: "New Moon"
        case .firstQuarter: "First quarter Moon"
        case .full: "Full Moon"
        case .lastQuarter: "Last quarter Moon"
        }
    }
}

extension DailyInsight.Row {
    var symbol: String {
        switch tag {
        case "RETROGRADE": "arrow.uturn.backward"
        case "TURNING POINT": "arrow.triangle.2.circlepath"
        case "NEAR STATION": "scope"
        case "SHADOW": "circle.lefthalf.filled"
        case "MOON PHASE": title.hasPrefix("New") ? "moonphase.new.moon" : "moonphase.full.moon"
        default: "sparkles"
        }
    }
}
