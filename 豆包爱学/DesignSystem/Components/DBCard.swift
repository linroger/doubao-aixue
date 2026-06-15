//
//  DBCard.swift
//  豆包爱学 — Design System
//
//  Rounded surface container used throughout the app.
//

import SwiftUI

public struct DBCard<Content: View>: View {
    private let content: Content
    private let padding: CGFloat
    private let cornerRadius: CGFloat
    private let fill: Color
    private let elevation: DBElevation

    public init(
        padding: CGFloat = DBSpacing.lg,
        cornerRadius: CGFloat = DBRadius.lg,
        fill: Color = .dbSurface,
        elevation: DBElevation = .low,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.fill = fill
        self.elevation = elevation
        self.content = content()
    }

    public var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dbSurfaceStyle(cornerRadius: cornerRadius, fill: fill, elevation: elevation)
    }
}

#Preview("DBCard") {
    VStack(spacing: 16) {
        DBCard {
            VStack(alignment: .leading, spacing: 6) {
                Text("今日靶向练习").font(.dbHeadline)
                Text("5–10 分钟巩固薄弱知识点").font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
            }
        }
        DBCard(fill: .dbPrimarySoft, elevation: .none) {
            Label("错题已自动收录", systemImage: "checkmark.seal.fill")
                .foregroundStyle(Color.dbPrimaryDeep)
        }
    }
    .padding()
    .background(Color.dbBackground)
}
