//
//  AICredentialStore.swift
//  豆包爱学 — Services/Intelligence/Cloud
//
//  Single source of truth for the cloud-AI configuration: whether cloud is on,
//  which provider + model the user picked, and the per-provider API key (kept in
//  the Keychain). `@Observable` so the app re-injects the right `IntelligenceService`
//  whenever the user changes any of it (see `DoubaoAiXueApp`).
//
//  Selection (enabled / provider / model) persists in UserDefaults under
//  `db.ai.*`; API keys persist in the Keychain keyed by provider id.
//

import SwiftUI

// MARK: - Resolved config (Sendable snapshot)

/// An immutable snapshot used to build a `CloudIntelligenceService` off the
/// MainActor. Carries everything a request needs.
nonisolated struct ResolvedAIConfig: Sendable, Hashable {
    var provider: AIProvider
    var modelID: String
    var apiKey: String
}

// MARK: - Store

@MainActor
@Observable
final class AICredentialStore {

    private enum Keys {
        static let enabled = "db.ai.cloudEnabled"
        static let provider = "db.ai.providerID"
        static let model = "db.ai.modelID"
    }

    private let defaults: UserDefaults
    private let keychain: KeychainStore

    /// Whether cloud AI is active. When off, the app uses on-device / offline.
    var cloudEnabled: Bool { didSet { defaults.set(cloudEnabled, forKey: Keys.enabled) } }
    /// Selected provider id (see `AIProvider.catalog`).
    var providerID: String { didSet { defaults.set(providerID, forKey: Keys.provider) } }
    /// Selected model id within the provider.
    var modelID: String { didSet { defaults.set(modelID, forKey: Keys.model) } }

    /// Bumped on any key/provider/model change so observers (the App scene)
    /// rebuild the intelligence service even when only the Keychain changed.
    private(set) var configToken: Int = 0

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain
        self.cloudEnabled = defaults.bool(forKey: Keys.enabled)
        self.providerID = defaults.string(forKey: Keys.provider) ?? "doubao"
        self.modelID = defaults.string(forKey: Keys.model) ?? ""
    }

    // MARK: Derived

    var provider: AIProvider? { AIProvider.provider(id: providerID) }

    var selectedModel: AIModel? {
        guard let provider else { return nil }
        return provider.model(withID: modelID) ?? provider.models.first
    }

    private var effectiveModelID: String {
        selectedModel?.id ?? provider?.defaultModelID ?? ""
    }

    // MARK: API keys (Keychain)

    func apiKey(for providerID: String) -> String { keychain.get(account: providerID) ?? "" }

    var currentKey: String { apiKey(for: providerID) }

    func setKey(_ key: String, for providerID: String) {
        keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), account: providerID)
        configToken &+= 1
    }

    // MARK: Selection mutations

    func setCloudEnabled(_ on: Bool) {
        cloudEnabled = on
        configToken &+= 1
    }

    func selectProvider(_ id: String) {
        providerID = id
        if selectedModel == nil { modelID = provider?.defaultModelID ?? "" }
        configToken &+= 1
    }

    func selectModel(_ id: String) {
        modelID = id
        configToken &+= 1
    }

    // MARK: Resolution

    /// The active config, or `nil` when cloud is off / unconfigured / keyless.
    /// Touches `configToken` so SwiftUI re-resolves after a Keychain-only change.
    var resolved: ResolvedAIConfig? {
        _ = configToken
        guard cloudEnabled, let provider else { return nil }
        let key = currentKey
        guard !key.isEmpty else { return nil }
        return ResolvedAIConfig(provider: provider, modelID: effectiveModelID, apiKey: key)
    }

    /// One-line status for the settings row subtitle.
    var statusSummary: String {
        guard cloudEnabled else { return "未开启 · 使用端侧/离线智能" }
        guard let provider else { return "未选择模型" }
        guard !currentKey.isEmpty else { return "\(provider.shortName) · 待填写 API Key" }
        return "\(provider.shortName) · \(selectedModel?.name ?? effectiveModelID)"
    }
}

// MARK: - Factory

/// Builds the `IntelligenceService` the whole app runs on. With a resolved cloud
/// config it returns a `CloudIntelligenceService` (falling back to on-device/mock
/// on any error); otherwise the on-device / offline base service.
nonisolated enum IntelligenceFactory {
    static func make(_ config: ResolvedAIConfig?) -> any IntelligenceService {
        let base = RoutePolicy.defaultService()
        guard let config else { return base }
        return CloudIntelligenceService(config: config, fallback: base)
    }
}
