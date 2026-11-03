import SwiftUI

// MARK: - Header

/// Top bar on every main screen: logo, wordmark, tagline, then share, notifications and settings.
public struct AppHeader: View {
    let onShare: () -> Void
    let onNotifications: () -> Void
    let onSettings: () -> Void

    public init(onShare: @escaping () -> Void, onNotifications: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.onShare = onShare
        self.onNotifications = onNotifications
        self.onSettings = onSettings
    }

    public var body: some View {
        // Figma's 430 pt layout first; narrower phones get slightly smaller buttons
        // and, on the smallest, a gently scaled wordmark rather than a wrapped one.
        ViewThatFits(in: .horizontal) {
            row(buttonSize: RetroMetrics.headerButtonSize, spacing: 13)
            row(buttonSize: 36, spacing: 8)
        }
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
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            HStack(spacing: spacing) {
                HeaderIconButton(systemImage: RetroSymbol.share, label: "Share Retrograde", size: buttonSize, action: onShare)
                HeaderIconButton(systemImage: RetroSymbol.notifications, label: "Notifications", size: buttonSize, action: onNotifications)
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
    let action: () -> Void

    public init(systemImage: String, label: String, size: CGFloat = RetroMetrics.headerButtonSize, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(RetroColor.text)
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(RetroColor.line, lineWidth: 1))
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

    let title: String
    let systemImage: String?
    let layout: Layout
    let showsArrow: Bool
    let action: () -> Void

    public init(_ title: String, systemImage: String? = nil, layout: Layout = .center, showsArrow: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.layout = layout
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
                Spacer(minLength: 0)
                if showsArrow {
                    Image(systemName: RetroSymbol.forward).font(.system(size: 15, weight: .semibold))
                }
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: RetroMetrics.buttonHeight)
            .foregroundStyle(RetroColor.text)
            .background(RetroColor.pink, in: RoundedRectangle(cornerRadius: RetroMetrics.Radius.button))
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
            HStack(spacing: 8) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.custom("Inter-Bold", size: 13, relativeTo: .subheadline))
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(RetroColor.text)
            .overlay(RoundedRectangle(cornerRadius: RetroMetrics.Radius.button).strokeBorder(RetroColor.text, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackStyle())
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
                if let systemImage { Image(systemName: systemImage).font(.system(size: 9, weight: .bold)) }
                Text(title).retroText(.monoBold)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .overlay(Capsule().strokeBorder(.white, lineWidth: 1))
            .contentShape(Capsule())
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
            .font(.custom("SpaceMono-Bold", size: 8, relativeTo: .caption2))
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

    public init(progress: Double, fill: Color = RetroColor.pink, marker: Color = RetroColor.yellow) {
        self.progress = min(max(progress, 0), 1)
        self.fill = fill
        self.marker = marker
    }

    public var body: some View {
        GeometryReader { geo in
            let x = geo.size.width * progress
            ZStack(alignment: .leading) {
                Capsule().fill(RetroColor.line)
                Capsule().fill(fill).frame(width: max(x, 5))
                Circle()
                    .fill(marker)
                    .overlay(Circle().strokeBorder(RetroColor.background, lineWidth: 2))
                    .frame(width: 11, height: 11)
                    .offset(x: min(max(x - 5.5, 0), geo.size.width - 11))
            }
        }
        .frame(height: 11)
        .padding(.vertical, -3) // the track is 5 pt; the marker overhangs it
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
            HStack {
                Text(start).foregroundStyle(RetroColor.textMuted)
                Spacer()
                Text(current).foregroundStyle(currentColor)
                Spacer()
                Text(end).foregroundStyle(RetroColor.textMuted)
            }
            .retroText(.monoSmall)
        }
        .accessibilityElement(children: .combine)
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
        ZStack {
            switch state {
            case .open:
                RoundedRectangle(cornerRadius: RetroMetrics.Radius.checkbox).strokeBorder(RetroColor.textMuted, lineWidth: 1)
            case .done:
                RoundedRectangle(cornerRadius: RetroMetrics.Radius.checkbox).fill(RetroColor.pink)
                Image(systemName: RetroSymbol.check).font(.system(size: 9, weight: .heavy)).foregroundStyle(RetroColor.text)
            case .locked:
                Image(systemName: RetroSymbol.lock).font(.system(size: 10)).foregroundStyle(RetroColor.textMuted)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}
