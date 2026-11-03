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
