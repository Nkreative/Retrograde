import SwiftUI

// MARK: - Header

/// Top bar on every main screen: logo, wordmark, tagline, then share, notifications and settings.
public struct AppHeader: View {
    let onShare: () -> Void
    let onNotifications: () -> Void
    let onSettings: () -> Void
    /// Shows a dot on the bell when the Notification Center has unread items.
    let hasUnreadNotifications: Bool

    public init(onShare: @escaping () -> Void, onNotifications: @escaping () -> Void, onSettings: @escaping () -> Void, hasUnreadNotifications: Bool = false) {
        self.onShare = onShare
        self.onNotifications = onNotifications
        self.onSettings = onSettings
        self.hasUnreadNotifications = hasUnreadNotifications
    }

    public var body: some View {
        // Figma's 430 pt layout first; narrower phones get slightly smaller buttons
        // and, on the smallest, a gently scaled wordmark rather than a wrapped one.
        ViewThatFits(in: .horizontal) {
            row(buttonSize: RetroMetrics.headerButtonSize, spacing: 13)
            row(buttonSize: 36, spacing: 8)
        }
        // The header is chrome, like a navigation bar: it stops growing at the largest text sizes.
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .padding(.horizontal, RetroMetrics.screenPadding)
        .frame(minHeight: RetroMetrics.headerHeight)
    }

    private func row(buttonSize: CGFloat, spacing: CGFloat) -> some View {
        HStack(spacing: 12) {
            BrandMark()
            VStack(alignment: .leading, spacing: 2) {
                Text("RETROGRADE")
                    .retroText(.title)
                    .foregroundStyle(RetroColor.text)
                Text("YOUR COSMIC REALITY CHECK")
                    .retroText(.monoSmall)
                    .foregroundStyle(RetroColor.textMuted)
                    .minimumScaleFactor(0.6) // shrinks rather than cuts off at larger text sizes
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            HStack(spacing: spacing) {
                HeaderIconButton(systemImage: RetroSymbol.share, label: "Share Retrograde", size: buttonSize, action: onShare)
                HeaderIconButton(systemImage: RetroSymbol.notifications, label: hasUnreadNotifications ? "Notifications, unread" : "Notifications",
                                 size: buttonSize, showsBadge: hasUnreadNotifications, action: onNotifications)
                HeaderIconButton(systemImage: RetroSymbol.settings, label: "Settings", size: buttonSize, action: onSettings)
            }
        }
    }
}

/// 40 pt outlined circle button used in the header.
public struct HeaderIconButton: View {
    let systemImage: String
    let label: String
    let size: CGFloat
    let showsBadge: Bool
    let action: () -> Void

    public init(systemImage: String, label: String, size: CGFloat = RetroMetrics.headerButtonSize, showsBadge: Bool = false, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.size = size
        self.showsBadge = showsBadge
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(RetroColor.text)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(RetroColor.line, lineWidth: 1))
                .overlay(alignment: .topTrailing) {
                    if showsBadge {
                        Circle().fill(RetroColor.pink)
                            .overlay(Circle().strokeBorder(RetroColor.background, lineWidth: 2))
                            .frame(width: 11, height: 11)
                            .offset(x: -2, y: 2)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Buttons

/// Pink 52 pt button. `.leading` puts the label at the start with an optional arrow at the end
/// ("Go to my survival kit"); `.center` centres icon and label ("Mark as done").
public struct PrimaryButton: View {
    public enum Layout { case leading, center }
    /// `.completed` is the wine "Done for this cycle" state from Figma.
    public enum Style { case filled, completed }

    let title: String
    let systemImage: String?
    let layout: Layout
    let style: Style
    let showsArrow: Bool
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, layout: Layout = .center, style: Style = .filled, showsArrow: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.layout = layout
        self.style = style
        self.showsArrow = showsArrow
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                if layout == .center { Spacer(minLength: 0) }
                if let systemImage {
                    Image(systemName: systemImage).font(.system(size: 16, weight: .semibold))
                }
                Text(title).retroText(.button)
                    .multilineTextAlignment(layout == .center ? .center : .leading) // when large text wraps it
                Spacer(minLength: 0)
                if showsArrow {
                    Image(systemName: RetroSymbol.forward).font(.system(size: 15, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: RetroMetrics.buttonHeight)
            .foregroundStyle(RetroColor.text)
            .background(style == .filled ? RetroColor.pink : RetroColor.wine, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.button))
            .overlay {
                if style == .completed {
                    RoundedRectangle(cornerRadius: RetroMetrics.Radius.button).strokeBorder(RetroColor.pink, lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(PressFeedbackStyle())
    }
}

/// Outlined secondary button ("Copy prompt", "Open iOS Settings").
public struct SecondaryButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            SecondaryButtonLabel(title, systemImage: systemImage)
        }
        .buttonStyle(PressFeedbackStyle())
    }
}

/// The outlined look on its own, for controls that aren't plain buttons (e.g. a `ShareLink`).
public struct SecondaryButtonLabel: View {
    let title: String
    let systemImage: String?

    public init(_ title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)) }
            Text(title).retroText(.button)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
        .foregroundStyle(RetroColor.text)
        .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.button).strokeBorder(RetroColor.text, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

/// The Figma calendar's Expand / Collapse capsule, also used by Survival Kit sections.
/// `hiddenCount` adds "· 5 more" while collapsed.
public struct ExpandCollapseButton: View {
    let isExpanded: Bool
    let hiddenCount: Int?
    let action: () -> Void

    public init(isExpanded: Bool, hiddenCount: Int? = nil, action: @escaping () -> Void) {
        self.isExpanded = isExpanded
        self.hiddenCount = hiddenCount
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(isExpanded ? "Collapse" : hiddenCount.map { "Expand · \($0) more" } ?? "Expand")
                    .retroText(.monoSmall)
                Image(systemName: isExpanded ? RetroSymbol.chevronUp : RetroSymbol.chevronDown)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(RetroColor.text)
            .padding(.vertical, 8)
            .padding(.horizontal, 14)
            .overlay(Capsule().strokeBorder(RetroColor.textMuted, lineWidth: 1))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityLabel(isExpanded ? "Show fewer" : hiddenCount.map { "Show \($0) more" } ?? "Expand")
    }
}

/// Small outlined capsule ("+ ADD TO HOME SCREEN").
public struct PillButton: View {
    let title: String
    let systemImage: String?
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 10, weight: .bold)) }
                Text(title).retroText(.monoBold)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
            .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
            // The capsule stays compact; the tappable area is 44 pt tall.
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackStyle())
    }
}

struct PressFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Surfaces

public extension View {
    /// Rounded card: surface fill, 1 pt border, 16 pt padding.
    func retroCard(padding: CGFloat = RetroMetrics.cardPadding, fill: Color = RetroColor.surface, radius: CGFloat = RetroMetrics.Radius.card) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(RetroColor.line, lineWidth: 1))
    }

    /// Full-screen app background.
    func retroScreenBackground() -> some View {
        background(RetroColor.background.ignoresSafeArea())
    }
}

/// 34 pt rounded square with a pink icon (topic rows, section headings).
public struct IconChip: View {
    let systemImage: String
    let size: CGFloat

    public init(systemImage: String, size: CGFloat = RetroMetrics.iconChipSize) {
        self.systemImage = systemImage
        self.size = size
    }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .medium))
            .foregroundStyle(RetroColor.pink)
            .frame(width: size, height: size)
            .background(RetroColor.chip, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.chip))
            .accessibilityHidden(true)
    }
}

/// Small yellow capsule ("BEST VALUE").
public struct Badge: View {
    let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(title)
            .retroText(.monoBold)
            .foregroundStyle(RetroColor.background)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(RetroColor.yellow, in: Capsule())
    }
}

// MARK: - Progress

/// Thin progress track with a filled portion and a round marker ("you are here").
public struct CycleProgressBar: View {
    let progress: Double
    let fill: Color
    let marker: Color
    let markerSize: CGFloat

    public init(progress: Double, fill: Color = RetroColor.pink, marker: Color = RetroColor.yellow, markerSize: CGFloat = 11) {
        self.progress = min(max(progress, 0), 1)
        self.fill = fill
        self.marker = marker
        self.markerSize = markerSize
    }

    public var body: some View {
        GeometryReader { geo in
            let x = geo.size.width * progress
            ZStack(alignment: .leading) {
                Capsule().fill(RetroColor.line).frame(height: 5)
                Capsule().fill(fill).frame(width: max(x, 5), height: 5)
                Circle()
                    .fill(marker)
                    .overlay(Circle().strokeBorder(RetroColor.background, lineWidth: markerSize > 9 ? 2 : 1.5))
                    .frame(width: markerSize, height: markerSize)
                    .offset(x: min(max(x - markerSize / 2, 0), geo.size.width - markerSize))
            }
        }
        .frame(height: markerSize)
        .padding(.vertical, -(markerSize - 5) / 2) // the track is 5 pt; the marker overhangs it
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((progress * 100).rounded())) percent"))
    }
}

/// Progress bar with start, current and end labels underneath (Overview, Survival Kit).
public struct LabeledProgress: View {
    let progress: Double
    let start: String
    let current: String
    let end: String
    let fill: Color
    let currentColor: Color

    public init(progress: Double, start: String, current: String, end: String, fill: Color = RetroColor.pink, currentColor: Color = RetroColor.pink) {
        self.progress = progress
        self.start = start
        self.current = current
        self.end = end
        self.fill = fill
        self.currentColor = currentColor
    }

    public var body: some View {
        VStack(spacing: 7) {
            CycleProgressBar(progress: progress, fill: fill)
            MarkerLabels(progress: progress, start: start, current: current, end: end, currentColor: currentColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(current), between \(start.lowercased()) and \(end.lowercased())")
        .accessibilityValue("\(Int((min(max(progress, 0), 1) * 100).rounded())) percent")
    }
}

/// Start and end labels at the bar's ends, with a current label between them.
/// With `followsMarker` (a position like "YOU ARE HERE") the current label sits under the marker;
/// near either end it stays inside the bar and takes the place of that end's label. Without it
/// (a count like "2 of 27 done") the current label is centred, as in Figma.
public struct MarkerLabels: View {
    let progress: Double
    let start: String
    let current: String
    let end: String
    let currentColor: Color
    let followsMarker: Bool
    @State private var widths: [Int: CGFloat] = [:]

    public init(progress: Double, start: String, current: String, end: String, currentColor: Color, followsMarker: Bool = true) {
        self.progress = progress
        self.start = start
        self.current = current
        self.end = end
        self.currentColor = currentColor
        self.followsMarker = followsMarker
    }

    public var body: some View {
        if followsMarker {
            following
        } else {
            // One row where it fits; with large text, the count on its own line above the ends.
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(start).foregroundStyle(RetroColor.textMuted)
                    Spacer(minLength: 8)
                    Text(current).foregroundStyle(currentColor)
                    Spacer(minLength: 8)
                    Text(end).foregroundStyle(RetroColor.textMuted)
                }
                .fixedSize(horizontal: true, vertical: false)
                VStack(spacing: 4) {
                    Text(current).foregroundStyle(currentColor)
                    HStack {
                        Text(start)
                        Spacer(minLength: 8)
                        Text(end)
                    }
                    .foregroundStyle(RetroColor.textMuted)
                    .minimumScaleFactor(0.7)
                }
            }
            .retroText(.monoSmall)
            .lineLimit(1)
        }
    }

    private var following: some View {
        Text(start) // sets the row height for the current text size
            .hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                GeometryReader { geo in
                    let width = geo.size.width
                    let currentWidth = widths[1] ?? 0
                    let x = min(max(width * min(max(progress, 0), 1) - currentWidth / 2, 0), width - currentWidth)
                    let gap: CGFloat = 8
                    let startHidden = x < (widths[0] ?? 0) + gap
                    let endHidden = x + currentWidth > width - (widths[2] ?? 0) - gap
                    ZStack(alignment: .topLeading) {
                        label(start, 0, RetroColor.textMuted).opacity(startHidden ? 0 : 1)
                        label(end, 2, RetroColor.textMuted)
                            .frame(width: width, alignment: .trailing)
                            .opacity(endHidden ? 0 : 1)
                        label(current, 1, currentColor).offset(x: x)
                    }
                }
            }
            .retroText(.monoSmall)
            .lineLimit(1)
    }

    private func label(_ text: String, _ index: Int, _ color: Color) -> some View {
        Text(text)
            .foregroundStyle(color)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { widths[index] = $0 }
    }
}

// MARK: - Checklist

/// Survival Kit row checkbox.
public struct TaskCheckbox: View {
    public enum State { case open, done, locked }

    let state: State

    public init(_ state: State) {
        self.state = state
    }

    public var body: some View {
        // All three states share an 18 pt slot and read at the same size: a 16 pt box, or a lock
        // glyph of the same visible height.
        ZStack {
            switch state {
            case .open:
                RoundedRectangle(cornerRadius: RetroMetrics.Radius.checkbox)
                    .strokeBorder(RetroColor.textMuted, lineWidth: 1.25)
                    .frame(width: 16, height: 16)
            case .done:
                RoundedRectangle(cornerRadius: RetroMetrics.Radius.checkbox)
                    .fill(RetroColor.pink)
                    .frame(width: 16, height: 16)
                Image(systemName: RetroSymbol.check).font(.system(size: 10, weight: .heavy)).foregroundStyle(RetroColor.text)
            case .locked:
                Image(systemName: RetroSymbol.lock).font(.system(size: 15, weight: .medium)).foregroundStyle(RetroColor.textMuted)
            }
        }
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
    }
}
