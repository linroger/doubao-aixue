//
//  DBColors.swift
//  豆包爱学 — Design System
//
//  Warm, child-friendly, Dark-Mode-aware palette defined entirely in code
//  (no asset-catalog edits required). All colors are dynamic light/dark.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
#endif

public extension Color {
    /// Build a `Color` from a 24-bit hex value, e.g. `0xFF7A45`.
    init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// A dynamic color that resolves differently in light vs dark appearance.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
        #else
        self = light
        #endif
    }
}

/// Semantic brand palette. Reference as `Color.dbPrimary`, etc.
public extension Color {
    // Brand — warm "豆包" coral/orange with a friendly teal companion.
    static let dbPrimary       = Color(light: Color(hex: 0xFF7A45), dark: Color(hex: 0xFF9466))
    static let dbPrimaryDeep   = Color(light: Color(hex: 0xE85F2A), dark: Color(hex: 0xFF8552))
    static let dbPrimarySoft   = Color(light: Color(hex: 0xFFE7DA), dark: Color(hex: 0x3A2A23))
    static let dbSecondary     = Color(light: Color(hex: 0x2BB3A3), dark: Color(hex: 0x45CBBA))
    static let dbSecondarySoft = Color(light: Color(hex: 0xDDF3F0), dark: Color(hex: 0x213230))
    static let dbAccent        = Color(light: Color(hex: 0xFFC24B), dark: Color(hex: 0xFFD06B))
    static let dbAccentSoft    = Color(light: Color(hex: 0xFFF2D6), dark: Color(hex: 0x35301F))

    // Surfaces & backgrounds.
    static let dbBackground    = Color(light: Color(hex: 0xF7F7FB), dark: Color(hex: 0x0E0E12))
    static let dbBackgroundAlt = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x16161C))
    static let dbSurface       = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1C1C24))
    static let dbSurfaceRaised = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x24242E))
    static let dbSeparator     = Color(light: Color(hex: 0xE6E6EE), dark: Color(hex: 0x2C2C36))

    // Text.
    static let dbTextPrimary   = Color(light: Color(hex: 0x1B1B26), dark: Color(hex: 0xF2F2F7))
    static let dbTextSecondary = Color(light: Color(hex: 0x6A6A7C), dark: Color(hex: 0x9B9BAB))
    static let dbTextTertiary  = Color(light: Color(hex: 0x9A9AAB), dark: Color(hex: 0x6E6E7E))
    static let dbOnPrimary     = Color.white

    // Status.
    static let dbSuccess = Color(light: Color(hex: 0x2FB36B), dark: Color(hex: 0x4CCB86))
    static let dbWarning = Color(light: Color(hex: 0xE8A53A), dark: Color(hex: 0xFFC061))
    static let dbError   = Color(light: Color(hex: 0xE5484D), dark: Color(hex: 0xFF6B70))
    static let dbInfo    = Color(light: Color(hex: 0x3E78F0), dark: Color(hex: 0x6F9BFF))

    static let dbSuccessSoft = Color(light: Color(hex: 0xDFF5E9), dark: Color(hex: 0x16291F))
    static let dbErrorSoft   = Color(light: Color(hex: 0xFCE3E4), dark: Color(hex: 0x2C1A1B))

    /// Hero gradient used on the Home camera entry and onboarding.
    static var dbHeroGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xFF8A5B), Color(hex: 0xFF6F61), Color(hex: 0xF1556B)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

/// Per-subject accent color used by chips, tiles, and the knowledge graph.
public enum DBSubjectColor {
    public static func color(for subject: Subject) -> Color {
        switch subject {
        case .math:      Color(light: Color(hex: 0x3E78F0), dark: Color(hex: 0x6F9BFF))
        case .physics:   Color(light: Color(hex: 0x7C5CFF), dark: Color(hex: 0x9D86FF))
        case .chemistry: Color(light: Color(hex: 0x2BB3A3), dark: Color(hex: 0x45CBBA))
        case .biology:   Color(light: Color(hex: 0x2FB36B), dark: Color(hex: 0x4CCB86))
        case .chinese:   Color(light: Color(hex: 0xE5484D), dark: Color(hex: 0xFF6B70))
        case .english:   Color(light: Color(hex: 0xFF7A45), dark: Color(hex: 0xFF9466))
        case .science:   Color(light: Color(hex: 0x12A5C9), dark: Color(hex: 0x4CC6E5))
        case .history:   Color(light: Color(hex: 0xB07A2E), dark: Color(hex: 0xD0A05A))
        case .geography: Color(light: Color(hex: 0x2E9E8F), dark: Color(hex: 0x57C2B2))
        case .politics:  Color(light: Color(hex: 0xC0476F), dark: Color(hex: 0xE0708F))
        case .general:   Color(light: Color(hex: 0x6A6A7C), dark: Color(hex: 0x9B9BAB))
        }
    }
}
