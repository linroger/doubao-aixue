//
//  ToolsHubView.swift
//  豆包爱学 — Features/Tools
//
//  全部工具 — the searchable, category-grouped hub for every utility in the app.
//  Each tile is tinted by its category (shared with Home via ToolKind.tileTint),
//  section headers carry an icon + subtitle, and an in-page search field filters
//  tools by name. Root for both the iPhone 工具 tab and the iPad/Mac sidebar.
//
//  Contract: `struct ToolsHubView: View` with a no-arg `init()`.
//

import SwiftUI

struct ToolsHubView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var query = ""

    private var isRegular: Bool { sizeClass != .compact }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: DBSpacing.md),
              count: isRegular ? 5 : 4)
    }

    private func tools(in category: ToolCategory) -> [ToolKind] {
        ToolKind.allCases
            .filter { $0.category == category }
            .filter { query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query) }
    }

    private var hasResults: Bool {
        ToolCategory.allCases.contains { !tools(in: $0).isEmpty }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.xl) {
                DBSearchField(text: $query, placeholder: "搜索工具，如「作业批改」「听写」")

                if !hasResults {
                    DBStateView(kind: .empty, title: "没有找到工具",
                                message: "换个关键词试试，或清空搜索查看全部工具。")
                        .frame(minHeight: 240)
                } else {
                    ForEach(ToolCategory.allCases) { category in
                        let categoryTools = tools(in: category)
                        if !categoryTools.isEmpty {
                            VStack(alignment: .leading, spacing: DBSpacing.sm) {
                                DBSectionHeader(category.displayName,
                                                subtitle: category.subtitle,
                                                systemImage: category.symbolName)
                                LazyVGrid(columns: columns, spacing: DBSpacing.md) {
                                    ForEach(categoryTools) { tool in
                                        DBToolTile(title: tool.displayName,
                                                   systemImage: tool.symbolName,
                                                   tint: tool.tileTint, compact: true) {
                                            router.openTool(tool, regular: isRegular)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(DBSpacing.screenInset)
            .frame(maxWidth: 880)
            .frame(maxWidth: .infinity)
        }
        .background(Color.dbBackground)
        .navigationTitle("工具")
    }
}

#Preview("工具") {
    NavigationStack { ToolsHubView() }
        .environment(AppRouter())
}
