import SwiftUI

/// A shape from SVG path data (M, L, H, V, C, Z — absolute or relative), as exported by Figma,
/// scaled to fit its frame.
struct SVGPath: Shape {
    let data: String
    let viewBox: CGSize

    func path(in rect: CGRect) -> Path {
        Self.parse(data).applying(Self.fit(viewBox, in: rect))
    }

    static func fit(_ box: CGSize, in rect: CGRect) -> CGAffineTransform {
        let scale = min(rect.width / box.width, rect.height / box.height)
        return CGAffineTransform(translationX: rect.midX - box.width * scale / 2, y: rect.midY - box.height * scale / 2)
            .scaledBy(x: scale, y: scale)
    }

    static func parse(_ data: String) -> Path {
        var path = Path()
        var tokens = Tokens(data)
        var command: Character = "M"
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero

        while let next = tokens.peekCommand() ?? (tokens.hasNumber ? command : nil) {
            if tokens.peekCommand() != nil { tokens.skipCommand() }
            command = next
            let relative = command.isLowercase
            func point() -> CGPoint {
                let p = CGPoint(x: tokens.number(), y: tokens.number())
                return relative ? CGPoint(x: current.x + p.x, y: current.y + p.y) : p
            }
            switch command.uppercased() {
            case "M":
                current = point()
                subpathStart = current
                path.move(to: current)
                command = relative ? "l" : "L" // further pairs are line-tos
            case "L":
                current = point()
                path.addLine(to: current)
            case "H":
                let x = tokens.number()
                current.x = relative ? current.x + x : x
                path.addLine(to: current)
            case "V":
                let y = tokens.number()
                current.y = relative ? current.y + y : y
                path.addLine(to: current)
            case "C":
                let c1 = point(), c2 = point(), end = point()
                path.addCurve(to: end, control1: c1, control2: c2)
                current = end
            case "Z":
                path.closeSubpath()
                current = subpathStart
            default:
                return path // unsupported command: stop rather than draw garbage
            }
        }
        return path
    }

    private struct Tokens {
        private let chars: [Character]
        private var index = 0

        init(_ s: String) {
            chars = Array(s)
        }

        private mutating func skipSeparators() {
            while index < chars.count, chars[index] == " " || chars[index] == "," || chars[index].isNewline { index += 1 }
        }

        mutating func peekCommand() -> Character? {
            skipSeparators()
            guard index < chars.count, chars[index].isLetter, chars[index] != "e" else { return nil }
            return chars[index]
        }

        mutating func skipCommand() { index += 1 }

        var hasNumber: Bool {
            var copy = self
            copy.skipSeparators()
            guard copy.index < copy.chars.count else { return false }
            let c = copy.chars[copy.index]
            return c.isNumber || c == "-" || c == "." || c == "+"
        }

        mutating func number() -> CGFloat {
            skipSeparators()
            let start = index
            var seenDot = false
            if index < chars.count, chars[index] == "-" || chars[index] == "+" { index += 1 }
            while index < chars.count {
                let c = chars[index]
                if c.isNumber {
                    index += 1
                } else if c == ".", !seenDot {
                    seenDot = true
                    index += 1
                } else if c == "e" || c == "E" {
                    index += 1
                    if index < chars.count, chars[index] == "-" || chars[index] == "+" { index += 1 }
                } else {
                    break
                }
            }
            return CGFloat(Double(String(chars[start..<index])) ?? 0)
        }
    }
}

/// An SVG path outlined with round caps and joins, as a fillable shape so its line
/// width scales with the frame like the Figma vector does.
struct StrokedSVGPath: Shape {
    let data: String
    let viewBox: CGSize
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        let transform = SVGPath.fit(viewBox, in: rect)
        return SVGPath.parse(data)
            .strokedPath(StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .applying(transform)
    }
}
