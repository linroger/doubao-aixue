//
//  CloudChatClient.swift
//  豆包爱学 — Services/Intelligence/Cloud
//
//  One HTTP client that speaks all three provider dialects (OpenAI-compatible,
//  Anthropic Messages, Google Gemini) over `URLSession`. Non-streaming: it sends
//  a system + user prompt and returns the assistant's text. `CloudIntelligenceService`
//  layers structured prompts on top and parses the text into feature DTOs.
//
//  Requires the macOS "outgoing network connections" entitlement
//  (ENABLE_OUTGOING_NETWORK_CONNECTIONS=YES) — iOS has network access by default.
//
//  `nonisolated` Sendable value type → usable from the (nonisolated) intelligence
//  service and any task.
//

import Foundation

// MARK: - Error

nonisolated enum CloudAIError: Error, Sendable, CustomStringConvertible {
    case badURL
    case http(Int, String)        // status code + short body
    case emptyResponse
    case decode(String)
    case transport(String)

    var description: String {
        switch self {
        case .badURL: "请求地址无效"
        case .http(let code, let body): "服务返回 \(code)：\(body)"
        case .emptyResponse: "服务没有返回内容"
        case .decode(let m): "无法解析返回内容：\(m)"
        case .transport(let m): "网络错误：\(m)"
        }
    }
}

// MARK: - Client

nonisolated struct CloudChatClient: Sendable {
    let provider: AIProvider
    let modelID: String
    let apiKey: String

    init(provider: AIProvider, modelID: String, apiKey: String) {
        self.provider = provider
        self.modelID = modelID
        self.apiKey = apiKey
    }

    init(config: ResolvedAIConfig) {
        self.init(provider: config.provider, modelID: config.modelID, apiKey: config.apiKey)
    }

    /// Send a system + user prompt; return the assistant's reply text.
    func complete(system: String, user: String, maxTokens: Int = 1400) async throws -> String {
        let request = try buildRequest(system: system, user: user, maxTokens: maxTokens)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CloudAIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw CloudAIError.emptyResponse }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            throw CloudAIError.http(http.statusCode, String(body))
        }
        let text = try parse(data)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CloudAIError.emptyResponse }
        return trimmed
    }

    /// Send a system + user prompt **with an image** (multimodal); return the reply.
    /// Used by 作业批改 to let a vision-capable model read a photographed page. Builds
    /// the image part in each dialect's shape (OpenAI `image_url` data-URI, Anthropic
    /// `image` base64 source, Gemini `inline_data`).
    func completeVision(system: String, user: String, imageData: Data, maxTokens: Int = 2400) async throws -> String {
        let request = try buildVisionRequest(system: system, user: user, imageData: imageData, maxTokens: maxTokens)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw CloudAIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw CloudAIError.emptyResponse }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8)?.prefix(300) ?? ""
            throw CloudAIError.http(http.statusCode, String(body))
        }
        let text = try parse(data)
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CloudAIError.emptyResponse }
        return trimmed
    }

    /// Lightweight connectivity/auth probe for the settings screen.
    func test() async throws -> String {
        try await complete(
            system: "你是一个助手，请用一句不超过 15 字的中文确认你已就绪。",
            user: "请回复：连接成功。",
            maxTokens: 64)
    }

    // MARK: Request building

    private func buildRequest(system: String, user: String, maxTokens: Int) throws -> URLRequest {
        switch provider.dialect {
        case .openAI:    return try openAIRequest(system: system, user: user, maxTokens: maxTokens)
        case .anthropic: return try anthropicRequest(system: system, user: user, maxTokens: maxTokens)
        case .gemini:    return try geminiRequest(system: system, user: user, maxTokens: maxTokens)
        }
    }

    private func makeRequest(url: URL, headers: [String: String], body: [String: Any]) throws -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = 60
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return req
    }

    private func openAIRequest(system: String, user: String, maxTokens: Int) throws -> URLRequest {
        guard let url = URL(string: provider.baseURL + provider.chatPath) else { throw CloudAIError.badURL }
        let body: [String: Any] = [
            "model": modelID,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
            "max_tokens": maxTokens,
            "stream": false,
        ]
        return try makeRequest(url: url, headers: ["Authorization": "Bearer \(apiKey)"], body: body)
    }

    private func anthropicRequest(system: String, user: String, maxTokens: Int) throws -> URLRequest {
        guard let url = URL(string: provider.baseURL + provider.chatPath) else { throw CloudAIError.badURL }
        let body: [String: Any] = [
            "model": modelID,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [
                ["role": "user", "content": user],
            ],
        ]
        let headers = [
            "x-api-key": apiKey,
            "anthropic-version": "2023-06-01",
        ]
        return try makeRequest(url: url, headers: headers, body: body)
    }

    private func geminiRequest(system: String, user: String, maxTokens: Int) throws -> URLRequest {
        // /v1beta/models/{model}:generateContent?key=KEY
        let urlString = "\(provider.baseURL)\(provider.chatPath)/\(modelID):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw CloudAIError.badURL }
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [["text": user]]]],
            "generationConfig": ["maxOutputTokens": maxTokens],
        ]
        return try makeRequest(url: url, headers: [:], body: body)
    }

    // MARK: Vision request building

    private func buildVisionRequest(system: String, user: String, imageData: Data, maxTokens: Int) throws -> URLRequest {
        let mime = Self.mimeType(for: imageData)
        let base64 = imageData.base64EncodedString()
        switch provider.dialect {
        case .openAI:    return try openAIVisionRequest(system: system, user: user, mime: mime, base64: base64, maxTokens: maxTokens)
        case .anthropic: return try anthropicVisionRequest(system: system, user: user, mime: mime, base64: base64, maxTokens: maxTokens)
        case .gemini:    return try geminiVisionRequest(system: system, user: user, mime: mime, base64: base64, maxTokens: maxTokens)
        }
    }

    private func openAIVisionRequest(system: String, user: String, mime: String, base64: String, maxTokens: Int) throws -> URLRequest {
        guard let url = URL(string: provider.baseURL + provider.chatPath) else { throw CloudAIError.badURL }
        let body: [String: Any] = [
            "model": modelID,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": [
                    ["type": "text", "text": user],
                    ["type": "image_url", "image_url": ["url": "data:\(mime);base64,\(base64)"]],
                ]],
            ],
            "max_tokens": maxTokens,
            "stream": false,
        ]
        return try makeRequest(url: url, headers: ["Authorization": "Bearer \(apiKey)"], body: body)
    }

    private func anthropicVisionRequest(system: String, user: String, mime: String, base64: String, maxTokens: Int) throws -> URLRequest {
        guard let url = URL(string: provider.baseURL + provider.chatPath) else { throw CloudAIError.badURL }
        let body: [String: Any] = [
            "model": modelID,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [
                ["role": "user", "content": [
                    ["type": "image", "source": ["type": "base64", "media_type": mime, "data": base64]],
                    ["type": "text", "text": user],
                ]],
            ],
        ]
        let headers = ["x-api-key": apiKey, "anthropic-version": "2023-06-01"]
        return try makeRequest(url: url, headers: headers, body: body)
    }

    private func geminiVisionRequest(system: String, user: String, mime: String, base64: String, maxTokens: Int) throws -> URLRequest {
        let urlString = "\(provider.baseURL)\(provider.chatPath)/\(modelID):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw CloudAIError.badURL }
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": [
                ["text": user],
                ["inline_data": ["mime_type": mime, "data": base64]],
            ]]],
            "generationConfig": ["maxOutputTokens": maxTokens],
        ]
        return try makeRequest(url: url, headers: [:], body: body)
    }

    /// Sniff the image MIME from magic bytes (default JPEG, which our pickers emit).
    static func mimeType(for data: Data) -> String {
        guard let first = data.first else { return "image/jpeg" }
        switch first {
        case 0x89: return "image/png"
        case 0x47: return "image/gif"
        case 0x52: return "image/webp"     // "RIFF"…WEBP
        case 0x49, 0x4D: return "image/tiff"
        default: return "image/jpeg"
        }
    }

    // MARK: Response parsing

    private func parse(_ data: Data) throws -> String {
        switch provider.dialect {
        case .openAI:    return try parseOpenAI(data)
        case .anthropic: return try parseAnthropic(data)
        case .gemini:    return try parseGemini(data)
        }
    }

    private func parseOpenAI(_ data: Data) throws -> String {
        struct Resp: Decodable {
            struct Choice: Decodable { struct Msg: Decodable { let content: String? }; let message: Msg? }
            let choices: [Choice]?
        }
        guard let resp = try? JSONDecoder().decode(Resp.self, from: data),
              let text = resp.choices?.first?.message?.content else {
            throw CloudAIError.decode("OpenAI 格式")
        }
        return text
    }

    private func parseAnthropic(_ data: Data) throws -> String {
        struct Resp: Decodable {
            struct Block: Decodable { let type: String; let text: String? }
            let content: [Block]?
        }
        guard let resp = try? JSONDecoder().decode(Resp.self, from: data) else {
            throw CloudAIError.decode("Anthropic 格式")
        }
        let text = (resp.content ?? []).compactMap { $0.type == "text" ? $0.text : nil }.joined()
        guard !text.isEmpty else { throw CloudAIError.decode("Anthropic 空内容") }
        return text
    }

    private func parseGemini(_ data: Data) throws -> String {
        struct Resp: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable { struct Part: Decodable { let text: String? }; let parts: [Part]? }
                let content: Content?
            }
            let candidates: [Candidate]?
        }
        guard let resp = try? JSONDecoder().decode(Resp.self, from: data),
              let parts = resp.candidates?.first?.content?.parts else {
            throw CloudAIError.decode("Gemini 格式")
        }
        let text = parts.compactMap(\.text).joined()
        guard !text.isEmpty else { throw CloudAIError.decode("Gemini 空内容") }
        return text
    }
}
