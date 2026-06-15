//
//  ToolsHubView.swift
//  豆包爱学 — Features/Tools
//
//  WAVE-0 PLACEHOLDER (replaced by the Tools feature agent in Wave 1).
//  Contract: `struct ToolsHubView: View` with a no-arg `init()`.
//

import SwiftUI

struct ToolsHubView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var isRegular: Bool { sizeClass != .compact }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.xl) {
                ForEach(ToolCategory.allCases) { category in
                    let tools = ToolKind.allCases.filter { $0.category == category }
                    if !tools.isEmpty {
                        VStack(alignment: .leading, spacing: DBSpacing.sm) {
                            DBSectionHeader(category.displayName)
                            LazyVGrid(columns: Array(repeating: GridItem(spacing: 12), count: isRegular ? 5 : 4), spacing: 12) {
                                ForEach(tools) { tool in
                                    DBToolTile(title: tool.displayName, systemImage: tool.symbolName,
                                               tint: .dbPrimary, compact: true) {
                                        router.openTool(tool, regular: isRegular)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(DBSpacing.screenInset)
        }
        .background(Color.dbBackground)
        .navigationTitle("工具")
    }
}
