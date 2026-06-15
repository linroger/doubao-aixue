//
//  OralScenario.swift
//  豆包爱学 — Features/Practice/Oral
//
//  Presentation helpers for 英语口语 / 口语陪练 (F36). The pure value types
//  (`OralScenario`, `OralTurnScript`, `OralAvatar`, `OralCorrection`) live in
//  `OralPracticeScenarios.swift`; this file adds the SwiftUI-facing helpers that
//  return Color / DBMascotMood. Those helpers touch `Color.db*` which is
//  MainActor-isolated, so the whole extension is `@MainActor` (NOT `nonisolated`).
//

import SwiftUI

// MARK: - Scenario presentation (MainActor — returns Color/DBMascotMood)

@MainActor
extension OralScenario {
    /// Accent tint used for this scenario's chip, header and gauges.
    var tint: Color {
        switch self {
        case .introduction: .dbPrimary
        case .shopping:     .dbSecondary
        case .directions:   .dbInfo
        case .restaurant:   .dbAccent
        case .schoolDay:    .dbSuccess
        }
    }

    /// Mascot mood used to animate the on-call avatar for this scenario.
    var mascotMood: DBMascotMood {
        switch self {
        case .introduction: .happy
        case .shopping:     .curious
        case .directions:   .thinking
        case .restaurant:   .cheering
        case .schoolDay:    .happy
        }
    }
}

// MARK: - Avatar presentation (MainActor)

@MainActor
extension OralAvatar {
    /// Mascot mood matching this persona's energy.
    var mascotMood: DBMascotMood {
        switch id {
        case "amy":    .happy
        case "leo":    .cheering
        case "olivia": .thinking
        case "noah":   .curious
        default:       .happy
        }
    }

    /// SF Symbol shown on the persona chooser chip.
    var symbolName: String {
        voiceLanguage.hasPrefix("en-GB")
            ? "person.crop.circle.badge.checkmark"
            : "person.crop.circle.fill"
    }
}

// MARK: - Pronunciation score presentation (MainActor — returns Color)

/// Colour ramp shared by the per-word heatmap and the accuracy/fluency gauges.
/// 0…100 score → red (needs work) → amber → green (great).
@MainActor
enum OralScorePalette {
    static func tint(forScore score: Double) -> Color {
        switch score {
        case ..<60:  .dbError
        case ..<80:  .dbWarning
        default:     .dbSuccess
        }
    }

    /// A short Chinese verdict for an overall 0…100 score.
    nonisolated static func verdict(forOverall overall: Double) -> String {
        switch overall {
        case ..<60:  "再练一练，注意发音"
        case ..<75:  "不错，继续加油"
        case ..<90:  "很棒，发音清晰"
        default:     "太厉害了，地道流利！"
        }
    }
}
