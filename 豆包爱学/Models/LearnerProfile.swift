//
//  LearnerProfile.swift
//  豆包爱学
//
//  The personalization baseline set at onboarding; conditions all content.
//  CloudKit-ready: every property has a default; no unique constraints.
//

import Foundation
import SwiftData

@Model
public final class LearnerProfile {
    public var id: UUID = UUID()
    public var nickname: String = "小学员"
    public var gradeRaw: Int = GradeLevel.g5.rawValue
    public var subjectsRaw: [String] = []          // [Subject.rawValue]
    public var editionsData: Data? = nil           // encoded [String:String] subject→edition
    public var region: String = ""
    public var onboardingComplete: Bool = false
    public var isMinor: Bool = true
    public var learnModeEnabled: Bool = true       // anti-cheat default ON
    public var preferredRouteRaw: String = IntelligenceRoute.onDevice.rawValue
    public var streakDays: Int = 0
    public var problemsSolved: Int = 0
    public var lastActiveAt: Date = Date()
    public var createdAt: Date = Date()

    public init() {}

    // MARK: Ergonomic accessors

    public var grade: GradeLevel {
        get { GradeLevel(rawValue: gradeRaw) ?? .g5 }
        set { gradeRaw = newValue.rawValue }
    }
    public var stage: GradeStage { grade.stage }

    public var subjects: [Subject] {
        get { subjectsRaw.compactMap(Subject.init(rawValue:)) }
        set { subjectsRaw = newValue.map(\.rawValue) }
    }

    public var preferredRoute: IntelligenceRoute {
        get { IntelligenceRoute(rawValue: preferredRouteRaw) ?? .onDevice }
        set { preferredRouteRaw = newValue.rawValue }
    }

    public var editions: [Subject: TextbookEdition] {
        get {
            guard let map = DBJSON.decode([String: String].self, from: editionsData) else { return [:] }
            var result: [Subject: TextbookEdition] = [:]
            for (k, v) in map {
                if let s = Subject(rawValue: k), let e = TextbookEdition(rawValue: v) { result[s] = e }
            }
            return result
        }
        set {
            let map = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value.rawValue) })
            editionsData = DBJSON.encode(map)
        }
    }
}
