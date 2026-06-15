//
//  RoutePolicy.swift
//  豆包爱学
//
//  Decides which provider serves a task and surfaces an "on-device vs enhanced"
//  badge. Everything currently routes on-device/offline; cloud (Doubao/PCC) is a
//  documented seam controlled by the learner's preferred route + availability.
//

import Foundation

public nonisolated enum IntelligenceTask: String, Sendable {
    case solve, gradeEssay, gradeArithmetic, similar, explain
    case summarize, docQA, lesson, dictation, pronunciation, tutor, chat

    /// Tasks that benefit most from a larger cloud model when the user opts in.
    public var prefersCloudWhenAllowed: Bool {
        switch self {
        case .gradeEssay, .lesson, .docQA, .summarize: true
        default: false
        }
    }
}

public nonisolated struct RoutePolicy: Sendable {
    public var preferred: IntelligenceRoute
    public var onDeviceAvailable: Bool
    public var cloudAvailable: Bool

    public init(preferred: IntelligenceRoute = .onDevice,
                onDeviceAvailable: Bool = FoundationModelsService.isAvailable,
                cloudAvailable: Bool = false) {
        self.preferred = preferred
        self.onDeviceAvailable = onDeviceAvailable
        self.cloudAvailable = cloudAvailable
    }

    /// Resolve the route actually used for a task.
    public func resolve(_ task: IntelligenceTask) -> IntelligenceRoute {
        if preferred == .cloud, cloudAvailable, task.prefersCloudWhenAllowed { return .cloud }
        if onDeviceAvailable { return .onDevice }
        return .mock
    }

    /// Pick the concrete provider for the resolved route.
    public func provider(for task: IntelligenceTask) -> any IntelligenceService {
        switch resolve(task) {
        case .onDevice: FoundationModelsService()
        case .cloud:    FoundationModelsService()   // cloud seam → falls back to on-device/mock today
        case .mock:     MockIntelligenceService()
        }
    }

    /// The best default service for the app (used to seed the environment).
    public static func defaultService() -> any IntelligenceService {
        FoundationModelsService.isAvailable ? FoundationModelsService() : MockIntelligenceService()
    }
}
