import SwiftUI

/// Colours from the Figma file (it has no shared styles, so these are its raw values).
public enum RetroColor {
    public static let background = Color(hex: 0x130D25)
    /// Cards, sheets.
    public static let surface = Color(hex: 0x1D1331)
    /// Calendar and day-detail panels.
    public static let surfaceRaised = Color(hex: 0x201431)
    /// Icon chips.
    public static let chip = Color(hex: 0x2B1B43)
    /// Calendar day cells.
    public static let cell = Color(hex: 0x2B1E3C)
    /// Borders, dividers, progress tracks.
    public static let line = Color(hex: 0x49305F)
    public static let text = Color(hex: 0xF5F0FF)
    public static let textMuted = Color(hex: 0xB8A9CD)
    public static let pink = Color(hex: 0xFF2D87)
    /// Retrograde markers and inactive intensity bars.
    public static let pinkSoft = Color(hex: 0xEC82B1)
    /// Shadow-period markers.
    public static let mauve = Color(hex: 0xC997C6)
    /// Countdown number, "today", progress marker, badges.
    public static let yellow = Color(hex: 0xFFD23D)
    /// Selected cards and highlighted panels.
    public static let wine = Color(hex: 0x461736)
    /// Empty intensity segments.
    public static let dim = Color(hex: 0x49334F)
    /// "Calm" intensity level.
    public static let calm = Color(hex: 0xA89CBE)
}

public enum RetroMetrics {
    /// Side margin of every screen.
    public static let screenPadding: CGFloat = 24
    public static let cardPadding: CGFloat = 16
    public static let sectionSpacing: CGFloat = 24
    public static let buttonHeight: CGFloat = 52
    public static let headerHeight: CGFloat = 62
    public static let headerButtonSize: CGFloat = 40
    public static let iconChipSize: CGFloat = 34

    public enum Radius {
        public static let checkbox: CGFloat = 4
        public static let cell: CGFloat = 6
        public static let chip: CGFloat = 8
        public static let button: CGFloat = 8
        public static let card: CGFloat = 12
        public static let panel: CGFloat = 16
        public static let sheet: CGFloat = 28
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
