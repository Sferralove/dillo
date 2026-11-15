import CoreGraphics
import Foundation

/// Parser minimo per l'attributo `d` dei tracciati SVG (M L H V C S Q Z, assoluti e relativi).
/// Serve a usare i vettoriali esportati da Affinity senza librerie esterne.
nonisolated enum SVGPath {
    static func parse(_ d: String) -> CGPath {
        let path = CGMutablePath()
        var tokens = tokenize(d)[...]
        var current = CGPoint.zero, start = CGPoint.zero, lastControl: CGPoint?
        var command: Character = "M"

        func number() -> CGFloat {
            guard case .number(let v)? = tokens.first else { return 0 }
            tokens.removeFirst()
            return v
        }

        while !tokens.isEmpty {
            if case .command(let c)? = tokens.first { command = c; tokens.removeFirst() }
            let rel = command.isLowercase
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { rel ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y) }
            switch command.lowercased().first! {
            case "m":
                current = pt(number(), number()); start = current
                path.move(to: current)
                command = rel ? "l" : "L"           // coppie successive = lineTo
                lastControl = nil
            case "l":
                current = pt(number(), number()); path.addLine(to: current); lastControl = nil
            case "h":
                let x = number(); current = CGPoint(x: rel ? current.x + x : x, y: current.y); path.addLine(to: current); lastControl = nil
            case "v":
                let y = number(); current = CGPoint(x: current.x, y: rel ? current.y + y : y); path.addLine(to: current); lastControl = nil
            case "c":
                let c1 = pt(number(), number()), c2 = pt(number(), number()), end = pt(number(), number())
                path.addCurve(to: end, control1: c1, control2: c2); current = end; lastControl = c2
            case "s":
                let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
                let c2 = pt(number(), number()), end = pt(number(), number())
                path.addCurve(to: end, control1: c1, control2: c2); current = end; lastControl = c2
            case "q":
                let c = pt(number(), number()), end = pt(number(), number())
                path.addQuadCurve(to: end, control: c); current = end; lastControl = nil
            case "z":
                path.closeSubpath(); current = start; lastControl = nil
                continue
            default:
                _ = number()
            }
        }
        return path
    }

    private enum Token { case command(Character), number(CGFloat) }

    private static func tokenize(_ d: String) -> [Token] {
        var tokens: [Token] = []
        var buffer = ""
        func flush() { if let v = Double(buffer) { tokens.append(.number(CGFloat(v))) }; buffer = "" }
        var prev: Character = " "
        for ch in d {
            if ch.isLetter && ch != "e" && ch != "E" {
                flush(); tokens.append(.command(ch))
            } else if ch == "," || ch.isWhitespace {
                flush()
            } else if ch == "-" && !buffer.isEmpty && prev != "e" && prev != "E" {
                flush(); buffer = "-"
            } else if ch == "." && buffer.contains(".") && prev != "e" && prev != "E" {
                flush(); buffer = "."
            } else {
                buffer.append(ch)
            }
            prev = ch
        }
        flush()
        return tokens
    }
}
