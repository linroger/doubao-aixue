//
//  DBChip.swift
//  豆包爱学 — Design System
//
//  Pill chips & tags for subjects, filters, knowledge points, suggestions.
//

import SwiftUI

public struct DBChip: View {
    public var title: String
    public var systemImage: String?
    public var tint: Color
    public var isSelected: Bool

    public init(_ title: String, systemImage: String? = nil, tint: Color = .dbPrimary, isSelected: Bool = false) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.isSelected = isSelected
    }

    public var body: some View {
        HStack(spacing: DBSpacing.xs) {
            if let systemImage { Image(systemName: systemImage).font(.dbCaption) }
            Text(title).font(.dbFootnote.weight(.medium))
        }
        .padding(.horizontal, DBSpacing.md)
        .padding(.vertical, DBSpacing.sm - 2)
        .foregroundStyle(isSelected ? Color.dbOnPrimary : tint)
        .background(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14)),
                    in: Capsule(style: .continuous))
    }
}

/// A small static label tag (non-interactive), e.g. priority or status.
public struct DBTag: View {
    public var text: String
    public var tint: Color
    public init(_ text: String, tint: Color = .dbSecondary) {
        self.text = text
        self.tint = tint
    }
    public var body: some View {
        Text(text)
            .font(.dbCaption2.weight(.semibold))
            .padding(.horizontal, DBSpacing.sm)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: DBRadius.xs, style: .continuous))
    }
}

/// Convenience subject chip.
public struct DBSubjectChip: View {
    public var subject: Subject
    public var isSelected: Bool
    public init(_ subject: Subject, isSelected: Bool = false) {
        self.subject = subject
        self.isSelected = isSelected
    }
    public var body: some View {
        DBChip(subject.displayName, systemImage: subject.symbolName,
               tint: DBSubjectColor.color(for: subject), isSelected: isSelected)
    }
}

#Preview("Chips") {
    VStack(alignment: .leading, spacing: 12) {
        HStack { ForEach(Subject.allCases.prefix(4)) { DBSubjectChip($0, isSelected: $0 == .math) } }
        HStack { DBTag("P0"); DBTag("已掌握", tint: .dbSuccess); DBTag("薄弱", tint: .dbError) }
    }
    .padding().background(Color.dbBackground)
}
