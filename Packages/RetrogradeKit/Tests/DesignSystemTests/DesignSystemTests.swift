import CoreText
import SwiftUI
import Testing
@testable import DesignSystem

@Suite struct FontTests {
    @Test(arguments: RetroFonts.postScriptNames)
    func bundledFontRegistersUnderItsPostScriptName(_ name: String) {
        RetroFonts.register()
        let font = CTFontCreateWithName(name as CFString, 12, nil)
        // CoreText silently falls back to another font when a name is unknown.
        #expect(CTFontCopyPostScriptName(font) as String == name)
    }

    @Test func everyTextStyleUsesABundledFont() {
        for style in RetroTextStyle.allCases {
            #expect(RetroFonts.postScriptNames.contains(style.postScriptName), "\(style)")
        }
    }
}

/// The M12.1 readability floor, and the widget's sizes held where M14.5 approved them.
@Suite struct TypeScaleTests {
    static let widgetStyles: [RetroTextStyle: CGFloat] = [
        .widgetTitle: 17, .widgetTitleSmall: 13, .widgetPhase: 11, .widgetPhaseSmall: 10, .widgetCountdown: 32, .widgetCountdownSmall: 34,
        .widgetUnit: 12, .widgetCaption: 11, .widgetLabel: 10, .widgetNote: 12,
    ]

    @Test func nothingIsTooSmallToRead() {
        for style in RetroTextStyle.allCases {
            #expect(style.size >= 10, "\(style)")
        }
        for style in [RetroTextStyle.body, .bodyStrong, .bodyHeavy] {
            #expect(style.size >= 15, "\(style)")
        }
        #expect(RetroTextStyle.bodyLarge.size == 16)
    }

    @Test func widgetStylesAreUnchanged() {
        for (style, size) in Self.widgetStyles {
            #expect(style.size == size, "\(style)")
        }
    }
}

@Suite struct SVGPathTests {
    @Test(arguments: RetroGlyph.allCases)
    func glyphFillsItsViewBox(_ glyph: RetroGlyph) {
        let bounds = SVGPath.parse(glyph.pathData).boundingRect
        #expect(bounds.minX >= 0 && bounds.minY >= 0)
        #expect(bounds.maxX <= glyph.viewBox.width && bounds.maxY <= glyph.viewBox.height)
        // Each Figma icon spans most of its 21 pt box.
        #expect(bounds.width > glyph.viewBox.width * 0.7)
        #expect(bounds.height > glyph.viewBox.height * 0.7)
    }

    @Test func parsesAbsoluteAndRelativeCommands() {
        let absolute = SVGPath.parse("M1 1H5V5H1Z").boundingRect
        #expect(absolute == CGRect(x: 1, y: 1, width: 4, height: 4))
        let relative = SVGPath.parse("m1 1h4v4h-4z").boundingRect
        #expect(relative == absolute)
        let implicitLines = SVGPath.parse("M0 0 10 0 10 10").boundingRect
        #expect(implicitLines == CGRect(x: 0, y: 0, width: 10, height: 10))
        let packed = SVGPath.parse("M0-1L.5.5").boundingRect
        #expect(packed == CGRect(x: 0, y: -1, width: 0.5, height: 1.5))
    }

    @Test func scalesToItsFrame() {
        let path = SVGPath(data: "M0 0H21V21H0Z", viewBox: CGSize(width: 21, height: 21)).path(in: CGRect(x: 0, y: 0, width: 42, height: 42))
        #expect(path.boundingRect == CGRect(x: 0, y: 0, width: 42, height: 42))
    }
}

/// Labels under the progress bars: ends at the edges, the count centred on the full width.
@Suite struct SpreadLabelsTests {
    @Test func oneLineWhenTheCentreLabelClearsBothEnds() {
        let sizes = [CGSize(width: 70, height: 13), CGSize(width: 90, height: 13), CGSize(width: 40, height: 13)]
        #expect(SpreadLabels.fitsOnOneLine(sizes, width: 342, gap: 8))
    }

    @Test func centreIsTheFullWidthsCentreNotTheGroupsCentre() {
        // A long left label and a short right one: centring the group would fit, centring on the
        // width doesn't, so the count moves to its own line rather than drifting off-centre.
        let sizes = [CGSize(width: 140, height: 13), CGSize(width: 90, height: 13), CGSize(width: 20, height: 13)]
        #expect(!SpreadLabels.fitsOnOneLine(sizes, width: 342, gap: 8))
    }

    @Test func largeTextStacks() {
        let sizes = [CGSize(width: 150, height: 30), CGSize(width: 200, height: 30), CGSize(width: 100, height: 30)]
        #expect(!SpreadLabels.fitsOnOneLine(sizes, width: 342, gap: 8))
    }
}
