//
//  AppRouter.swift
//  豆包爱学
//
//  Single navigation source of truth. Tabs on iPhone, sidebar sections on
//  iPad/Mac, shared typed Routes for push destinations, and modal sheets.
//

import SwiftUI

// MARK: - Tabs (iPhone)

public enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case home, study, tools, me
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .home: "首页"
        case .study: "学习"
        case .tools: "工具"
        case .me: "我的"
        }
    }
    public var symbol: String {
        switch self {
        case .home: "house.fill"
        case .study: "play.tv.fill"
        case .tools: "square.grid.2x2.fill"
        case .me: "person.crop.circle.fill"
        }
    }
}

// MARK: - Sidebar sections (iPad/Mac)

public enum AppSection: Hashable, Identifiable, Sendable, CaseIterable {
    case home, classroom, documents, mistakes, knowledgeGraph, reports, companion, tools, profile
    public var id: Self { self }
    public var displayName: String {
        switch self {
        case .home: "首页"
        case .classroom: "豆包课堂"
        case .documents: "文档问答"
        case .mistakes: "错题本"
        case .knowledgeGraph: "知识图谱"
        case .reports: "学习报告"
        case .companion: "AI 伙伴"
        case .tools: "全部工具"
        case .profile: "我的"
        }
    }
    public var symbol: String {
        switch self {
        case .home: "house.fill"
        case .classroom: "play.tv.fill"
        case .documents: "doc.text.magnifyingglass"
        case .mistakes: "book.closed.fill"
        case .knowledgeGraph: "point.3.connected.trianglepath.dotted"
        case .reports: "chart.bar.xaxis"
        case .companion: "bubble.left.and.bubble.right.fill"
        case .tools: "square.grid.2x2.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

// MARK: - Push routes

public enum Route: Hashable, Sendable {
    case tool(ToolKind)
    case mistakeDetail(UUID)
    case course(UUID)
    case knowledgePoint(String)
    case conversation(UUID)
    case wordDeck(UUID)
    case dictation(UUID)
    case document(UUID)
    /// 举一反三 / 靶向练习, optionally pre-targeted at one knowledge point so a weak
    /// point (Home), a mistake, a report card, or a knowledge-point screen can launch
    /// practice already focused on the right thing. `nil` opens the generic picker.
    case drill(knowledgePointID: String?)
    case reports
    case achievements
}

// MARK: - Modal sheets

public enum AppSheet: Identifiable, Sendable {
    case capture(CaptureMode)
    case tutor(problemText: String, subject: Subject, grade: GradeLevel)
    case parentGate(reason: String)
    case search

    public var id: String {
        switch self {
        case .capture(let m): "capture-\(m.rawValue)"
        case .tutor(let t, _, _): "tutor-\(t.hashValue)"
        case .parentGate: "parentGate"
        case .search: "search"
        }
    }
}

// MARK: - Router

@MainActor
@Observable
public final class AppRouter {
    public var selectedTab: AppTab = .home
    public var sidebarSelection: AppSection? = .home
    public var presentedSheet: AppSheet?

    private var paths: [AppTab: NavigationPath] = [:]
    public var detailPath = NavigationPath()      // iPad/Mac detail column

    public init() {}

    public func path(for tab: AppTab) -> Binding<NavigationPath> {
        Binding(
            get: { [weak self] in self?.paths[tab] ?? NavigationPath() },
            set: { [weak self] in self?.paths[tab] = $0 }
        )
    }

    public func navigate(_ route: Route, regular: Bool) {
        if regular {
            detailPath.append(route)
        } else {
            paths[selectedTab, default: NavigationPath()].append(route)
        }
    }

    public func present(_ sheet: AppSheet) { presentedSheet = sheet }

    public func popToRoot(regular: Bool) {
        if regular { detailPath = NavigationPath() }
        else { paths[selectedTab] = NavigationPath() }
    }

    /// Launch a tool from anywhere (Home tiles, Tools hub, Companion intents).
    public func openTool(_ tool: ToolKind, regular: Bool) {
        switch tool {
        case .solve, .gradeArithmetic:
            present(.capture(tool == .solve ? .solve : .grade))
        default:
            navigate(.tool(tool), regular: regular)
        }
    }

    /// Open 举一反三 already focused on a specific knowledge point (or `nil` for the
    /// generic picker). Used by Home's 今日靶向练习, a mistake's 举一反三, a report's
    /// 专项练习, and a knowledge point's 去练习 — so practice always lands on target.
    public func openDrill(knowledgePointID: String?, regular: Bool) {
        navigate(.drill(knowledgePointID: knowledgePointID), regular: regular)
    }

    /// Deep-link from an App Intent / Siri / Spotlight signal, consumed once when
    /// the app becomes active (see `AppShell`). `regular` selects the iPad/Mac
    /// (split-view) vs iPhone (tab) routing idiom.
    public func handle(_ signal: PendingIntentSignal, regular: Bool) {
        switch signal {
        case .solveProblem:
            // The capture-and-solve flow is a self-contained sheet on both idioms.
            present(.capture(.solve))
        case .startDictation:
            if regular {
                sidebarSelection = .tools
            } else {
                selectedTab = .tools
            }
            openTool(.dictation, regular: regular)
        case .reviewMistakes:
            if regular {
                sidebarSelection = .mistakes
            } else {
                selectedTab = .tools
                openTool(.mistakeNotebook, regular: false)
            }
        case .startTutor(let prompt):
            present(.tutor(problemText: prompt ?? "", subject: .general, grade: .g6))
        }
    }
}

// AppRouter is injected as an @Observable object: `.environment(router)` at the
// root, read via `@Environment(AppRouter.self) private var router`.
