//
//  StudyPlanner.swift
//  豆包爱学
//
//  Builds graph-driven targeted practice (靶向练习) from mastery scores.
//

import Foundation

public nonisolated struct WeakPoint: Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var subject: Subject
    public var score: Double
    public init(id: String, name: String, subject: Subject, score: Double) {
        self.id = id; self.name = name; self.subject = subject; self.score = score
    }
}

public nonisolated enum StudyPlanner {

    /// The weakest knowledge points (lowest mastery first), capped at `limit`.
    public static func weakest(_ points: [WeakPoint], limit: Int = 5) -> [WeakPoint] {
        points.sorted { $0.score < $1.score }.prefix(limit).map { $0 }
    }

    /// Estimated minutes for a targeted set given how many weak points it covers.
    public static func estimatedMinutes(forTargets count: Int) -> Int {
        max(5, min(15, count * 2 + 3))
    }

    /// Whether a knowledge point should trigger a 薄弱点预警 micro-course push
    /// (unclear after 3 consecutive explanations — RESEARCH F48).
    public static func shouldPushMicroCourse(consecutiveExplains: Int) -> Bool {
        consecutiveExplains >= 3
    }
}
