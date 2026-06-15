//
//  AIProvider.swift
//  豆包爱学 — Services/Intelligence/Cloud
//
//  Catalog of selectable cloud AI providers/models. The user picks one in
//  设置 → AI 模型; `CloudIntelligenceService` then powers every AI feature
//  (拍题解题 / 豆包老师 / 作文批改 / AI 伙伴 …) through that provider.
//
//  Three wire dialects cover all of them:
//    • openAI    — OpenAI-compatible /chat/completions (OpenAI, Qwen, Doubao,
//                  GLM, Kimi, MiniMax, DeepSeek). Auth: Bearer token.
//    • anthropic — Claude Messages API /v1/messages. Auth: x-api-key + version.
//    • gemini    — Google generateContent. Auth: ?key= query param.
//
//  All pure value types → `nonisolated` so the (nonisolated) network client and
//  service can use them freely under Swift 6 MainActor-default isolation.
//

import Foundation

// MARK: - Dialect

/// How a provider's HTTP request/response is shaped.
nonisolated enum AIDialect: String, Codable, Sendable {
    case openAI      // OpenAI-compatible chat/completions
    case anthropic   // Claude Messages API
    case gemini      // Google Gemini generateContent
}

// MARK: - Model

/// One selectable model within a provider.
nonisolated struct AIModel: Identifiable, Codable, Sendable, Hashable {
    var id: String          // wire model id, e.g. "gpt-4o", "claude-opus-4-8"
    var name: String        // friendly label shown in the picker
    init(_ id: String, _ name: String) { self.id = id; self.name = name }
}

// MARK: - Provider

/// A cloud AI vendor: where to call, how to auth, and which models it offers.
nonisolated struct AIProvider: Identifiable, Codable, Sendable, Hashable {
    var id: String                 // stable key, e.g. "openai", "doubao"
    var name: String               // Chinese display name, e.g. "豆包 (火山方舟)"
    var shortName: String          // compact label for chips, e.g. "豆包"
    var dialect: AIDialect
    var baseURL: String            // scheme + host + version path (no trailing slash)
    var chatPath: String           // appended for openAI/anthropic dialects
    var models: [AIModel]
    var symbolName: String         // SF Symbol for the provider tile
    var keyHelpURL: String         // where the user gets an API key
    var keyHint: String            // placeholder/format hint for the key field

    var defaultModelID: String { models.first?.id ?? "" }

    func model(withID id: String) -> AIModel? { models.first { $0.id == id } }
}

// MARK: - Catalog

extension AIProvider {

    /// Look a provider up by id; `nil` if unknown (e.g. a stale stored selection).
    nonisolated static func provider(id: String) -> AIProvider? {
        catalog.first { $0.id == id }
    }

    /// Every supported provider, in display order. K12-friendly Chinese names.
    nonisolated static let catalog: [AIProvider] = [
        // 国内主流
        AIProvider(
            id: "doubao", name: "豆包 (火山方舟)", shortName: "豆包",
            dialect: .openAI,
            baseURL: "https://ark.cn-beijing.volces.com/api/v3",
            chatPath: "/chat/completions",
            models: [
                AIModel("doubao-pro-32k", "豆包 Pro 32K"),
                AIModel("doubao-pro-128k", "豆包 Pro 128K"),
                AIModel("doubao-lite-32k", "豆包 Lite 32K"),
            ],
            symbolName: "leaf.circle.fill",
            keyHelpURL: "https://console.volcengine.com/ark",
            keyHint: "火山方舟 API Key（也可填入推理接入点 ID 作为模型）"),

        AIProvider(
            id: "qwen", name: "通义千问 (阿里云)", shortName: "通义千问",
            dialect: .openAI,
            baseURL: "https://dashscope.aliyuncs.com/compatible-mode/v1",
            chatPath: "/chat/completions",
            models: [
                AIModel("qwen-max", "通义千问 Max"),
                AIModel("qwen-plus", "通义千问 Plus"),
                AIModel("qwen-turbo", "通义千问 Turbo"),
            ],
            symbolName: "circle.hexagongrid.fill",
            keyHelpURL: "https://dashscope.console.aliyun.com",
            keyHint: "DashScope API Key（sk- 开头）"),

        AIProvider(
            id: "glm", name: "智谱清言 GLM", shortName: "智谱 GLM",
            dialect: .openAI,
            baseURL: "https://open.bigmodel.cn/api/paas/v4",
            chatPath: "/chat/completions",
            models: [
                AIModel("glm-4-plus", "GLM-4-Plus"),
                AIModel("glm-4-air", "GLM-4-Air"),
                AIModel("glm-4-flash", "GLM-4-Flash（免费）"),
            ],
            symbolName: "sparkle",
            keyHelpURL: "https://open.bigmodel.cn",
            keyHint: "智谱 API Key"),

        AIProvider(
            id: "kimi", name: "Kimi (月之暗面)", shortName: "Kimi",
            dialect: .openAI,
            baseURL: "https://api.moonshot.cn/v1",
            chatPath: "/chat/completions",
            models: [
                AIModel("moonshot-v1-8k", "Kimi 8K"),
                AIModel("moonshot-v1-32k", "Kimi 32K"),
                AIModel("moonshot-v1-128k", "Kimi 128K"),
            ],
            symbolName: "moon.stars.fill",
            keyHelpURL: "https://platform.moonshot.cn",
            keyHint: "Moonshot API Key（sk- 开头）"),

        AIProvider(
            id: "minimax", name: "MiniMax (海螺)", shortName: "MiniMax",
            dialect: .openAI,
            baseURL: "https://api.minimax.chat/v1",
            chatPath: "/text/chatcompletion_v2",
            models: [
                AIModel("abab6.5s-chat", "abab6.5s"),
                AIModel("abab6.5-chat", "abab6.5"),
            ],
            symbolName: "waveform.circle.fill",
            keyHelpURL: "https://platform.minimaxi.com",
            keyHint: "MiniMax API Key"),

        AIProvider(
            id: "deepseek", name: "DeepSeek 深度求索", shortName: "DeepSeek",
            dialect: .openAI,
            baseURL: "https://api.deepseek.com/v1",
            chatPath: "/chat/completions",
            models: [
                AIModel("deepseek-chat", "DeepSeek-V3"),
                AIModel("deepseek-reasoner", "DeepSeek-R1（推理）"),
            ],
            symbolName: "magnifyingglass.circle.fill",
            keyHelpURL: "https://platform.deepseek.com",
            keyHint: "DeepSeek API Key（sk- 开头）"),

        // 国际
        AIProvider(
            id: "anthropic", name: "Claude (Anthropic)", shortName: "Claude",
            dialect: .anthropic,
            baseURL: "https://api.anthropic.com",
            chatPath: "/v1/messages",
            models: [
                AIModel("claude-opus-4-8", "Claude Opus 4.8"),
                AIModel("claude-sonnet-4-6", "Claude Sonnet 4.6"),
                AIModel("claude-haiku-4-5", "Claude Haiku 4.5"),
            ],
            symbolName: "a.circle.fill",
            keyHelpURL: "https://console.anthropic.com",
            keyHint: "Anthropic API Key（sk-ant- 开头）"),

        AIProvider(
            id: "openai", name: "OpenAI (ChatGPT)", shortName: "OpenAI",
            dialect: .openAI,
            baseURL: "https://api.openai.com/v1",
            chatPath: "/chat/completions",
            models: [
                AIModel("gpt-4o", "GPT-4o"),
                AIModel("gpt-4o-mini", "GPT-4o mini"),
                AIModel("o4-mini", "o4-mini（推理）"),
            ],
            symbolName: "circle.grid.cross.fill",
            keyHelpURL: "https://platform.openai.com",
            keyHint: "OpenAI API Key（sk- 开头）"),

        AIProvider(
            id: "gemini", name: "Gemini (Google)", shortName: "Gemini",
            dialect: .gemini,
            baseURL: "https://generativelanguage.googleapis.com",
            chatPath: "/v1beta/models",   // model + :generateContent appended by client
            models: [
                AIModel("gemini-2.0-flash", "Gemini 2.0 Flash"),
                AIModel("gemini-1.5-pro", "Gemini 1.5 Pro"),
                AIModel("gemini-1.5-flash", "Gemini 1.5 Flash"),
            ],
            symbolName: "diamond.circle.fill",
            keyHelpURL: "https://aistudio.google.com",
            keyHint: "Google AI Studio API Key"),
    ]
}
