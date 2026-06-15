//
//  DBToolTile.swift
//  豆包爱学 — Design System
//
//  Colorful rounded tile used in the 工具 hub and Home quick-entries.
//

import SwiftUI

public struct DBToolTile: View {
    public var title: String
    public var systemImage: String
    public var tint: Color
    public var subtitle: String?
    public var compact: Bool
    public var action: () -> Void

    public init(
        title: String,
        systemImage: String,
        tint: Color = .dbPrimary,
        subtitle: String? = nil,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.subtitle = subtitle
        self.compact = compact
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            if compact {
                VStack(spacing: DBSpacing.sm) {
                    icon
                    Text(title).font(.dbFootnote.weight(.medium))
                        .foregroundStyle(Color.dbTextPrimary).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DBSpacing.md)
            } else {
                HStack(spacing: DBSpacing.md) {
                    icon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.dbBodyEmph).foregroundStyle(Color.dbTextPrimary)
                        if let subtitle {
                            Text(subtitle).font(.dbCaption).foregroundStyle(Color.dbTextSecondary).lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(DBSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .dbSurfaceStyle(cornerRadius: DBRadius.md)
            }
        }
        .buttonStyle(.plain)
    }

    private var icon: some View {
        Image(systemName: systemImage)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 46, height: 46)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: DBRadius.sm, style: .continuous))
    }
}

#Preview("Tool tiles") {
    VStack(spacing: 14) {
        LazyVGrid(columns: Array(repeating: GridItem(), count: 4), spacing: 12) {
            ForEach(ToolKind.allCases.prefix(8)) { tool in
                DBToolTile(title: tool.displayName, systemImage: tool.symbolName,
                           tint: .dbPrimary, compact: true) {}
            }
        }
        DBToolTile(title: "作文批改", systemImage: "text.badge.checkmark",
                   tint: .dbSecondary, subtitle: "综合点评·分句批改·升格作文") {}
    }
    .padding().background(Color.dbBackground)
}
