//
//  MistakeNotebookSupport.swift
//  豆包爱学 — Features/Knowledge/MistakeNotebook
//
//  Shared, presentation-only helpers for the 错题本 (mistake notebook): how an
//  error type / mastery state maps to a tint and badge, whether a question
//  should render as math, and the forgetting-curve framing copy. Kept tiny and
//  pure so both the list and the detail view stay focused.
//

import SwiftUI

// MARK: - Mastery badge

/// A small pill summarizing how well an item is mastered, colored by state.
struct MasteryBadge: View {
    let mastery: MasteryState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: MistakePresentation.masterySymbol(mastery))
                .font(.system(size: 10, weight: .bold))
            Text(mastery.displayName)
                .font(.dbCaption2.weight(.semibold))
        }
        .padding(.horizontal, DBSpacing.sm)
        .padding(.vertical, 3)
        .foregroundStyle(MistakePresentation.masteryTint(mastery))
        .background(
            MistakePresentation.masteryTint(mastery).opacity(0.15),
            in: Capsule(style: .continuous)
        )
        .accessibilityLabel("掌握程度 \(mastery.displayName)")
    }
}

// MARK: - Presentation mapping

/// Pure mapping helpers (no state) shared across the notebook surfaces.
enum MistakePresentation {

    static func masteryTint(_ mastery: MasteryState) -> Color {
        switch mastery {
        case .new: .dbTextTertiary
        case .weak: .dbError
        case .developing: .dbWarning
        case .mastered: .dbSuccess
        }
    }

    static func masterySymbol(_ mastery: MasteryState) -> String {
        switch mastery {
        case .new: "circle.dashed"
        case .weak: "exclamationmark.triangle.fill"
        case .developing: "arrow.up.right.circle.fill"
        case .mastered: "checkmark.seal.fill"
        }
    }

    static func errorTypeTint(_ type: ErrorType) -> Color {
        switch type {
        case .concept: .dbInfo
        case .method: .dbSecondary
        case .calculation: .dbWarning
        case .careless: .dbAccent
        case .knowledgeGap: .dbError
        case .comprehension: .dbPrimary
        }
    }

    /// Whether a question string should be rendered with `MathText`.
    /// True for STEM subjects, or when the text carries formula-ish characters.
    static func isMathy(_ text: String, subject: Subject) -> Bool {
        if subject.isSTEM { return true }
        let markers: Set<Character> = ["=", "+", "×", "÷", "√", "²", "³", "≤", "≥", "≠", "π", "^", "_", "\\"]
        if text.contains(where: { markers.contains($0) }) { return true }
        // Bare arithmetic like "45 ÷ 5" or "3*4" with digits and an operator.
        let hasDigit = text.contains(where: \.isNumber)
        let hasOp = text.contains(where: { "*-/<>".contains($0) })
        return hasDigit && hasOp
    }

    /// Human relative-time framing for a review due date (forgetting curve).
    static func dueDescription(for date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let startToday = cal.startOfDay(for: now)
        let startDue = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startToday, to: startDue).day ?? 0
        switch days {
        case ..<0: return "已逾期 \(-days) 天"
        case 0: return "今天复习"
        case 1: return "明天复习"
        default: return "\(days) 天后复习"
        }
    }
}

// MARK: - Review filter

/// The "待复习/今日复习" toggle in the list toolbar.
enum ReviewFilter: String, CaseIterable, Identifiable {
    case all          // 全部
    case dueToday     // 今日复习 (nextReviewAt <= now)
    case unmastered   // 未掌握 (mastery != .mastered)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "全部"
        case .dueToday: "今日复习"
        case .unmastered: "待巩固"
        }
    }

    var symbolName: String {
        switch self {
        case .all: "tray.full.fill"
        case .dueToday: "bell.badge.fill"
        case .unmastered: "flag.fill"
        }
    }
}
