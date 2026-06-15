//
//  DBButtonStyle.swift
//  豆包爱学 — Design System
//

import SwiftUI

public enum DBButtonVariant {
    case primary, secondary, ghost, destructive
}

public struct DBButtonStyle: ButtonStyle {
    public var variant: DBButtonVariant
    public var fullWidth: Bool

    public init(_ variant: DBButtonVariant = .primary, fullWidth: Bool = false) {
        self.variant = variant
        self.fullWidth = fullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dbBodyEmph)
            .foregroundStyle(foreground)
            .padding(.vertical, DBSpacing.md)
            .padding(.horizontal, DBSpacing.xl)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(background, in: Capsule(style: .continuous))
            .overlay {
                if variant == .ghost {
                    Capsule(style: .continuous).strokeBorder(Color.dbSeparator, lineWidth: 1)
                }
            }
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary, .destructive: .white
        case .secondary: .dbPrimaryDeep
        case .ghost: .dbTextPrimary
        }
    }

    private var background: AnyShapeStyle {
        switch variant {
        case .primary: AnyShapeStyle(Color.dbHeroGradient)
        case .secondary: AnyShapeStyle(Color.dbPrimarySoft)
        case .ghost: AnyShapeStyle(Color.clear)
        case .destructive: AnyShapeStyle(Color.dbError)
        }
    }
}

public extension ButtonStyle where Self == DBButtonStyle {
    static func db(_ variant: DBButtonVariant = .primary, fullWidth: Bool = false) -> DBButtonStyle {
        DBButtonStyle(variant, fullWidth: fullWidth)
    }
}

#Preview("Buttons") {
    VStack(spacing: 14) {
        Button("开始讲解") {}.buttonStyle(.db(.primary, fullWidth: true))
        Button("加入错题本") {}.buttonStyle(.db(.secondary))
        Button("稍后再说") {}.buttonStyle(.db(.ghost))
        Button("删除") {}.buttonStyle(.db(.destructive))
    }
    .padding()
    .background(Color.dbBackground)
}
