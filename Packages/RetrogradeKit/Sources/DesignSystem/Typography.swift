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

/// The type ramp used across the Figma screens. Sizes are Figma's; they scale with Dynamic Type.
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
    /// Inter SemiBold 13 — row titles.
    case bodyStrong
    /// Inter Regular 13 — task instructions.
    case bodyLarge
    /// Inter Regular 12 — body copy.
    case body
    /// Inter ExtraBold 12 — emphasised word inside body copy ("Mercury").
    case bodyHeavy
    /// Inter Regular 10 — fine print (the "reflection prompt, not a prediction" note).
    case finePrint
    /// Inter Regular 15 — journal prompts ("Today I’m feeling ___.").
    case prompt
    /// Space Mono 36 — short countdowns ("00:10").
    case timer
    /// Space Mono 27 — the breathing ring's countdown ("01:00").
    case timerCompact
    /// Archivo Black 21 — breath lengths ("4 seconds").
    case breathCount
    /// Space Mono 8 — captions under timers and examples ("FOR EXAMPLE").
    case monoTiny
    /// Inter SemiBold 16 — paywall prices ("$19.99").
    case price
    /// Inter Regular 11 — purchase terms under the paywall button.
    case disclosure
    /// Space Mono 11 — countdown label, step numbers.
    case monoLarge
    /// Space Mono 10 — tab labels, eyebrows.
    case mono
    /// Space Mono Bold 10 — pill labels.
    case monoBold
    /// Space Mono 9 — tagline, phase labels, category labels.
    case monoSmall

    var postScriptName: String {
        switch self {
        case .display, .hero, .title, .section, .cardTitle, .breathCount: "ArchivoBlack-Regular"
        case .button: "Inter-Bold"
        case .bodyStrong, .price: "Inter-SemiBold"
        case .bodyLarge, .body, .finePrint, .prompt, .disclosure: "Inter-Regular"
        case .bodyHeavy: "Inter-ExtraBold"
        case .monoLarge, .mono, .monoSmall, .timer, .timerCompact, .monoTiny: "SpaceMono-Regular"
        case .monoBold: "SpaceMono-Bold"
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
        case .cardTitle, .price: 16
        case .button: 14
        case .prompt: 15
        case .bodyStrong, .bodyLarge: 13
        case .body, .bodyHeavy: 12
        case .monoLarge, .disclosure: 11
        case .mono, .monoBold, .finePrint: 10
        case .monoSmall: 9
        case .monoTiny: 8
        }
    }

    /// The system style it scales alongside when the person changes text size.
    var scalesLike: Font.TextStyle {
        switch self {
        case .display, .timer: .largeTitle
        case .timerCompact, .breathCount: .title2
        case .prompt: .body
        case .monoTiny: .caption2
        case .hero: .title
        case .title: .title2
        case .section: .title3
        case .cardTitle, .price: .headline
        case .button: .body
        case .bodyStrong, .bodyLarge: .subheadline
        case .body, .bodyHeavy, .monoLarge: .footnote
        case .mono, .monoBold: .caption
        case .finePrint: .caption2
        case .disclosure: .caption
        case .monoSmall: .caption2
        }
    }

    /// Extra space between lines where Figma sets a taller line height (body copy is 135 %).
    var lineSpacing: CGFloat {
        switch self {
        case .body, .bodyHeavy: 2
        case .bodyLarge: 3
        case .prompt: 4
        case .disclosure: 3
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
