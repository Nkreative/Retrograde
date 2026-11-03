import SwiftUI

/// SF Symbols standing in for Figma's standard interface icons.
public enum RetroSymbol {
    public static let share = "square.and.arrow.up"
    public static let notifications = "bell"
    public static let notificationsOff = "bell.slash.fill"
    public static let settings = "gearshape"
    public static let close = "xmark"
    public static let back = "arrow.left"
    public static let forward = "arrow.right"
    public static let chevronRight = "chevron.right"
    public static let chevronUp = "chevron.up"
    public static let chevronDown = "chevron.down"
    public static let add = "plus"
    public static let check = "checkmark"
    public static let checkCircle = "checkmark.circle"
    public static let lock = "lock.fill"
    public static let unlock = "lock.open.fill"
    public static let star = "star.fill"
    public static let copy = "doc.on.doc"
    public static let externalLink = "arrow.up.right.square"
    public static let play = "play.fill"
    public static let pause = "pause.fill"
    public static let restart = "arrow.counterclockwise"
    // Topic icons (Overview tips, Survival Kit sections).
    public static let communication = "message"
    public static let techBackup = "laptopcomputer"
    public static let planning = "calendar"
    public static let journal = "pencil.line"
    public static let firstAid = "cross.case"
    public static let moon = "moon.fill"
    public static let heart = "heart.fill"
}

/// Retrograde's own line icons, drawn from the Figma vectors so the tab bar matches exactly.
public enum RetroGlyph: CaseIterable, Sendable {
    /// Overview tab: planet on an orbit.
    case orbit
    /// Survival Kit tab: first-aid kit.
    case survivalKit
    /// Calendar tab.
    case calendar

    var viewBox: CGSize {
        switch self {
        case .orbit, .calendar: CGSize(width: 21, height: 21)
        case .survivalKit: CGSize(width: 19, height: 21)
        }
    }

    var lineWidth: CGFloat {
        switch self {
        case .orbit: 1.7
        case .survivalKit: 1.8
        case .calendar: 2
        }
    }

    var pathData: String {
        switch self {
        case .orbit:
            "M17.7973 5.67395C18.7413 7.10077 19.2463 8.77302 19.2498 10.4838C19.2533 12.1946 18.7553 13.869 17.8172 15.2997C16.8791 16.7304 15.5422 17.8547 13.9719 18.5336C12.4015 19.2124 10.6666 19.416 8.98169 19.1192M3.20116 15.3263C2.2572 13.8991 1.75242 12.2265 1.74928 10.5153C1.74614 8.80421 2.24478 7.12972 3.18349 5.69907C4.12221 4.26842 5.45979 3.1444 7.03074 2.4661C8.60168 1.78781 10.337 1.58501 12.022 1.8828M13.1243 10.5001C13.1243 11.9499 11.949 13.1251 10.4993 13.1251C9.04952 13.1251 7.87427 11.9499 7.87427 10.5001C7.87427 9.05037 9.04952 7.87512 10.4993 7.87512C11.949 7.87512 13.1243 9.05037 13.1243 10.5001ZM18.3743 4.37512C18.3743 5.34162 17.5908 6.12512 16.6243 6.12512C15.6578 6.12512 14.8743 5.34162 14.8743 4.37512C14.8743 3.40862 15.6578 2.62512 16.6243 2.62512C17.5908 2.62512 18.3743 3.40862 18.3743 4.37512ZM6.12427 16.6251C6.12427 17.5916 5.34077 18.3751 4.37427 18.3751C3.40777 18.3751 2.62427 17.5916 2.62427 16.6251C2.62427 15.6586 3.40777 14.8751 4.37427 14.8751C5.34077 14.8751 6.12427 15.6586 6.12427 16.6251Z"
        case .survivalKit:
            "M6.33233 7.00032V3.49962C6.33233 2.33272 6.86028 1.74927 7.91617 1.74927H11.0839C12.1397 1.74927 12.6677 2.33272 12.6677 3.49962V7.00032M9.50001 10.501V15.7521M7.12425 13.1265H11.8758M3.16465 7.00032H15.8354C16.8913 7.00032 17.4192 7.58377 17.4192 8.75067V17.5024C17.4192 18.6693 16.8913 19.2528 15.8354 19.2528H3.16465C2.10876 19.2528 1.58081 18.6693 1.58081 17.5024V8.75067C1.58081 7.58377 2.10876 7.00032 3.16465 7.00032Z"
        case .calendar:
            "M7 1.74927V5.24955M14 1.74927V5.24955M2.625 8.74983H18.375M4.375 3.49941H16.625C17.5915 3.49941 18.375 4.28297 18.375 5.24955V17.5005C18.375 18.4671 17.5915 19.2507 16.625 19.2507H4.375C3.4085 19.2507 2.625 18.4671 2.625 17.5005V5.24955C2.625 4.28297 3.4085 3.49941 4.375 3.49941Z"
        }
    }
}

/// Draws a `RetroGlyph` in the current foreground style. Size it with `.frame(height:)`.
public struct RetroGlyphView: View {
    let glyph: RetroGlyph

    public init(_ glyph: RetroGlyph) {
        self.glyph = glyph
    }

    public var body: some View {
        StrokedSVGPath(data: glyph.pathData, viewBox: glyph.viewBox, lineWidth: glyph.lineWidth)
            .aspectRatio(glyph.viewBox, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// The Retrograde logo: pink disc with the white orbit mark.
public struct BrandMark: View {
    let size: CGFloat

    public init(size: CGFloat = 34) {
        self.size = size
    }

    public var body: some View {
        let box = CGSize(width: 34, height: 34)
        ZStack {
            Circle().fill(RetroColor.pink)
            StrokedSVGPath(
                data: "M19.1874 6.9375C13.2811 9.46875 7.37486 16.7812 7.09361 22.4062C6.81236 27.4688 11.0311 28.875 16.3749 26.0625C22.8436 22.6875 28.7499 15.0938 27.0624 10.875C26.7811 10.0312 26.2186 9.46875 25.3749 8.90625M25.6562 12.5625L25.375 8.90625L29.0312 9.1875M16.375 21.2812C18.5496 21.2812 20.3125 19.5184 20.3125 17.3438C20.3125 15.1691 18.5496 13.4062 16.375 13.4062C14.2004 13.4062 12.4375 15.1691 12.4375 17.3438C12.4375 19.5184 14.2004 21.2812 16.375 21.2812Z",
                viewBox: box, lineWidth: 1.40625
            )
            .fill(.white)
            SVGPath(data: "M22.2812 7.35938C22.8249 7.35938 23.2656 6.91866 23.2656 6.375C23.2656 5.83134 22.8249 5.39062 22.2812 5.39062C21.7376 5.39062 21.2969 5.83134 21.2969 6.375C21.2969 6.91866 21.7376 7.35938 22.2812 7.35938Z", viewBox: box)
                .fill(.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Retrograde")
    }
}
