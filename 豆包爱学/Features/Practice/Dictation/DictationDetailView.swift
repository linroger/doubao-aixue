//
//  DictationDetailView.swift
//  豆包爱学 — Features/Practice/Dictation
//
//  Pushed destination for Route.dictation(UUID). Loads the chosen DictationList
//  from SwiftData and drives the three-phase session (read-aloud → 默写 → 批改)
//  through a single DictationSessionModel. Handles the "list went missing" state.
//

import SwiftUI
import SwiftData

struct DictationDetailView: View {
    let listID: UUID

    @Environment(\.intelligence) private var intelligence
    @Environment(\.ocr) private var ocr
    @Environment(TTSService.self) private var tts
    @Environment(\.modelContext) private var modelContext

    @Query private var lists: [DictationList]

    @State private var model: DictationSessionModel?

    init(listID: UUID) {
        self.listID = listID
        _lists = Query(filter: #Predicate<DictationList> { $0.id == listID },
                       sort: \DictationList.createdAt, order: .forward)
    }

    private var list: DictationList? { lists.first }

    var body: some View {
        Group {
            if let list {
                if let model {
                    DictationSessionView(model: model, listName: list.name)
                } else {
                    // Building the session model the first time the list resolves.
                    Color.dbBackground
                        .task { ensureModel(for: list) }
                }
            } else {
                DBStateView(kind: .error,
                            title: "找不到这张听写表",
                            message: "它可能已被删除，返回上一页再试试吧。",
                            systemImage: "questionmark.folder")
            }
        }
        .background(Color.dbBackground)
        .navigationTitle(list?.name.isEmpty == false ? list!.name : "听写")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func ensureModel(for list: DictationList) {
        guard model == nil else { return }
        model = DictationSessionModel(
            list: list,
            intelligence: intelligence,
            ocr: ocr,
            tts: tts,
            modelContext: modelContext
        )
    }
}

#Preview("有词表") {
    NavigationStack {
        DictationDetailPreviewLoader()
    }
    .modelContainer(PreviewSampleData.container)
    .environment(AppRouter())
    .environment(TTSService())
}

/// Resolves a seeded list's id so the detail preview has real data to render.
private struct DictationDetailPreviewLoader: View {
    @Query(sort: \DictationList.createdAt, order: .forward) private var lists: [DictationList]
    var body: some View {
        if let id = lists.first?.id {
            DictationDetailView(listID: id)
        } else {
            DBStateView(kind: .loading, title: "加载中")
        }
    }
}
