//
//  DBSectionHeader.swift
//  豆包爱学 — Design System
//

import SwiftUI

public struct DBSectionHeader<Trailing: View>: View {
    public var title: String
    public var subtitle: String?
    public var systemImage: String?
    private let trailing: Trailing

    public init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DBSpacing.sm) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.dbHeadline)
                    .foregroundStyle(Color.dbPrimary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.dbTitle3).foregroundStyle(Color.dbTextPrimary)
                if let subtitle {
                    Text(subtitle).font(.dbFootnote).foregroundStyle(Color.dbTextSecondary)
                }
            }
            Spacer(minLength: DBSpacing.sm)
            trailing
        }
    }
}

#Preview("Section header") {
    VStack(spacing: 20) {
        DBSectionHeader("今日学习", subtitle: "继续上次的内容", systemImage: "sparkles") {
            Button("更多") {}.font(.dbFootnote).buttonStyle(.plain).foregroundStyle(Color.dbPrimary)
        }
        DBSectionHeader("错题本", systemImage: "book.closed.fill")
    }
    .padding().background(Color.dbBackground)
}
