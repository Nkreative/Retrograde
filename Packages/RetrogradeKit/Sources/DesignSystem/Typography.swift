import CoreText
import SwiftUI

/// Registers the bundled fonts (Archivo Black, Space Mono, Inter — all SIL Open Font License).
/// Call once at launch; also safe from previews and widgets.
public enum RetroFonts {
    public static let postScriptNames = [
        "ArchivoBlack-Regular", "SpaceMono-Regular", "SpaceMono-Bold", "Inter-Regular", "Inter-SemiBold", "Inter-Bold",
        "Inter-ExtraBold",
    ]

    public static func register() { _ = registration }

    private static let registration: Void = {
        for name in postScriptNames {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts") else {
                assertionFailure("Missing font \(name)")
                continue
            }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
}

/// The type ramp. Headings, numbers and buttons keep Figma's sizes; body copy and small labels
/// were raised after testing on an iPhone (M12.1): nothing in the app is under 10 pt, body copy
/// is 15 pt. Everything scales with Dynamic Type. The widget has its own pinned styles so app
/// changes never move it.
public enum RetroTextStyle: CaseIterable, Sendable {
    /// Archivo Black 32 — countdown number.
    case display
    /// Archivo Black 30 — hero headline ("A LITTLE CHAOS.").
    case hero
    /// Archivo Black 20 — wordmark, sheet titles.
    case title
    /// Archivo Black 19 — section titles, selected date.
    case section
    /// Archivo Black 16 — card and task titles.
    case cardTitle
    /// Inter Bold 14 — buttons.
    case button
    /// Inter SemiBold 15 — row titles.
    case bodyStrong
    /// Inter Regular 16 — task instructions, the day's habit.
    case bodyLarge
    /// Inter Regular 15 — body copy.
    case body
    /// Inter ExtraBold 15 — emphasised word inside body copy ("Mercury").
    case bodyHeavy
    /// Inter Regular 12 — fine print (the "reflection prompt, not a prediction" note).
    case finePrint
    /// Inter Regular 15 — journal prompts ("Today I’m feeling ___.").
    case prompt
    /// Space Mono 36 — short countdowns ("00:10").
    case timer
    /// Space Mono 27 — the breathing ring's countdown ("01:00").
    case timerCompact
    /// Archivo Black 21 — breath lengths ("4 seconds").
    case breathCount
    /// Space Mono 16 — calendar day numbers.
    case monoNumber
    /// Space Mono Bold 16 — the selected calendar day's number.
    case monoNumberBold
    /// Space Mono 10 — the smallest captions: calendar cell markers, scale labels ("FOR EXAMPLE").
    case monoTiny
    /// Inter SemiBold 16 — paywall prices ("$19.99").
    case price
    /// Inter Regular 12 — purchase terms under the paywall button.
    case disclosure
    /// Space Mono 13 — countdown label, step numbers.
    case monoLarge
    /// Space Mono 12 — tab labels, eyebrows.
    case mono
    /// Space Mono Bold 11 — pill and badge labels.
    case monoBold
    /// Space Mono 11 — tagline, phase labels, category labels.
    case monoSmall
    /// Widget only — Space Mono 13, the countdown line ("days to exhale").
    case monoBody
    /// Widget only — Space Mono Bold 12, the phase label ("RETROGRADE").
    case monoLabel
    /// Widget only — Space Mono 11, the labels under the bar.
    case widgetCaption
    /// Widget only — Inter Regular 12, the no-data note.
    case widgetNote

    var postScriptName: String {
        switch self {
        case .display, .hero, .title, .section, .cardTitle, .breathCount: "ArchivoBlack-Regular"
        case .button: "Inter-Bold"
        case .bodyStrong, .price: "Inter-SemiBold"
        case .bodyLarge, .body, .finePrint, .prompt, .disclosure, .widgetNote: "Inter-Regular"
        case .bodyHeavy: "Inter-ExtraBold"
        case .monoBody, .monoLarge, .mono, .monoSmall, .timer, .timerCompact, .monoTiny, .monoNumber, .widgetCaption: "SpaceMono-Regular"
        case .monoLabel, .monoBold, .monoNumberBold: "SpaceMono-Bold"
        }
    }

    public var size: CGFloat {
        switch self {
        case .timer: 36
        case .display: 32
        case .hero: 30
        case .timerCompact: 27
        case .breathCount: 21
        case .title: 20
        case .section: 19
        case .cardTitle, .price, .bodyLarge, .monoNumber, .monoNumberBold: 16
        case .bodyStrong, .body, .bodyHeavy, .prompt: 15
        case .button: 14
        case .monoLarge, .monoBody: 13
        case .mono, .monoLabel, .finePrint, .disclosure, .widgetNote: 12
        case .monoBold, .monoSmall, .widgetCaption: 11
        case .monoTiny: 10
        }
    }

    /// The system style it scales alongside when the person changes text size.
    var scalesLike: Font.TextStyle {
        switch self {
        case .display, .timer: .largeTitle
        case .timerCompact, .breathCount: .title2
        case .prompt, .bodyLarge: .body
        case .hero: .title
        case .title: .title2
        case .section: .title3
        case .cardTitle, .price, .monoNumber, .monoNumberBold: .headline
        case .button: .body
        case .bodyStrong, .body, .bodyHeavy, .monoBody: .subheadline
        case .monoLarge, .monoLabel, .widgetCaption, .widgetNote: .footnote
        case .mono, .monoBold, .disclosure, .finePrint: .caption
        case .monoSmall, .monoTiny: .caption2
        }
    }

    /// Extra space between lines: body copy runs at about 135 % line height, which reads more
    /// easily than the font's own.
    var lineSpacing: CGFloat {
        switch self {
        case .body, .bodyHeavy, .bodyStrong: 3
        case .bodyLarge, .prompt: 4
        case .disclosure, .finePrint: 2
        case .widgetNote: 2
        default: 0
        }
    }

    public var font: Font { .custom(postScriptName, size: size, relativeTo: scalesLike) }
}

public extension View {
    func retroText(_ style: RetroTextStyle) -> some View {
        font(style.font).lineSpacing(style.lineSpacing)
    }
}
