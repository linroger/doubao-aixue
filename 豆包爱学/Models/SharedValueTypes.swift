//
//  SharedValueTypes.swift
//  豆包爱学
//
//  Pure Codable/Sendable value types shared by the data layer (SwiftData models
//  store these encoded as JSON) and the Intelligence DTOs (which compose them).
//  Keeping them here avoids duplication and a models→services dependency.
//

import Foundation

// MARK: - Solutions

public nonisolated struct KnowledgeRef: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var subject: Subject
    public init(id: String = UUID().uuidString, name: String, subject: Subject) {
        self.id = id; self.name = name; self.subject = subject
    }
}

public nonisolated struct FigureRef: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable { case diagram, illustration, chart, geometry, freeBody }
    public var kind: Kind
    public var caption: String
    public var systemSymbol: String      // SF Symbol used as a stand-in visual
    public init(kind: Kind, caption: String, systemSymbol: String = "function") {
        self.kind = kind; self.caption = caption; self.systemSymbol = systemSymbol
    }
}

public nonisolated struct SolutionStep: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var index: Int
    public var title: String
    public var detail: String            // explanation text
    public var math: String?             // optional LaTeX-ish line
    public var figure: FigureRef?
    public init(id: String = UUID().uuidString, index: Int, title: String,
                detail: String, math: String? = nil, figure: FigureRef? = nil) {
        self.id = id; self.index = index; self.title = title
        self.detail = detail; self.math = math; self.figure = figure
    }
}

public nonisolated struct ChoiceOption: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var label: String             // A / B / C / D
    public var text: String
    public var isCorrect: Bool
    public var explanation: String
    public init(id: String = UUID().uuidString, label: String, text: String,
                isCorrect: Bool, explanation: String) {
        self.id = id; self.label = label; self.text = text
        self.isCorrect = isCorrect; self.explanation = explanation
    }
}

// MARK: - Tutor blackboard (动态板书)

public nonisolated struct BoardElement: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case title, text, formula, bullet, highlight, divider, answer }
    public var id: String
    public var kind: Kind
    public var content: String
    public init(id: String = UUID().uuidString, kind: Kind, content: String = "") {
        self.id = id; self.kind = kind; self.content = content
    }
}

public nonisolated struct TutorCheckpoint: Codable, Sendable, Hashable {
    public var prompt: String
    public var options: [String]
    public var answerIndex: Int
    public var explanation: String
    public init(prompt: String, options: [String], answerIndex: Int, explanation: String) {
        self.prompt = prompt; self.options = options
        self.answerIndex = answerIndex; self.explanation = explanation
    }
}

public nonisolated struct TutorSegment: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var narration: String         // what the teacher says (also TTS)
    public var board: [BoardElement]     // what appears on the blackboard
    public var checkpoint: TutorCheckpoint?
    public init(id: String = UUID().uuidString, narration: String,
                board: [BoardElement] = [], checkpoint: TutorCheckpoint? = nil) {
        self.id = id; self.narration = narration
        self.board = board; self.checkpoint = checkpoint
    }
}

// MARK: - Essay grading

public nonisolated struct RubricDimension: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String              // 结构 / 立意 / 用词 / 语法 …
    public var score: Double
    public var maxScore: Double
    public var comment: String
    public init(id: String = UUID().uuidString, name: String, score: Double,
                maxScore: Double, comment: String) {
        self.id = id; self.name = name; self.score = score
        self.maxScore = maxScore; self.comment = comment
    }
}

public nonisolated struct SentenceAnnotation: Codable, Sendable, Hashable, Identifiable {
    public enum Severity: String, Codable, Sendable { case praise, suggestion, error }
    public var id: String
    public var original: String
    public var comment: String
    public var suggestion: String?
    public var severity: Severity
    public init(id: String = UUID().uuidString, original: String, comment: String,
                suggestion: String? = nil, severity: Severity) {
        self.id = id; self.original = original; self.comment = comment
        self.suggestion = suggestion; self.severity = severity
    }
}

// MARK: - Pronunciation scoring

public nonisolated struct WordScore: Codable, Sendable, Hashable, Identifiable {
    public var id: String
    public var word: String
    public var score: Double             // 0...100
    public init(id: String = UUID().uuidString, word: String, score: Double) {
        self.id = id; self.word = word; self.score = score
    }
}

// MARK: - Chat rich content

public nonisolated struct RichBlock: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case text, math, image, code, suggestion, action }
    public var id: String
    public var kind: Kind
    public var content: String
    public var auxiliary: String?        // e.g. action route or image symbol
    public init(id: String = UUID().uuidString, kind: Kind, content: String, auxiliary: String? = nil) {
        self.id = id; self.kind = kind; self.content = content; self.auxiliary = auxiliary
    }
}

// MARK: - JSON coding helpers (used by SwiftData models to store payloads)

public nonisolated enum DBJSON {
    public static func encode<T: Encodable>(_ value: T) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try? encoder.encode(value)
    }
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
