//
//  DBTypography.swift
//  豆包爱学 — Design System
//
//  Rounded, friendly type scale. Use `Font.db*` everywhere for consistency.
//  All sizes are Dynamic-Type relative (via `.system(_:design:)`).
//

import SwiftUI

public extension Font {
    static let dbLargeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let dbTitle      = Font.system(.title, design: .rounded, weight: .bold)
    static let dbTitle2     = Font.system(.title2, design: .rounded, weight: .semibold)
    static let dbTitle3     = Font.system(.title3, design: .rounded, weight: .semibold)
    static let dbHeadline   = Font.system(.headline, design: .rounded, weight: .semibold)
    static let dbBody       = Font.system(.body, design: .rounded)
    static let dbBodyEmph   = Font.system(.body, design: .rounded, weight: .semibold)
    static let dbCallout    = Font.system(.callout, design: .rounded)
    static let dbSubheadline = Font.system(.subheadline, design: .rounded)
    static let dbFootnote   = Font.system(.footnote, design: .rounded)
    static let dbCaption    = Font.system(.caption, design: .rounded)
    static let dbCaption2   = Font.system(.caption2, design: .rounded)

    /// Numeric/monospaced-digit body for scores, timers, counters.
    static let dbMonoBody   = Font.system(.body, design: .rounded).monospacedDigit()
    static let dbScore      = Font.system(size: 34, weight: .bold, design: .rounded).monospacedDigit()
}

public extension Text {
    /// Apply the primary heading style in one call.
    func dbSectionTitle() -> some View {
        self.font(.dbTitle3).foregroundStyle(Color.dbTextPrimary)
    }
}
