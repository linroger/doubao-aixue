//
//  ReadingSupport.swift
//  豆包爱学 — Features/Practice/Reading
//
//  Shared value types & helpers for 课文翻译 (TranslationView) and 古诗文
//  (ClassicalView). Pure data lives here as `nonisolated Sendable`; the small
//  set of SwiftUI-value helpers (Color/Font) stay @MainActor.
//

import SwiftUI

// MARK: - Sentence-aligned bilingual model (translation)

/// One aligned sentence pair in a 课文翻译 result. `original` is the source-text
/// sentence; `translated` is its rendering in the other language.
nonisolated struct AlignedSentence: Sendable, Hashable, Identifiable {
    let id = UUID()
    let original: String
    let translated: String
}

/// Translation direction for 课文翻译.
nonisolated enum TranslationDirection: String, CaseIterable, Sendable, Identifiable {
    case zhToEn          // 中文 → English
    case enToZh          // English → 中文

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .zhToEn: "中 → 英"
        case .enToZh: "英 → 中"
        }
    }

    /// BCP-47 language for reading the *source* aloud.
    var sourceTTSLanguage: String {
        switch self {
        case .zhToEn: "zh-CN"
        case .enToZh: "en-US"
        }
    }

    /// BCP-47 language for reading the *translation* aloud.
    var targetTTSLanguage: String {
        switch self {
        case .zhToEn: "en-US"
        case .enToZh: "zh-CN"
        }
    }

    var toggled: TranslationDirection {
        self == .zhToEn ? .enToZh : .zhToEn
    }
}

// MARK: - Translation engine (offline, deterministic)

/// Sentence-aligned bilingual translation. The real product calls the on-device
/// Translation framework when a language pack is installed; here we provide a
/// deterministic gloss-backed translation so the flow is fully demoable offline
/// on both platforms (Translation availability is a documented integration seam).
nonisolated enum ReadingTranslator {

    /// Split a passage into sentence units, keeping CJK and Latin punctuation.
    static func splitSentences(_ text: String) -> [String] {
        let terminators = CharacterSet(charactersIn: "。！？!?；;\n")
        var sentences: [String] = []
        var current = ""
        for ch in text {
            current.append(ch)
            if let scalar = ch.unicodeScalars.first, terminators.contains(scalar) {
                let trimmed = current.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { sentences.append(trimmed) }
                current = ""
            }
        }
        let tail = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { sentences.append(tail) }
        return sentences
    }

    /// Produce a sentence-aligned bilingual rendering of `text` in `direction`.
    static func translate(_ text: String, direction: TranslationDirection) -> [AlignedSentence] {
        splitSentences(text).map { sentence in
            AlignedSentence(original: sentence,
                            translated: translateSentence(sentence, direction: direction))
        }
    }

    /// Word-level gloss used by tap-to-look-up. Returns `nil` when unknown so the
    /// caller can show an encouraging fallback instead of a wrong answer.
    static func gloss(for word: String) -> String? {
        let key = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        return glossary[key]
    }

    // MARK: Private

    private static func translateSentence(_ sentence: String, direction: TranslationDirection) -> String {
        let key = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        if let canned = sentenceBank[key] { return canned }
        // Fall back to a faithful word-by-word gloss so output is never empty.
        let tokens = tokenize(key, direction: direction)
        let glossed = tokens.compactMap { gloss(for: $0) }
        if !glossed.isEmpty {
            return glossed.joined(separator: direction == .zhToEn ? " " : "，")
        }
        return direction == .zhToEn
            ? "(译文示例) " + key
            : "（参考译文）" + key
    }

    private static func tokenize(_ sentence: String, direction: TranslationDirection) -> [String] {
        switch direction {
        case .enToZh:
            return sentence
                .components(separatedBy: CharacterSet(charactersIn: " ,.!?;:\n"))
                .filter { !$0.isEmpty }
        case .zhToEn:
            // CJK: gloss per character is too coarse; rely on the sentence bank.
            return sentence.map { String($0) }
        }
    }

    /// Canned high-quality sentence translations for the bundled sample text so
    /// "用示例" demonstrates a clean bilingual result.
    private static let sentenceBank: [String: String] = [
        "Knowledge is power.": "知识就是力量。",
        "Practice makes perfect.": "熟能生巧。",
        "Hard work helps you achieve your goals.": "努力会帮助你实现目标。",
        "I want to improve my English.": "我想提高我的英语。",
        "Be confident in the exam!": "考试时要自信！",
        "学而不思则罔，思而不学则殆。":
            "Learning without thinking leads to confusion; thinking without learning leads to peril.",
        "读书破万卷，下笔如有神。":
            "Read ten thousand books, and your writing will flow as if inspired.",
        "少壮不努力，老大徒伤悲。":
            "If you do not strive in youth, you will only grieve in vain when old.",
    ]

    /// Bilingual word glossary for tap-to-look-up (covers the bundled units).
    private static let glossary: [String: String] = [
        "improve": "v. 改善；提高",
        "knowledge": "n. 知识；学问",
        "achieve": "v. 实现；取得",
        "challenge": "n. 挑战 v. 向…挑战",
        "memory": "n. 记忆；回忆",
        "confident": "adj. 自信的",
        "power": "n. 力量；能力",
        "practice": "n./v. 练习",
        "perfect": "adj. 完美的",
        "goal": "n. 目标",
        "goals": "n. 目标（复数）",
        "english": "n. 英语",
        "exam": "n. 考试",
        "work": "n./v. 工作；努力",
        "hard": "adj./adv. 努力地；困难的",
        "help": "v. 帮助",
        "helps": "v. 帮助",
        "want": "v. 想要",
        "be": "v. 是；成为",
    ]
}

// MARK: - Sample passages

nonisolated enum ReadingSamples {
    static let chinesePassage = "学而不思则罔，思而不学则殆。读书破万卷，下笔如有神。"
    static let englishPassage = "Knowledge is power. Practice makes perfect. Hard work helps you achieve your goals."
}

// MARK: - Classical text utilities (断句)

/// 断句 (sentence segmentation) presentation for 古诗文 study. Splits the
/// original poem into rhythmic units a learner can tap to read aloud one line.
nonisolated enum ClassicalSegmenter {

    /// Each line of the poem becomes one tappable unit (newline-delimited).
    static func lines(of original: String) -> [String] {
        original
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Fine-grained 断句: split each line at CJK clause punctuation, keeping the
    /// punctuation attached so the learner sees the natural pauses.
    static func clauses(of line: String) -> [String] {
        var clauses: [String] = []
        var current = ""
        let breakers = CharacterSet(charactersIn: "，。！？、；：")
        for ch in line {
            current.append(ch)
            if let scalar = ch.unicodeScalars.first, breakers.contains(scalar) {
                clauses.append(current)
                current = ""
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { clauses.append(current) }
        return clauses
    }
}

// MARK: - Presentation helpers (@MainActor — produce SwiftUI values)

@MainActor
enum ReadingPresentation {
    /// A warm tint for the dynasty badge on the author card.
    static func dynastyTint(_ dynasty: String) -> Color {
        dynasty.isEmpty ? .dbSecondary : .dbAccent
    }
}
