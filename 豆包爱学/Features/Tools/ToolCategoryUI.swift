//
//  ToolCategoryUI.swift
//  豆包爱学 — Features/Tools
//
//  UI-layer presentation metadata for ToolCategory / ToolKind, kept out of the
//  framework-free model layer (AppEnums). One source of truth so Home and the
//  Tools hub tint and label tools identically.
//

import SwiftUI

public extension ToolCategory {
    /// Accent color for tiles + section headers in this category.
    var tileTint: Color {
        switch self {
        case .qa: .dbPrimary
        case .grade: .dbSecondary
        case .memory: .dbAccent
        case .expression: .dbInfo
        case .extend: .dbSuccess
        }
    }

    var symbolName: String {
        switch self {
        case .qa: "questionmark.bubble.fill"
        case .grade: "checkmark.seal.fill"
        case .memory: "brain.head.profile"
        case .expression: "text.bubble.fill"
        case .extend: "sparkles"
        }
    }

    var subtitle: String {
        switch self {
        case .qa: "拍题、答疑、识别"
        case .grade: "作业、口算、作文、测验"
        case .memory: "错题、题库、单词、听写"
        case .expression: "口语、翻译"
        case .extend: "课堂、文档、报告、工具"
        }
    }
}

public extension ToolKind {
    /// Category accent color, shared by Home tiles and the Tools hub.
    var tileTint: Color { category.tileTint }
}
