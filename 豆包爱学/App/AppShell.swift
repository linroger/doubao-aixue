//
//  AppShell.swift
//  豆包爱学
//
//  Adaptive navigation shell: TabView on iPhone (compact), NavigationSplitView
//  on iPad/Mac (regular). Shared Route destinations and modal sheets.
//

import SwiftUI

struct AppShell: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase

    private var isRegular: Bool { sizeClass != .compact }

    var body: some View {
        @Bindable var router = router
        Group {
            if isRegular {
                splitView
            } else {
                tabView
            }
        }
        .tint(Color.dbPrimary)
        .sheet(item: $router.presentedSheet) { sheet in
            AppDestinations.sheetView(sheet)
        }
        // Consume any pending App Intent / Siri / Spotlight signal once the shell
        // is on-screen (first launch) and whenever the app returns to active —
        // which is exactly when an `openAppWhenRun` intent foregrounds us.
        .task { consumePendingIntent() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { consumePendingIntent() }
        }
    }

    /// Reads-and-clears the durable intent mailbox and deep-links accordingly.
    private func consumePendingIntent() {
        if let signal = PendingIntentStore.shared.consume() {
            router.handle(signal, regular: isRegular)
        }
    }

    // MARK: iPhone tabs

    private var tabView: some View {
        @Bindable var router = router
        return TabView(selection: $router.selectedTab) {
            ForEach(AppTab.allCases) { tab in
                NavigationStack(path: router.path(for: tab)) {
                    AppDestinations.tabRoot(tab)
                        .navigationDestination(for: Route.self) { AppDestinations.routeView($0) }
                }
                .tabItem { Label(tab.displayName, systemImage: tab.symbol) }
                .tag(tab)
            }
        }
    }

    // MARK: iPad / Mac split view

    private var splitView: some View {
        @Bindable var router = router
        return NavigationSplitView {
            List(AppSection.allCases, selection: $router.sidebarSelection) { section in
                Label(section.displayName, systemImage: section.symbol).tag(section)
            }
            .navigationTitle("豆包爱学")
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 200, ideal: 232)
            #endif
            .toolbar {
                ToolbarItem {
                    Button {
                        router.present(.capture(.solve))
                    } label: { Label("拍照解题", systemImage: "camera.viewfinder") }
                }
            }
        } detail: {
            NavigationStack(path: $router.detailPath) {
                AppDestinations.sectionRoot(router.sidebarSelection ?? .home)
                    .navigationDestination(for: Route.self) { AppDestinations.routeView($0) }
            }
        }
    }
}
