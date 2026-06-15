//
//  LiquidGlass.swift
//  豆包爱学 — Design System
//
//  Liquid Glass (iOS/macOS 26) helpers with graceful material fallback.
//  Min deployment is 26, but availability guards keep the code defensive.
//

import SwiftUI

public extension View {
    /// Apply a Liquid Glass capsule/shape effect, falling back to a material.
    @ViewBuilder
    func dbGlass(in shape: some Shape = Capsule(style: .continuous)) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }

    /// Glass for floating action elements (interactive, tinted).
    @ViewBuilder
    func dbGlassProminent(in shape: some Shape = Capsule(style: .continuous)) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: shape)
        } else {
            self.background(.thinMaterial, in: shape)
        }
    }

    /// A glass-backed bar/surface (toolbars, floating panels).
    @ViewBuilder
    func dbGlassSurface(cornerRadius: CGFloat = DBRadius.lg) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}
