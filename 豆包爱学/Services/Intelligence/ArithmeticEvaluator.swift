//
//  ArithmeticEvaluator.swift
//  豆包爱学
//
//  A small, dependency-free arithmetic evaluator (+ - × ÷ * / and parentheses,
//  integers & decimals). Lets 口算批改 / solve genuinely compute answers.
//

import Foundation

public nonisolated enum ArithmeticEvaluator {

    /// Evaluate an arithmetic expression string. Returns nil if it isn't a
    /// well-formed numeric expression.
    public static func evaluate(_ raw: String) -> Double? {
        let normalized = raw
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "x", with: "*")
            .replacingOccurrences(of: "X", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "＋", with: "+")
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        // Reject anything that isn't digits/operators/parens/decimal.
        let allowed = CharacterSet(charactersIn: "0123456789.+-*/()")
        guard normalized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        // Must contain at least one operator to count as an "expression".
        guard normalized.contains(where: { "+-*/".contains($0) }) || Double(normalized) != nil else { return nil }

        var parser = Parser(normalized)
        guard let result = parser.parseExpression(), parser.isAtEnd else { return nil }
        return result.isFinite ? result : nil
    }

    /// Format a numeric result trimming trailing zeros.
    public static func format(_ value: Double) -> String {
        if value.rounded() == value && abs(value) < 1e15 {
            return String(Int(value))
        }
        return String(format: "%g", value)
    }

    // Recursive-descent parser.
    private struct Parser {
        let chars: [Character]
        var index = 0
        init(_ s: String) { chars = Array(s) }
        var isAtEnd: Bool { index >= chars.count }
        func peek() -> Character? { index < chars.count ? chars[index] : nil }

        mutating func parseExpression() -> Double? {
            guard var value = parseTerm() else { return nil }
            while let op = peek(), op == "+" || op == "-" {
                index += 1
                guard let rhs = parseTerm() else { return nil }
                value = (op == "+") ? value + rhs : value - rhs
            }
            return value
        }

        mutating func parseTerm() -> Double? {
            guard var value = parseFactor() else { return nil }
            while let op = peek(), op == "*" || op == "/" {
                index += 1
                guard let rhs = parseFactor() else { return nil }
                if op == "/" { if rhs == 0 { return nil }; value /= rhs } else { value *= rhs }
            }
            return value
        }

        mutating func parseFactor() -> Double? {
            guard let c = peek() else { return nil }
            if c == "(" {
                index += 1
                guard let v = parseExpression() else { return nil }
                guard peek() == ")" else { return nil }
                index += 1
                return v
            }
            if c == "-" { index += 1; guard let v = parseFactor() else { return nil }; return -v }
            if c == "+" { index += 1; return parseFactor() }
            return parseNumber()
        }

        mutating func parseNumber() -> Double? {
            var s = ""
            while let c = peek(), c.isNumber || c == "." {
                s.append(c); index += 1
            }
            return Double(s)
        }
    }
}
