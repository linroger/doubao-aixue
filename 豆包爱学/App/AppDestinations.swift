//
//  AppDestinations.swift
//  豆包爱学
//
//  Central view factory mapping tabs / sidebar sections / routes / sheets to
//  feature views. This is the ONE integration seam between navigation and
//  features. Every destination now resolves to a real feature view (Wave 0–2).
//

import SwiftUI

@MainActor
enum AppDestinations {

    // MARK: Tab roots (iPhone)

    @ViewBuilder
    static func tabRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .home:  HomeView()
        case .study: StudyView()
        case .tools: ToolsHubView()
        case .me:    ProfileView()
        }
    }

    // MARK: Sidebar section roots (iPad/Mac)

    @ViewBuilder
    static func sectionRoot(_ section: AppSection) -> some View {
        switch section {
        case .home:           HomeView()
        case .classroom:      StudyView()
        case .documents:      DocumentQAView()
        case .mistakes:       MistakeNotebookView()
        case .knowledgeGraph: KnowledgeGraphView()
        case .reports:        ReportsView()
        case .companion:      CompanionView()
        case .tools:          ToolsHubView()
        case .profile:        ProfileView()
        }
    }

    // MARK: Push routes

    @ViewBuilder
    static func routeView(_ route: Route) -> some View {
        switch route {
        case .tool(let tool):           toolView(tool)
        case .mistakeDetail(let id):    MistakeDetailView(mistakeID: id)
        case .course(let id):           CourseDetailView(courseID: id)
        case .knowledgePoint(let id):   KnowledgePointView(knowledgePointID: id)
        case .conversation(let id):     ConversationView(conversationID: id)
        case .wordDeck(let id):         WordDeckReviewView(deckID: id)
        case .dictation(let id):        DictationDetailView(listID: id)
        case .document(let id):         DocumentDetailView(documentID: id)
        case .drill(let kpID):          DrillView(targetKnowledgePointID: kpID)
        case .reports:                  ReportsView()
        case .achievements:             AchievementsView()
        }
    }

    /// Every utility surfaced in the 工具 hub and deep-linked from Home / Companion.
    /// Exhaustive over `ToolKind` so a newly added tool can't silently fall through.
    @ViewBuilder
    private static func toolView(_ tool: ToolKind) -> some View {
        switch tool {
        case .solve:             CaptureSolveView(mode: .solve)
        case .gradeArithmetic:   ArithmeticGradingView()
        case .gradeEssay:        EssayGradingView()
        case .mistakeNotebook:   MistakeNotebookView()
        case .dictation:         DictationView()
        case .vocabulary:        VocabularyView()
        case .oral:              OralPracticeView()
        case .translation:       TranslationView()
        case .knowledgeQA:       CompanionView()
        case .classical:         ClassicalView()
        case .documentQA:        DocumentQAView()
        case .recognizeAnything: RecognizeAnythingView()
        case .classroom:         StudyView()
        case .knowledgeGraph:    KnowledgeGraphView()
        case .drill:             DrillView()
        case .reports:           ReportsView()
        case .today:             TodayView()
        case .calculator:        CalculatorView()
        case .focus:             FocusTimerView()
        case .liveScan:          SolveLiveScanView()
        case .achievements:      AchievementsView()
        }
    }

    // MARK: Modal sheets

    @ViewBuilder
    static func sheetView(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .capture(let mode):
            // Solve uses its own self-contained capture flow; grade uses the
            // dedicated 口算批改 grader (wrapped to provide a nav bar + Done).
            switch mode {
            case .solve:
                CaptureSolveView(mode: .solve)
            case .grade:
                SheetScaffold(title: "口算批改") { ArithmeticGradingView() }
            }
        case .tutor(let text, let subject, let grade):
            // TutorSessionView supplies its own toolbar (needs a stack ancestor).
            NavigationStack {
                TutorSessionView(problemText: text, subject: subject, grade: grade)
            }
        case .parentGate(let reason):
            // ParentModeView is a plain scroll surface (gate → controls); the
            // scaffold supplies the nav bar + 完成 button.
            SheetScaffold(title: "家长模式") {
                ParentModeView(reason: reason)
            }
        case .search:
            // SearchView is documented to rely on SheetScaffold for its stack + Done.
            SheetScaffold(title: "搜索") {
                SearchView()
            }
        }
    }
}

/// A sheet wrapper providing a navigation bar with a Done button.
struct SheetScaffold<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { dismiss() }
                    }
                }
        }
    }
}
