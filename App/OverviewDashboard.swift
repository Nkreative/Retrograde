import DesignSystem
import Editorial
import Entitlements
import Persistence
import RetroCore
import Sharing
import SurvivalKit
import SwiftUI

/// The Overview once the Survival Kit is started (State B; approved M13.1 Figma, the Calm, Mild,
/// Elevated and Intense frames): "Today", Mercury's countdown with the cycle and Survival Kit bars,
/// the Add Widget pill while iOS lists no Retrograde widget, today's intensity card and the sharing
/// card. Every number and sentence comes from the same data as the other tabs.
struct OverviewDashboard: View {
    let now: Date
    /// Nil outside the verified data.
    let status: CycleStatus?
    @Environment(CompletionStore.self) private var completions
    @Environment(EntitlementStore.self) private var premium
    @Environment(AppRouter.self) private var router
    @Environment(SharingActivity.self) private var sharing
    @Environment(WidgetPrompt.self) private var widgetPrompt

    private let kit = SurvivalKit.for(.mercury)!

    /// The visible height under the header, so spare room is shared between the sections rather than
    /// left under the last card. Zero until measured.
    var viewportHeight: CGFloat = 0

    var body: some View {
        let today = CalendarDay(now, in: .autoupdatingCurrent)
        let progress = KitProgressSummary(kit: kit, done: completions.completedTaskIDs(in: KitCycle.id(at: now)), isPremium: premium.isPremium)
        let showsPill = OverviewLayout.showsWidgetPill(widgetPrompt)
        let stretch = OverviewLayout.gapStretch(viewportHeight: viewportHeight)
        // Each gap grows from its minimum to the Figma spacing as room allows (header 16, title 14,
        // bars to card 44, cards 31, scaled up on taller screens); anything left over stays at the bottom. With large text the gaps
        // stay at their minimums and the page scrolls.
        VStack(alignment: .leading, spacing: 0) {
            Gap(6...16, stretch: stretch)
            Text("Today")
                .retroText(.cardTitle)
                .foregroundStyle(RetroColor.text)
                .accessibilityAddTraits(.isHeader)
            Gap(12...16, stretch: stretch)
            if let status, let copy = OverviewCopy.for(status.planet, status.stage) {
                CycleSection(status: status, copy: copy, kit: progress) { router.open(overview: .survivalKit) }
            } else {
                MissingSkyData(padded: false)
            }
            if showsPill {
                Gap(2...8, stretch: stretch)
                HStack {
                    Spacer()
                    PillButton("ADD WIDGET", systemImage: RetroSymbol.add) { router.open(overview: .widgetHowTo) }
                        .accessibilityHint("Shows how to add the widget")
                }
                Gap(4...14, stretch: stretch)
            } else {
                Gap(24...44, stretch: stretch)
            }
            if let today = OverviewToday.make(today: today) {
                IntensityCard(today: today) { router.open(overview: .today(today.day)) }
                Gap(16...31, stretch: stretch)
            }
            SharingCard(summary: SharingSummary(finishedShares: sharing.records.count)) { router.open(overview: .shareInvite) }
            Spacer(minLength: 20)
        }
        .frame(minHeight: viewportHeight, alignment: .top)
        .padding(.horizontal, RetroMetrics.screenPadding)
    }
}

/// A vertical gap that takes as much of the spare height as it may, between `range`'s bounds.
private struct Gap: View {
    let range: ClosedRange<CGFloat>
    let stretch: CGFloat

    init(_ range: ClosedRange<CGFloat>, stretch: CGFloat) {
        self.range = range
        self.stretch = stretch
    }

    var body: some View {
        Spacer(minLength: range.lowerBound).frame(maxHeight: range.upperBound * stretch)
    }
}

/// Small rules the dashboard follows, kept apart so they can be tested.
enum OverviewLayout {
    /// The Add Widget pill shows while iOS reports no Retrograde widget (best effort; see `WidgetPrompt`).
    @MainActor static func showsWidgetPill(_ prompt: WidgetPrompt) -> Bool { prompt.offersWidget }

    /// How much the gaps may grow beyond Figma's spacing: 1 on the 17e-sized screen Figma was drawn
    /// for (580 pt between header and tab bar), more on taller ones, never less.
    static func gapStretch(viewportHeight: CGFloat) -> CGFloat {
        min(max(viewportHeight / 580, 1), 1.5)
    }
}

/// Which Overview the person sees: the kit introduction until they start the Survival Kit, then
/// the dashboard for good (new cycles included).
enum OverviewMode: Equatable {
    case introduction, dashboard

    init(kitStarted: Bool) {
        self = kitStarted ? .dashboard : .introduction
    }
}

/// Today's level and explanation for the intensity card, from the same daily data as the Calendar.
/// Today is always in the free window, so it's always unlocked; nil outside the verified data.
struct OverviewToday: Equatable {
    let day: CalendarDay
    let level: IntensityLevel
    let summary: String

    @MainActor static func make(today: CalendarDay, intensity: IntensityCalculator? = SkyData.intensity()) -> OverviewToday? {
        guard let intensity,
              let content = DayDetailContent.make(day: today, today: today, isPremium: false, policy: .launch, intensity: intensity),
              case let .unlocked(insight, _) = content.details
        else { return nil }
        return OverviewToday(day: today, level: content.level, summary: insight.summary)
    }
}

// MARK: - Mercury cycle

/// The countdown, where Mercury is in this stage (pink) and how much of the Survival Kit is done
/// (yellow). One button: it opens the Survival Kit.
private struct CycleSection: View {
    let status: CycleStatus
    let copy: OverviewCopy
    let kit: KitProgressSummary
    let action: () -> Void

    var body: some View {
        let tasks = kit.done == 1 ? "1 task done" : "\(kit.done) tasks done"
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                CountdownRow(status: status, copy: copy)
                VStack(spacing: 7) {
                    MarkerLabels(progress: status.progress, start: copy.barStart, current: "YOU ARE HERE", end: copy.barEnd, currentColor: RetroColor.pink)
                    CycleProgressBar(progress: status.progress, marker: RetroColor.pink, markerSize: 9)
                    CycleProgressBar(progress: kit.fraction, fill: RetroColor.yellow, marker: RetroColor.yellow, markerSize: 9)
                    // Spread across the bar as in Figma; with large text the count goes on its own line.
                    ViewThatFits(in: .horizontal) {
                        HStack {
                            Text("CONFUSED").foregroundStyle(RetroColor.textMuted)
                            Spacer(minLength: 8)
                            Text(tasks).foregroundStyle(RetroColor.yellow)
                            Spacer(minLength: 8)
                            Text("SURVIVED").foregroundStyle(RetroColor.textMuted)
                        }
                        VStack(spacing: 4) {
                            Text(tasks).foregroundStyle(RetroColor.yellow)
                            HStack {
                                Text("CONFUSED")
                                Spacer(minLength: 8)
                                Text("SURVIVED")
                            }
                            .foregroundStyle(RetroColor.textMuted)
                        }
                    }
                    .retroText(.monoSmall)
                    .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spokenStatus(tasks: tasks))
        .accessibilityHint("Opens the Survival Kit")
        .accessibilityAddTraits(.isButton)
    }

    private func spokenStatus(tasks: String) -> String {
        let days = status.daysUntilTarget
        let countdown = days == 0 ? "Today, \(copy.countdownToday)" : "\(days) \(copy.countdownUnit(for: days))"
        let day = copy.dayLabel(day: status.day, of: status.totalDays).map { ", " + $0.capitalized.replacingOccurrences(of: " / ", with: " of ") } ?? ""
        return "\(countdown)\(day). Survival Kit: \(tasks), \(kit.done) of \(kit.total)."
    }
}

// MARK: - Intensity

/// Today's level, the four-step scale and the day's explanation over Mercury, whose size, glow and
/// orbit rings grow with the level. One button: it opens today in the Calendar.
private struct IntensityCard: View {
    let today: OverviewToday
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RetroMetrics.Radius.panel)
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(DailyInsightCopy.levelName(today.level))
                        .retroText(.breathCount)
                        .foregroundStyle(RetroColor.text)
                    Spacer(minLength: 8)
                    Chevron()
                }
                IntensityScale(level: today.level)
                Text(today.summary)
                    .retroText(.body)
                    .foregroundStyle(RetroColor.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(17)
            .frame(maxWidth: .infinity, minHeight: 219, alignment: .topLeading)
            .background(alignment: .bottomTrailing) {
                // Behind large text the planet steps back so the words stay readable.
                IntensityArtworkView(artwork: .for(today.level))
                    .opacity(typeSize.isAccessibilitySize ? 0.35 : 1)
            }
            .background(RetroColor.surfaceRaised)
            .clipShape(shape)
            .overlay(shape.strokeBorder(RetroColor.line, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today’s intensity: \(DailyInsightCopy.levelName(today.level)), \(today.level.rawValue) of 4. \(today.summary)")
        .accessibilityHint("Opens today in the Calendar")
        .accessibilityAddTraits(.isButton)
    }
}

/// Four bars, filled up to the level in the Calendar's step colours.
private struct IntensityScale: View {
    let level: IntensityLevel

    var body: some View {
        HStack(spacing: 5) {
            ForEach(IntensityLevel.allCases, id: \.self) { step in
                RoundedRectangle(cornerRadius: 2)
                    .fill(step <= level ? IntensityPanel.stepColors[step.rawValue - 1] : RetroColor.dim)
                    .frame(height: 8)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The intensity card's artwork at each level, as in the approved Figma frames (Calm 384:2243, Mild
/// 384:2345, Elevated 384:2448, Intense 384:2551): one composition, Mercury rising from the card's
/// lower right, larger at each level. Each image is the planet rendered at its Figma crop, turn, size
/// and position on the 342 × 219 pt card, at 3×, transparent around it. No other effects.
struct IntensityArtwork: Equatable {
    let image: String
    /// The planet's diameter on the card, in points (Figma).
    let diameter: CGFloat

    static let canvas = CGSize(width: 342, height: 219)

    static func `for`(_ level: IntensityLevel) -> IntensityArtwork {
        switch level {
        case .calm: IntensityArtwork(image: "IntensityCalm", diameter: 69)
        case .mild: IntensityArtwork(image: "IntensityMild", diameter: 118)
        case .elevated: IntensityArtwork(image: "IntensityElevated", diameter: 156)
        case .intense: IntensityArtwork(image: "IntensityIntense", diameter: 283)
        }
    }
}

/// The planet at the Figma card's size, pinned to the card's lower right so a wider card keeps the
/// same corner composition.
private struct IntensityArtworkView: View {
    let artwork: IntensityArtwork

    var body: some View {
        Image(artwork.image)
            .resizable()
            .interpolation(.high)
            .frame(width: IntensityArtwork.canvas.width, height: IntensityArtwork.canvas.height)
            .accessibilityHidden(true)
    }
}

// MARK: - Sharing

/// "12 times you’ve shared Retrograde" over a small constellation. One button: it opens the Share screen.
private struct SharingCard: View {
    let summary: SharingSummary
    let action: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RetroMetrics.Radius.panel)
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let count = summary.count {
                    Text(count).retroText(.display).foregroundStyle(RetroColor.yellow)
                }
                // One line, as in Figma (shrinking slightly on narrow phones); wraps only at the
                // largest text sizes.
                Text(summary.message)
                    .retroText(.bodyStrong)
                    .foregroundStyle(RetroColor.text)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                Spacer(minLength: 4)
                Chevron()
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(alignment: .bottomTrailing) { Constellation().opacity(typeSize.isAccessibilitySize ? 0.35 : 1) }
            .background(RetroColor.surfaceRaised)
            .clipShape(shape)
            .overlay(shape.strokeBorder(RetroColor.line, lineWidth: 1))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.spoken)
        .accessibilityHint("Opens Share Retrograde")
        .accessibilityAddTraits(.isButton)
    }
}

/// The Figma constellation: five stars, one highlighted, joined by fine lines (points in the
/// 342 × 92 pt card, pinned to its lower right).
private struct Constellation: View {
    private static let stars: [CGPoint] = [CGPoint(x: 188, y: 78), CGPoint(x: 220, y: 64), CGPoint(x: 252, y: 74), CGPoint(x: 284, y: 56), CGPoint(x: 318, y: 76)]

    var body: some View {
        let s = Self.stars
        ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: s[0]); p.addLine(to: s[1]); p.addLine(to: s[2]); p.addLine(to: s[3]); p.addLine(to: s[4])
                p.move(to: s[2]); p.addLine(to: s[4])
            }
            .stroke(RetroColor.mauve.opacity(0.5), lineWidth: 0.75)
            ForEach(Array(s.enumerated()), id: \.offset) { index, point in
                let highlighted = index == 3
                let d: CGFloat = highlighted ? 6 : 4
                Circle()
                    .fill(highlighted ? RetroColor.yellow : RetroColor.text.opacity(0.75))
                    .frame(width: d, height: d)
                    .offset(x: point.x - d / 2, y: point.y - d / 2)
            }
        }
        .frame(width: 342, height: 92, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}

/// The subtle "opens something" arrow on the dashboard's cards.
private struct Chevron: View {
    var body: some View {
        Image(systemName: RetroSymbol.chevronRight)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(RetroColor.textMuted)
            .accessibilityHidden(true)
    }
}
