//
//  CompanionSupport.swift
//  豆包爱学 — Features/Companion
//
//  Pure, nonisolated value types and mappings shared by the AI 伙伴 surface
//  (知识问答 / 成长挚友). Keeping these here (and `nonisolated`) lets SwiftData
//  models and the nonisolated Intelligence layer interoperate cleanly while the
//  views stay MainActor by default.
//
//  Covers RESEARCH F23 (知识问答), F24 (成长挚友), F27 (AI 串联 intents) and
//  F28 (会话历史 / 接续学习).
//

import SwiftUI

// MARK: - Companion mode (学习问答 vs 成长挚友)

/// The two conversational personas exposed by the AI 伙伴 surface. `knowledge`
/// is the task-focused academic tutor; `companion` is the warmer 成长挚友 with a
/// softer theme. Bridges to the foundation `ConversationKind` used by `ChatRequest`.
public nonisolated enum CompanionMode: String, CaseIterable, Sendable, Identifiable {
    case knowledge
    case companion

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .knowledge: "学习问答"
        case .companion: "成长挚友"
        }
    }

    public var subtitle: String {
        switch self {
        case .knowledge: "百科 + 学科知识，随问随答"
        case .companion: "学习累了，来和豆包聊聊心里话"
        }
    }

    public var symbolName: String {
        switch self {
        case .knowledge: "lightbulb.max.fill"
        case .companion: "heart.fill"
        }
    }

    /// The persisted `Conversation.kindRaw` value for this mode.
    public var conversationKindRaw: String {
        switch self {
        case .knowledge: "knowledge"
        case .companion: "companion"
        }
    }

    /// The Intelligence `ConversationKind` for `ChatRequest`.
    public var chatKind: ConversationKind {
        switch self {
        case .knowledge: .knowledge
        case .companion: .companion
        }
    }

    public init(conversationKindRaw raw: String) {
        self = raw == "companion" ? .companion : .knowledge
    }

    public var defaultTitle: String {
        switch self {
        case .knowledge: "新的提问"
        case .companion: "和豆包聊聊"
        }
    }

    /// Example prompt chips shown on the empty state of a fresh conversation.
    public var examplePrompts: [String] {
        switch self {
        case .knowledge:
            return [
                "为什么天空是蓝色的？",
                "帮我讲讲分数的加减法",
                "鲸鱼是鱼类吗？",
                "怎么背古诗才记得牢？",
            ]
        case .companion:
            return [
                "今天考试没考好，有点难过",
                "我有点不想上学",
                "和同桌闹别扭了，怎么办",
                "我想夸夸自己今天的努力",
            ]
        }
    }

    /// Conversation-starter chips shown on the list when there is no history.
    public var listExamplePrompts: [String] {
        switch self {
        case .knowledge:
            return ["恐龙为什么会灭绝？", "怎么求三角形面积？", "讲讲水的三态变化"]
        case .companion:
            return ["最近压力有点大", "想找人说说话", "夸夸我吧"]
        }
    }
}

// MARK: - Cross-feature intents (F27 AI 串联)

/// Natural-language intents the companion can dispatch into specialized skills.
/// Mapped from `RichBlock(kind: .suggestion)` auxiliary tags emitted by the
/// Intelligence layer (e.g. "tutor" / "similar" / "mistake").
public nonisolated enum CompanionIntent: String, Sendable {
    case explain   = "tutor"     // 讲一讲 → 豆包老师 tutor session
    case similar   = "similar"   // 出相似题 → 举一反三
    case mistake   = "mistake"   // 加入错题本
    case solve     = "solve"     // 拍题 / 解题
    case plan      = "plan"      // 规划练习

    public init?(auxiliary: String?) {
        guard let auxiliary, let value = CompanionIntent(rawValue: auxiliary) else { return nil }
        self = value
    }

    public var symbolName: String {
        switch self {
        case .explain: "graduationcap.fill"
        case .similar: "rectangle.stack.badge.plus"
        case .mistake: "book.closed.fill"
        case .solve: "camera.viewfinder"
        case .plan: "calendar.badge.clock"
        }
    }
}

// MARK: - Theme

/// Resolves the accent palette for a mode so 成长挚友 reads warmer (secondary)
/// while 学习问答 stays on the primary brand color.
@MainActor
public enum CompanionTheme {
    public static func accent(for mode: CompanionMode) -> Color {
        mode == .companion ? .dbSecondary : .dbPrimary
    }

    public static func accentSoft(for mode: CompanionMode) -> Color {
        mode == .companion ? .dbSecondarySoft : .dbPrimarySoft
    }

    public static func mascotMood(for mode: CompanionMode) -> DBMascotMood {
        mode == .companion ? .happy : .curious
    }
}
