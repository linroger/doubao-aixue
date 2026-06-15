//
//  DBShadow.swift
//  豆包爱学 — Design System
//
//  Soft elevation shadows + reusable card-surface modifier.
//

import SwiftUI

public enum DBElevation {
    case none, low, medium, high
}

private struct DBShadowModifier: ViewModifier {
    let elevation: DBElevation
    func body(content: Content) -> some View {
        switch elevation {
        case .none:
            content
        case .low:
            content.shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 3)
        case .medium:
            content.shadow(color: .black.opacity(0.09), radius: 12, x: 0, y: 6)
        case .high:
            content.shadow(color: .black.opacity(0.12), radius: 22, x: 0, y: 12)
        }
    }
}

public extension View {
    /// Apply a soft, theme-consistent elevation shadow.
    func dbShadow(_ elevation: DBElevation = .low) -> some View {
        modifier(DBShadowModifier(elevation: elevation))
    }

    /// Wrap content in the standard rounded surface (background + radius + shadow).
    func dbSurfaceStyle(
        cornerRadius: CGFloat = DBRadius.lg,
        fill: Color = .dbSurface,
        elevation: DBElevation = .low
    ) -> some View {
        self
            .background(fill, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .dbShadow(elevation)
    }
}
