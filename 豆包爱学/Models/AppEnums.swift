//
//  AppEnums.swift
//  豆包爱学
//
//  Shared, UI-free, Sendable enumerations referenced across every layer.
//  Models import this; the design system maps these to colors/symbols.
//

import Foundation

// MARK: - Subjects

/// Academic subject. Raw value is a stable storage key.
public nonisolated enum Subject: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case math, physics, chemistry, biology
    case chinese, english, science
    case history, geography, politics
    case general

    public var id: String { rawValue }

    /// Chinese display label.
    public var displayName: String {
        switch self {
        case .math: "数学"
        case .physics: "物理"
        case .chemistry: "化学"
        case .biology: "生物"
        case .chinese: "语文"
        case .english: "英语"
        case .science: "科学"
        case .history: "历史"
        case .geography: "地理"
        case .politics: "道法"
        case .general: "综合"
        }
    }

    /// SF Symbol used in tiles and chips.
    public var symbolName: String {
        switch self {
        case .math: "x.squareroot"
        case .physics: "atom"
        case .chemistry: "flask.fill"
        case .biology: "leaf.fill"
        case .chinese: "character.book.closed.fill"
        case .english: "textformat.abc"
        case .science: "microscope.fill"
        case .history: "building.columns.fill"
        case .geography: "globe.asia.australia.fill"
        case .politics: "scale.3d"
        case .general: "books.vertical.fill"
        }
    }

    /// Subjects whose answers are primarily mathematical/STEM (drive solver layout).
    public var isSTEM: Bool {
        switch self {
        case .math, .physics, .chemistry, .biology, .science: true
        default: false
        }
    }
}

// MARK: - Grade & Stage

/// Education stage (学段). Explicitly excludes "working professional" per product positioning.
public nonisolated enum GradeStage: String, CaseIterable, Codable, Sendable, Identifiable {
    case primary       // 小学
    case juniorHigh    // 初中
    case seniorHigh    // 高中
    case college       // 大学

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .primary: "小学"
        case .juniorHigh: "初中"
        case .seniorHigh: "高中"
        case .college: "大学"
        }
    }

    public var symbolName: String {
        switch self {
        case .primary: "figure.child"
        case .juniorHigh: "backpack.fill"
        case .seniorHigh: "graduationcap.fill"
        case .college: "building.columns.fill"
        }
    }
}

/// Concrete grade level 1...12 (plus a college sentinel via stage). Raw value is the K12 ordinal.
public nonisolated enum GradeLevel: Int, CaseIterable, Codable, Sendable, Identifiable, Comparable {
    case g1 = 1, g2, g3, g4, g5, g6        // 小学一～六年级
    case g7, g8, g9                         // 初中一～三年级
    case g10, g11, g12                      // 高中一～三年级

    public var id: Int { rawValue }

    public static func < (lhs: GradeLevel, rhs: GradeLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    public var stage: GradeStage {
        switch rawValue {
        case 1...6: .primary
        case 7...9: .juniorHigh
        default: .seniorHigh
        }
    }

    public var displayName: String {
        let names = ["一", "二", "三", "四", "五", "六"]
        switch stage {
        case .primary: return "\(names[rawValue - 1])年级"
        case .juniorHigh: return "初\(names[rawValue - 7])"
        case .seniorHigh: return "高\(names[rawValue - 10])"
        case .college: return "大学"
        }
    }
}

/// Textbook edition (教材版本) — content is aligned to the chosen edition.
public nonisolated enum TextbookEdition: String, CaseIterable, Codable, Sendable, Identifiable {
    case renjiao        // 人教版
    case beishida       // 北师大版
    case sujiao         // 苏教版
    case waiyan         // 外研版 (English)
    case huadong        // 华东师大版
    case rujiao         // 沪教版
    case unspecified

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .renjiao: "人教版"
        case .beishida: "北师大版"
        case .sujiao: "苏教版"
        case .waiyan: "外研版"
        case .huadong: "华东师大版"
        case .rujiao: "沪教版"
        case .unspecified: "通用版"
        }
    }
}

// MARK: - Mistakes & mastery

public nonisolated enum MasteryState: String, CaseIterable, Codable, Sendable {
    case new          // 未掌握/新
    case weak         // 薄弱
    case developing   // 巩固中
    case mastered     // 已掌握

    public var displayName: String {
        switch self {
        case .new: "待学习"
        case .weak: "薄弱"
        case .developing: "巩固中"
        case .mastered: "已掌握"
        }
    }

    /// 0...1 progress used by rings and heatmaps.
    public var progress: Double {
        switch self {
        case .new: 0.0
        case .weak: 0.3
        case .developing: 0.65
        case .mastered: 1.0
        }
    }
}

/// Error cause taxonomy used by 错因分析.
public nonisolated enum ErrorType: String, CaseIterable, Codable, Sendable {
    case concept       // 概念不清
    case method        // 方法错误
    case calculation   // 计算错误
    case careless      // 粗心
    case knowledgeGap  // 知识点未掌握
    case comprehension // 审题错误

    public var displayName: String {
        switch self {
        case .concept: "概念不清"
        case .method: "方法错误"
        case .calculation: "计算错误"
        case .careless: "粗心大意"
        case .knowledgeGap: "知识点缺失"
        case .comprehension: "审题失误"
        }
    }
}

// MARK: - Capture & input

public nonisolated enum ProblemSource: String, Codable, Sendable, CaseIterable {
    case camera, album, document, text, voice, handwriting

    public var displayName: String {
        switch self {
        case .camera: "拍照"
        case .album: "相册"
        case .document: "文档"
        case .text: "文字"
        case .voice: "语音"
        case .handwriting: "手写"
        }
    }

    public var symbolName: String {
        switch self {
        case .camera: "camera.fill"
        case .album: "photo.on.rectangle"
        case .document: "doc.text.fill"
        case .text: "text.cursor"
        case .voice: "mic.fill"
        case .handwriting: "pencil.and.scribble"
        }
    }
}

/// Camera mode fork: solve vs grade (拍题 | 批改).
public nonisolated enum CaptureMode: String, Codable, Sendable, CaseIterable, Identifiable {
    case solve   // 拍题
    case grade   // 批改

    public var id: String { rawValue }
    public var displayName: String { self == .solve ? "拍题" : "批改" }
    public var symbolName: String { self == .solve ? "wand.and.stars" : "checkmark.circle.fill" }
}

// MARK: - Tools

/// Every utility surfaced in the 工具 hub and deep-linked from Home.
public nonisolated enum ToolKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case solve              // 拍题答疑
    case gradeArithmetic    // 口算批改
    case gradeEssay         // 作文批改
    case mistakeNotebook    // 错题本
    case dictation          // 听写
    case vocabulary         // 背单词
    case oral               // 英语口语
    case translation        // 课文翻译
    case knowledgeQA        // 知识专家
    case classical          // 古诗文
    case documentQA         // 文档问答
    case recognizeAnything  // 识万物
    case classroom          // 豆包课堂
    case knowledgeGraph     // 知识图谱
    case drill              // 举一反三/练习
    case reports            // 学习报告
    case today              // 今日计划
    case calculator         // 科学计算器 + 公式库
    case focus              // 专注 · 番茄钟
    case liveScan           // 实时扫题
    case achievements       // 成就墙

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .solve: "拍题答疑"
        case .gradeArithmetic: "口算批改"
        case .gradeEssay: "作文批改"
        case .mistakeNotebook: "错题本"
        case .dictation: "听写"
        case .vocabulary: "背单词"
        case .oral: "英语口语"
        case .translation: "课文翻译"
        case .knowledgeQA: "知识专家"
        case .classical: "古诗文"
        case .documentQA: "文档问答"
        case .recognizeAnything: "识万物"
        case .classroom: "豆包课堂"
        case .knowledgeGraph: "知识图谱"
        case .drill: "举一反三"
        case .reports: "学习报告"
        case .today: "今日"
        case .calculator: "计算器"
        case .focus: "专注"
        case .liveScan: "实时扫题"
        case .achievements: "成就"
        }
    }

    public var symbolName: String {
        switch self {
        case .solve: "camera.viewfinder"
        case .gradeArithmetic: "checkmark.rectangle.stack.fill"
        case .gradeEssay: "text.badge.checkmark"
        case .mistakeNotebook: "book.closed.fill"
        case .dictation: "ear.fill"
        case .vocabulary: "rectangle.on.rectangle.angled.fill"
        case .oral: "waveform.and.mic"
        case .translation: "character.bubble.fill"
        case .knowledgeQA: "lightbulb.fill"
        case .classical: "scroll.fill"
        case .documentQA: "doc.text.magnifyingglass"
        case .recognizeAnything: "viewfinder.circle.fill"
        case .classroom: "play.tv.fill"
        case .knowledgeGraph: "point.3.connected.trianglepath.dotted"
        case .drill: "square.grid.3x3.fill"
        case .reports: "chart.bar.xaxis"
        case .today: "sun.max.fill"
        case .calculator: "x.squareroot"
        case .focus: "timer"
        case .liveScan: "text.viewfinder"
        case .achievements: "trophy.fill"
        }
    }

    /// Grouping for the 工具 grid (答疑/批改/记忆/表达/拓展).
    public var category: ToolCategory {
        switch self {
        case .solve, .knowledgeQA, .recognizeAnything: .qa
        case .gradeArithmetic, .gradeEssay, .drill: .grade
        case .mistakeNotebook, .vocabulary, .dictation, .knowledgeGraph: .memory
        case .oral, .translation: .expression
        case .classical, .documentQA, .classroom, .reports: .extend
        case .liveScan: .qa
        case .today, .focus, .achievements: .memory
        case .calculator: .extend
        }
    }

    public var requiresNetwork: Bool { false } // everything has an on-device/mock path
}

public nonisolated enum ToolCategory: String, CaseIterable, Sendable, Identifiable {
    case qa, grade, memory, expression, extend
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .qa: "答疑"
        case .grade: "批改"
        case .memory: "记忆"
        case .expression: "表达"
        case .extend: "拓展"
        }
    }
}

// MARK: - Intelligence routing

/// Where an AI task is executed; surfaced to the UI as an "on-device vs enhanced" badge.
public nonisolated enum IntelligenceRoute: String, Codable, Sendable {
    case onDevice     // Foundation Models / Vision / Speech
    case cloud        // optional enhanced (Doubao/PCC) — documented seam
    case mock         // deterministic offline reference

    public var badgeLabel: String {
        switch self {
        case .onDevice: "端侧"
        case .cloud: "增强"
        case .mock: "离线"
        }
    }

    public var symbolName: String {
        switch self {
        case .onDevice: "lock.iphone"
        case .cloud: "sparkles"
        case .mock: "wifi.slash"
        }
    }
}
