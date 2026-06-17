//
//  ConversationModels.swift
//  豆包爱学
//
//  AI companion conversations (知识问答 / 成长挚友) with resumable history.
//

import Foundation
import SwiftData

public nonisolated enum ChatRole: String, Codable, Sendable { case user, assistant, system }

@Model
public final class Conversation {
    public var id: UUID = UUID()
    public var title: String = "新对话"
    public var kindRaw: String = "tutor"           // tutor / companion / knowledge
    public var subjectRaw: String? = nil
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \ChatMessageEntity.conversation)
    public var messages: [ChatMessageEntity]? = []

    public init() {}

    public var subject: Subject? {
        get { subjectRaw.flatMap(Subject.init(rawValue:)) }
        set { subjectRaw = newValue?.rawValue }
    }
    public var sortedMessages: [ChatMessageEntity] {
        (messages ?? []).sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
public final class ChatMessageEntity {
    public var id: UUID = UUID()
    public var roleRaw: String = ChatRole.user.rawValue
    public var text: String = ""
    public var blocksData: Data? = nil             // [RichBlock]
    public var routeRaw: String? = nil
    public var createdAt: Date = Date()
    public var conversation: Conversation? = nil

    public init() {}

    public var role: ChatRole {
        get { ChatRole(rawValue: roleRaw) ?? .user }
        set { roleRaw = newValue.rawValue }
    }
    public var blocks: [RichBlock] {
        get { DBJSON.decode([RichBlock].self, from: blocksData) ?? [] }
        set { blocksData = DBJSON.encode(newValue) }
    }
    public var route: IntelligenceRoute? {
        get { routeRaw.flatMap(IntelligenceRoute.init(rawValue:)) }
        set { routeRaw = newValue?.rawValue }
    }
}
