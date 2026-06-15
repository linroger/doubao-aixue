//
//  MathText.swift
//  豆包爱学 — Design System
//
//  A lightweight, dependency-free, accessible math/formula renderer. Converts a
//  pragmatic subset of LaTeX-ish input into an AttributedString with Unicode
//  symbols, superscripts and subscripts. Good for inline solution steps and the
//  blackboard. (Not a full TeX engine; fractions render inline as a⁄b.)
//

import SwiftUI

public struct MathText: View {
    public var expression: String
    public var font: Font

    public init(_ expression: String, font: Font = .dbBody) {
        self.expression = expression
        self.font = font
    }

    public var body: some View {
        Text(MathText.attributed(from: expression, baseFont: font))
            .accessibilityLabel(MathText.spokenLabel(from: expression))
    }

    /// Build a styled AttributedString from a LaTeX-ish expression.
    public static func attributed(from raw: String, baseFont: Font = .dbBody) -> AttributedString {
        let normalized = replaceSymbols(in: raw)
        var result = AttributedString()
        var index = normalized.startIndex

        func appendPlain(_ s: Substring) {
            var run = AttributedString(String(s))
            run.font = baseFont
            result += run
        }

        while index < normalized.endIndex {
            let ch = normalized[index]
            if ch == "^" || ch == "_" {
                let isSuper = (ch == "^")
                let after = normalized.index(after: index)
                guard after < normalized.endIndex else { appendPlain(normalized[index..<normalized.endIndex]); break }
                let (token, nextIndex) = grabGroup(in: normalized, from: after)
                var run = AttributedString(token)
                run.font = baseFont
                run.baselineOffset = isSuper ? 6 : -4
                // Visually shrink scripts.
                run.font = .system(.footnote, design: .rounded)
                run.baselineOffset = isSuper ? 6 : -4
                result += run
                index = nextIndex
            } else {
                appendPlain(normalized[index..<normalized.index(after: index)])
                index = normalized.index(after: index)
            }
        }
        return result
    }

    /// VoiceOver-friendly plain reading of the expression.
    public static func spokenLabel(from raw: String) -> String {
        replaceSymbols(in: raw)
            .replacingOccurrences(of: "^", with: " 的 ")
            .replacingOccurrences(of: "_", with: " 下标 ")
            .replacingOccurrences(of: "{", with: "")
            .replacingOccurrences(of: "}", with: "")
    }

    // Grab either a `{...}` group or a single character following ^ or _.
    private static func grabGroup(in s: String, from start: String.Index) -> (String, String.Index) {
        if s[start] == "{" {
            var depth = 0
            var i = start
            var content = ""
            while i < s.endIndex {
                let c = s[i]
                if c == "{" { depth += 1; if depth == 1 { i = s.index(after: i); continue } }
                if c == "}" { depth -= 1; if depth == 0 { return (content, s.index(after: i)) } }
                content.append(c)
                i = s.index(after: i)
            }
            return (content, s.endIndex)
        } else {
            return (String(s[start]), s.index(after: start))
        }
    }

    private static func replaceSymbols(in raw: String) -> String {
        var s = raw
        let map: [String: String] = [
            "\\times": "×", "\\div": "÷", "\\pm": "±", "\\mp": "∓",
            "\\leq": "≤", "\\geq": "≥", "\\neq": "≠", "\\approx": "≈",
            "\\cdot": "·", "\\ldots": "…", "\\infty": "∞", "\\angle": "∠",
            "\\Rightarrow": "⇒", "\\rightarrow": "→", "\\Leftrightarrow": "⇔",
            "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\theta": "θ",
            "\\pi": "π", "\\lambda": "λ", "\\mu": "μ", "\\sigma": "σ",
            "\\Delta": "Δ", "\\sum": "∑", "\\sqrt": "√", "\\degree": "°",
            "\\circ": "∘", "\\parallel": "∥", "\\perp": "⊥", "\\in": "∈",
        ]
        for (k, v) in map { s = s.replacingOccurrences(of: k, with: v) }
        // \frac{a}{b} -> a⁄b (with parens if multi-token)
        s = reduceFractions(in: s)
        return s
    }

    private static func reduceFractions(in input: String) -> String {
        var s = input
        while let range = s.range(of: "\\frac{") {
            let afterCmd = range.upperBound
            guard let (num, idxAfterNum) = balanced(s, from: s.index(before: afterCmd)) else { break }
            guard idxAfterNum < s.endIndex, s[idxAfterNum] == "{" else { break }
            guard let (den, idxAfterDen) = balanced(s, from: idxAfterNum) else { break }
            let numStr = num.count > 1 ? "(\(num))" : num
            let denStr = den.count > 1 ? "(\(den))" : den
            s.replaceSubrange(range.lowerBound..<idxAfterDen, with: "\(numStr)⁄\(denStr)")
        }
        return s
    }

    // Parse a `{...}` group starting at an opening brace index; return content + index after closing.
    private static func balanced(_ s: String, from openBrace: String.Index) -> (String, String.Index)? {
        guard openBrace < s.endIndex, s[openBrace] == "{" else { return nil }
        var depth = 0
        var i = openBrace
        var content = ""
        while i < s.endIndex {
            let c = s[i]
            if c == "{" { depth += 1; if depth == 1 { i = s.index(after: i); continue } }
            if c == "}" { depth -= 1; if depth == 0 { return (content, s.index(after: i)) } }
            content.append(c)
            i = s.index(after: i)
        }
        return nil
    }
}

#Preview("MathText") {
    VStack(alignment: .leading, spacing: 14) {
        MathText("x^2 + 2x + 1 = 0", font: .dbTitle3)
        MathText("v = \\frac{s}{t} \\times 2", font: .dbBody)
        MathText("\\Delta = b^2 - 4ac \\geq 0", font: .dbBody)
        MathText("\\pi r^2 \\approx 3.14 \\cdot r^2", font: .dbBody)
    }
    .padding().background(Color.dbBackground)
}
