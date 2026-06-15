//
//  ComingSoonView.swift
//  豆包爱学
//
//  Placeholder shown for destinations whose feature view hasn't been wired yet.
//  Replaced per-destination in AppDestinations as features land.
//

import SwiftUI

struct ComingSoonView: View {
    let title: String
    var subtitle: String = "正在为你准备中…"
    var symbol: String = "hammer.fill"

    var body: some View {
        VStack(spacing: DBSpacing.lg) {
            DBMascot(mood: .thinking, size: 96)
            Text(title).font(.dbTitle2).foregroundStyle(Color.dbTextPrimary)
            Text(subtitle).font(.dbCallout).foregroundStyle(Color.dbTextSecondary)
            Label("即将上线", systemImage: symbol).font(.dbFootnote)
                .foregroundStyle(Color.dbSecondary)
                .padding(.horizontal, DBSpacing.md).padding(.vertical, DBSpacing.sm)
                .background(Color.dbSecondarySoft, in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dbBackground)
        .navigationTitle(title)
    }
}

#Preview {
    NavigationStack { ComingSoonView(title: "豆包课堂") }
}
