//
//  DBAvatar.swift
//  豆包爱学 — Design System
//

import SwiftUI

public struct DBAvatar: View {
    public var name: String
    public var size: CGFloat
    public var gradeBadge: String?

    public init(name: String, size: CGFloat = 48, gradeBadge: String? = nil) {
        self.name = name
        self.size = size
        self.gradeBadge = gradeBadge
    }

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return String(trimmed.prefix(trimmed.first.map { $0.isASCII ? 2 : 1 } ?? 1))
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.dbHeroGradient)
                .frame(width: size, height: size)
                .overlay {
                    Text(initials.isEmpty ? "学" : initials)
                        .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            if let gradeBadge {
                Text(gradeBadge)
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Color.dbSecondary, in: Capsule())
                    .foregroundStyle(.white)
                    .overlay(Capsule().stroke(Color.dbSurface, lineWidth: 1.5))
                    .offset(x: 4, y: 4)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview("Avatar") {
    HStack(spacing: 20) {
        DBAvatar(name: "小明", size: 60, gradeBadge: "五年级")
        DBAvatar(name: "Lily", size: 60)
    }
    .padding().background(Color.dbBackground)
}
