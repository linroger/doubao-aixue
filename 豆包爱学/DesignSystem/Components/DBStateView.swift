//
//  DBStateView.swift
//  豆包爱学 — Design System
//
//  The cross-cutting state system (RESEARCH F59). Every async screen routes
//  through `ViewState` so empty/loading/error/offline are handled consistently.
//

import SwiftUI

/// Generic async screen/section state.
public enum ViewState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty(message: String)
    case error(message: String)
    case offline(message: String)

    public var value: Value? {
        if case let .loaded(v) = self { return v }
        return nil
    }
    public var isLoading: Bool { if case .loading = self { return true }; return false }
}

/// A friendly placeholder for empty/loading/error/offline states.
public struct DBStateView: View {
    public enum Kind { case empty, loading, error, offline, success }

    public var kind: Kind
    public var title: String
    public var message: String?
    public var systemImage: String?
    public var retry: (() -> Void)?

    public init(
        kind: Kind,
        title: String,
        message: String? = nil,
        systemImage: String? = nil,
        retry: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.retry = retry
    }

    public var body: some View {
        VStack(spacing: DBSpacing.lg) {
            artwork
            VStack(spacing: DBSpacing.xs) {
                Text(title).font(.dbHeadline).foregroundStyle(Color.dbTextPrimary)
                if let message {
                    Text(message)
                        .font(.dbCallout)
                        .foregroundStyle(Color.dbTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            if let retry {
                Button("重试", action: retry).buttonStyle(.db(.secondary))
            }
        }
        .padding(DBSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var artwork: some View {
        switch kind {
        case .loading:
            ProgressView().controlSize(.large).tint(Color.dbPrimary)
        case .empty:
            DBMascot(mood: .sleepy, size: 88)
        case .error:
            DBMascot(mood: .thinking, size: 88)
        case .offline:
            Image(systemName: systemImage ?? "wifi.slash")
                .font(.system(size: 52)).foregroundStyle(Color.dbTextTertiary)
        case .success:
            DBMascot(mood: .cheering, size: 88)
        }
    }
}

/// Drives content from a `ViewState`, rendering the right placeholder otherwise.
public struct DBStateContainer<Value, Content: View>: View {
    public var state: ViewState<Value>
    public var retry: (() -> Void)?
    private let content: (Value) -> Content

    public init(
        _ state: ViewState<Value>,
        retry: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.state = state
        self.retry = retry
        self.content = content
    }

    public var body: some View {
        switch state {
        case .idle, .loading:
            DBStateView(kind: .loading, title: "加载中…")
        case let .loaded(value):
            content(value)
        case let .empty(message):
            DBStateView(kind: .empty, title: "暂无内容", message: message)
        case let .error(message):
            DBStateView(kind: .error, title: "出错了", message: message, retry: retry)
        case let .offline(message):
            DBStateView(kind: .offline, title: "离线模式", message: message, retry: retry)
        }
    }
}

#Preview("States") {
    TabView {
        DBStateView(kind: .empty, title: "还没有错题", message: "保持得很棒，继续加油！").tabItem { Text("Empty") }
        DBStateView(kind: .error, title: "出错了", message: "请稍后重试", retry: {}).tabItem { Text("Error") }
        DBStateView(kind: .loading, title: "正在思考…").tabItem { Text("Loading") }
    }
    .background(Color.dbBackground)
}
