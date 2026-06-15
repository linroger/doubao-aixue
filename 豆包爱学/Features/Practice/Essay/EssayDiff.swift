//
//  EssayDiff.swift
//  豆包爱学 — Features/Practice/Essay
//
//  Lightweight, deterministic word/character-level diff used to highlight what
//  the 升格作文 (polished essay) changed relative to the student's original.
//  Pure value logic, no UI, no isolation — safe to call from anywhere.
//

import Foundation

/// One run of the polished text, tagged as either unchanged or newly added /
/// rewritten relative to the original. Drives the colored highlight in the
/// 升格作文 panel.
nonisolated struct EssayDiffSegment: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable { case same, added }
    let id = UUID()
    let text: String
    let kind: Kind
}

/// Computes a readable highlight of the polished text. We tokenise both texts
/// into "units" (CJK characters individually, Latin words as a whole) and run a
/// classic longest-common-subsequence diff. Tokens present in the original are
/// rendered plainly; tokens the model introduced are highlighted so the student
/// can see *exactly* what was upgraded — the core "show, don't just tell" value
/// of 作文批改.
nonisolated enum EssayDiff {

    /// Highlight runs for `polished` against `original`.
    static func segments(original: String, polished: String) -> [EssayDiffSegment] {
        let originalTokens = tokenize(original)
        let polishedTokens = tokenize(polished)

        // If either side is empty just return the polished text as a single run.
        guard !polishedTokens.isEmpty else { return [] }
        guard !originalTokens.isEmpty else {
            return [EssayDiffSegment(text: polished, kind: .added)]
        }

        let commonInPolished = lcsFlags(originalTokens, polishedTokens)

        // Coalesce consecutive tokens of the same kind into runs for clean UI.
        var segments: [EssayDiffSegment] = []
        var buffer = ""
        var bufferIsCommon: Bool? = nil

        func flush() {
            guard let isCommon = bufferIsCommon, !buffer.isEmpty else { return }
            segments.append(EssayDiffSegment(text: buffer, kind: isCommon ? .same : .added))
            buffer = ""
        }

        for (index, token) in polishedTokens.enumerated() {
            let isCommon = commonInPolished[index]
            if bufferIsCommon != isCommon { flush(); bufferIsCommon = isCommon }
            buffer += token
        }
        flush()
        return segments
    }

    // MARK: - Tokenisation

    /// Split into diff units: each CJK / punctuation scalar is its own unit,
    /// runs of Latin letters & digits stay together as a word. This makes
    /// Chinese diffs character-accurate and English diffs word-accurate.
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var word = ""

        func flushWord() {
            if !word.isEmpty { tokens.append(word); word = "" }
        }

        for ch in text {
            if ch.isLetter && ch.isASCII || ch.isNumber && ch.isASCII {
                word.append(ch)
            } else {
                flushWord()
                tokens.append(String(ch))
            }
        }
        flushWord()
        return tokens
    }

    // MARK: - LCS

    /// Returns, for each token in `b`, whether it participates in the longest
    /// common subsequence with `a` (i.e. it is "unchanged"). Tokens flagged
    /// `false` are considered newly added/rewritten content.
    private static func lcsFlags(_ a: [String], _ b: [String]) -> [Bool] {
        let n = a.count, m = b.count
        // DP table of LCS lengths. Bounded by essay length; comfortably fast.
        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if a[i] == b[j] {
                    dp[i][j] = dp[i + 1][j + 1] + 1
                } else {
                    dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        var flags = [Bool](repeating: false, count: m)
        var i = 0, j = 0
        while i < n && j < m {
            if a[i] == b[j] {
                flags[j] = true
                i += 1; j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return flags
    }
}
