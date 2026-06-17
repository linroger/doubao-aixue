//
//  RoutePolicy.swift
//  豆包爱学
//
//  Seeds the app's default on-device/offline intelligence service. The active
//  provider is chosen by the user in 设置 → AI 模型 (AICredentialStore →
//  IntelligenceFactory); routing is decided at each call site, not here, so this
//  type stays a thin factory rather than a generic resolver.
//

import Foundation

public nonisolated enum RoutePolicy {
    /// The best default service for the app (used to seed the environment / as the
    /// fallback under the cloud provider when no key is configured).
    public static func defaultService() -> any IntelligenceService {
        FoundationModelsService.isAvailable ? FoundationModelsService() : MockIntelligenceService()
    }
}
