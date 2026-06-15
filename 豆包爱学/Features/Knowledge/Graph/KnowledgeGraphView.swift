//
//  KnowledgeGraphView.swift
//  豆包爱学 — Features/Knowledge/Graph
//
//  知识图谱 (RESEARCH F13 / F39 / F44): 把 @Query 读到的 KnowledgePointEntity +
//  MasteryRecord 折叠成一张可缩放的概念地图。用 Canvas 画 node-link 思维导图，
//  节点按掌握度 (MasteryState) 着色；下方用 Swift Charts 画一张 学科 × 掌握档位
//  的「掌握度热力图」。支持学科筛选、双指缩放 / 拖拽平移、点击节点弹出详情面板，
//  面板里可「讲一讲」(router.navigate(.knowledgePoint(id))) 与「去练习」
//  (router.openTool(.drill, ...))。
//
//  Wired to AppSection.knowledgeGraph / ToolKind.knowledgeGraph.
//
//  纯布局/聚合逻辑全部委托给 KnowledgeGraphModel.swift 里的 nonisolated 助手；
//  本视图只负责把快照渲染成 SwiftUI，并处理所有状态。
//

import SwiftUI
import SwiftData
import Charts

struct KnowledgeGraphView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    @Query(sort: \KnowledgePointEntity.name) private var points: [KnowledgePointEntity]
    @Query private var masteries: [MasteryRecord]

    @State private var subjectFilter: Subject?
    @State private var selectedNodeID: String?

    private var isRegular: Bool { sizeClass != .compact }

    // MARK: Derived data (在 @MainActor 上把 @Model 安全拷成纯快照后再交给布局)

    private var allNodes: [KnowledgeGraphNode] {
        let pointSnaps = points.map(KnowledgePointSnapshot.init)
        let masterySnaps = masteries.map(MasterySnapshot.init)
        return KnowledgeGraphBuilder.makeNodes(points: pointSnaps, masteries: masterySnaps)
    }

    private var subjectsPresent: [Subject] {
        KnowledgeGraphBuilder.orderedSubjects(in: allNodes)
    }

    /// 当前筛选下的节点。
    private var nodes: [KnowledgeGraphNode] {
        guard let subjectFilter else { return allNodes }
        return allNodes.filter { $0.subject == subjectFilter }
    }

    private var links: [KnowledgeGraphLink] {
        KnowledgeGraphBuilder.makeLinks(for: nodes)
    }

    private var selectedNode: KnowledgeGraphNode? {
        guard let selectedNodeID else { return nil }
        return nodes.first { $0.id == selectedNodeID }
    }

    // MARK: Body

    var body: some View {
        Group {
            if points.isEmpty {
                DBStateView(
                    kind: .empty, title: "知识图谱还在生长",
                    message: "做题、听讲、复习后，你掌握的知识点会在这里连成一张地图～",
                    systemImage: "point.3.connected.trianglepath.dotted")
            } else {
                content
            }
        }
        .background(Color.dbBackground)
        .navigationTitle("知识图谱")
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                subjectFilterBar
                summaryStats
                graphCard
                heatmapCard
                weakPointsCard
            }
            .padding(DBSpacing.screenInset)
        }
        .sheet(item: nodeSheetBinding) { node in
            NodeDetailSheet(node: node) { route in
                selectedNodeID = nil
                route()
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// 把 selectedNodeID 包成 Identifiable 节点，驱动详情 sheet。
    private var nodeSheetBinding: Binding<KnowledgeGraphNode?> {
        Binding(
            get: { selectedNode },
            set: { selectedNodeID = $0?.id }
        )
    }

    // MARK: Subject filter

    private var subjectFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DBSpacing.sm) {
                Button { withAnimation(.snappy) { subjectFilter = nil; selectedNodeID = nil } } label: {
                    DBChip("全部学科", systemImage: "square.grid.2x2.fill",
                           tint: .dbSecondary, isSelected: subjectFilter == nil)
                }
                .buttonStyle(.plain)
                ForEach(subjectsPresent) { subject in
                    Button {
                        withAnimation(.snappy) {
                            subjectFilter = (subjectFilter == subject ? nil : subject)
                            selectedNodeID = nil
                        }
                    } label: {
                        DBSubjectChip(subject, isSelected: subjectFilter == subject)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: Summary stats

    private var summaryStats: some View {
        let total = nodes.count
        let mastered = nodes.filter { $0.mastery == .mastered }.count
        let weak = nodes.filter { $0.mastery == .new || $0.mastery == .weak }.count
        return HStack(spacing: DBSpacing.md) {
            DBValueStat(value: "\(total)", caption: "知识点",
                        systemImage: "circle.hexagongrid.fill", tint: .dbPrimary)
            DBValueStat(value: "\(mastered)", caption: "已掌握",
                        systemImage: "checkmark.seal.fill", tint: .dbSuccess)
            DBValueStat(value: "\(weak)", caption: "待攻克",
                        systemImage: "exclamationmark.triangle.fill", tint: .dbError)
        }
    }

    // MARK: Concept map

    private var graphCard: some View {
        DBCard(fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader(
                    "概念地图",
                    subtitle: "双指缩放、拖拽平移，点节点看详情",
                    systemImage: "point.3.filled.connected.trianglepath.dotted")

                if nodes.isEmpty {
                    DBStateView(kind: .empty, title: "这个学科还没有知识点",
                                message: "换个学科看看，或先去做几道题吧～")
                        .frame(height: 220)
                } else {
                    KnowledgeConceptMap(
                        nodes: nodes, links: links,
                        selectedNodeID: $selectedNodeID)
                        .frame(height: isRegular ? 420 : 320)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: DBRadius.md, style: .continuous))
                    masteryLegend
                }
            }
        }
    }

    private var masteryLegend: some View {
        DBFlowLayout(spacing: DBSpacing.sm) {
            ForEach(MasteryState.allCases, id: \.self) { state in
                HStack(spacing: 6) {
                    Circle()
                        .fill(KnowledgeMasteryStyle.color(for: state))
                        .frame(width: 10, height: 10)
                    Text(state.displayName)
                        .font(.dbCaption)
                        .foregroundStyle(Color.dbTextSecondary)
                }
            }
        }
    }

    // MARK: Heatmap (Swift Charts)

    private var heatmapCard: some View {
        DBCard(fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader(
                    "掌握度热力图",
                    subtitle: "每个学科在各掌握档位的知识点数量",
                    systemImage: "square.grid.3x3.fill")
                MasteryHeatmapChart(cells: KnowledgeHeatmapBuilder.cells(for: nodes))
            }
        }
    }

    // MARK: Weak points

    private var weakPointsCard: some View {
        let summaries = KnowledgeHeatmapBuilder.summaries(for: nodes)
        return DBCard(fill: .dbSurface, elevation: .low) {
            VStack(alignment: .leading, spacing: DBSpacing.md) {
                DBSectionHeader(
                    "薄弱学科排行",
                    subtitle: "平均掌握度从低到高，优先攻克最前面的",
                    systemImage: "chart.bar.xaxis.ascending")
                ForEach(summaries) { summary in
                    weakRow(summary)
                }
            }
        }
    }

    private func weakRow(_ summary: SubjectMasterySummary) -> some View {
        HStack(spacing: DBSpacing.md) {
            DBProgressRing(
                progress: summary.averageProgress, lineWidth: 6,
                tint: DBSubjectColor.color(for: summary.subject),
                label: "\(Int((summary.averageProgress * 100).rounded()))")
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.subject.displayName)
                    .font(.dbBodyEmph)
                    .foregroundStyle(Color.dbTextPrimary)
                Text("共 \(summary.total) 个知识点 · \(summary.weakCount) 个待攻克")
                    .font(.dbFootnote)
                    .foregroundStyle(Color.dbTextSecondary)
            }
            Spacer(minLength: 0)
            if summary.weakCount > 0 {
                DBTag("待攻克 \(summary.weakCount)", tint: .dbError)
            } else {
                DBTag("已稳固", tint: .dbSuccess)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Concept map (Canvas + pan/zoom)

/// 已解析颜色的渲染连线（坐标为单位空间 0…1）。
private struct RenderEdge {
    let from: CGPoint
    let to: CGPoint
    let isParent: Bool
    let color: Color
}

/// 已解析颜色的渲染节点。
private struct RenderNode {
    let position: CGPoint
    let radius: CGFloat
    let name: String
    let isSelected: Bool
    let fill: Color
    let stroke: Color
}

/// 用 Canvas 渲染的 node-link 思维导图，支持双指缩放与拖拽平移、点击命中节点。
private struct KnowledgeConceptMap: View {
    let nodes: [KnowledgeGraphNode]
    let links: [KnowledgeGraphLink]
    @Binding var selectedNodeID: String?

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private static let minScale: CGFloat = 0.6
    private static let maxScale: CGFloat = 3.0

    var body: some View {
        GeometryReader { geo in
            let positioned = KnowledgeGraphBuilder.layout(nodes: nodes, canvasSize: geo.size)
            let positionByID = Dictionary(uniqueKeysWithValues: positioned.map { ($0.id, $0) })

            ZStack {
                LinearGradient(
                    colors: [Color.dbBackgroundAlt, Color.dbSurfaceRaised],
                    startPoint: .topLeading, endPoint: .bottomTrailing)

                canvas(size: geo.size, positioned: positioned, positionByID: positionByID)
                    .scaleEffect(scale)
                    .offset(offset)
                    .contentShape(Rectangle())
                    .gesture(tapGesture(in: geo.size, positioned: positioned))
            }
            .gesture(magnifyGesture)
            .simultaneousGesture(dragGesture)
            .overlay(alignment: .bottomTrailing) { zoomControls }
            .accessibilityLabel("知识点概念地图，共 \(nodes.count) 个节点")
        }
    }

    private func canvas(
        size: CGSize,
        positioned: [PositionedNode],
        positionByID: [String: PositionedNode]
    ) -> some View {
        // 把设计系统颜色（@MainActor）在进入 Canvas 闭包前全部解析成纯 Color 值，
        // 这样渲染闭包内只做几何绘制，不再触碰 MainActor 助手。
        let edges: [RenderEdge] = links.compactMap { link in
            guard let a = positionByID[link.from], let b = positionByID[link.to] else { return nil }
            return RenderEdge(
                from: a.position, to: b.position,
                isParent: link.kind == .parent,
                color: Color.dbSeparator.opacity(link.kind == .parent ? 0.9 : 0.6))
        }
        let renderNodes: [RenderNode] = positioned.map { pn in
            let mastery = pn.node.mastery
            return RenderNode(
                position: pn.position, radius: pn.radius, name: pn.node.name,
                isSelected: pn.id == selectedNodeID,
                fill: KnowledgeMasteryStyle.softColor(for: mastery),
                stroke: KnowledgeMasteryStyle.color(for: mastery))
        }
        let labelColor = Color.dbTextPrimary

        return Canvas { context, canvasSize in
            // 1) 连线（父子实线、相关虚线）。
            for edge in edges {
                let p1 = point(edge.from, in: canvasSize)
                let p2 = point(edge.to, in: canvasSize)
                var path = Path()
                path.move(to: p1)
                path.addLine(to: p2)
                let style: StrokeStyle = edge.isParent
                    ? StrokeStyle(lineWidth: 1.6)
                    : StrokeStyle(lineWidth: 1.2, dash: [4, 4])
                context.stroke(path, with: .color(edge.color), style: style)
            }

            // 2) 节点（圆 + 掌握度配色 + 选中描边 + 标题）。
            for rn in renderNodes {
                let center = point(rn.position, in: canvasSize)
                let r = rn.radius
                let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)

                context.fill(Circle().path(in: rect), with: .color(rn.fill))
                context.stroke(
                    Circle().path(in: rect),
                    with: .color(rn.stroke),
                    lineWidth: rn.isSelected ? 3.5 : 2)

                if rn.isSelected {
                    let halo = rect.insetBy(dx: -5, dy: -5)
                    context.stroke(
                        Circle().path(in: halo),
                        with: .color(rn.stroke.opacity(0.4)),
                        lineWidth: 2)
                }

                let text = Text(rn.name)
                    .font(.dbCaption2)
                    .foregroundStyle(labelColor)
                context.draw(text, at: CGPoint(x: center.x, y: center.y + r + 9))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    // 命中测试：tap 直接附着在 canvas 上，location 已是画布本地坐标
    // （scaleEffect/offset 之前的空间），无需反变换。
    private func tapGesture(in size: CGSize, positioned: [PositionedNode]) -> some Gesture {
        SpatialTapGesture()
            .onEnded { value in
                let local = value.location
                var hit: String?
                var best = CGFloat.greatestFiniteMagnitude
                for pn in positioned {
                    let c = point(pn.position, in: size)
                    let d = hypot(local.x - c.x, local.y - c.y)
                    if d <= pn.radius + 6, d < best {
                        best = d
                        hit = pn.id
                    }
                }
                if let hit {
                    HapticEngine.play(.selection)
                    withAnimation(.snappy) { selectedNodeID = hit }
                }
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = clampScale(lastScale * value.magnification)
            }
            .onEnded { _ in lastScale = scale }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private var zoomControls: some View {
        VStack(spacing: DBSpacing.xs) {
            zoomButton(systemImage: "plus.magnifyingglass") {
                scale = clampScale(scale + 0.3); lastScale = scale
            }
            zoomButton(systemImage: "minus.magnifyingglass") {
                scale = clampScale(scale - 0.3); lastScale = scale
            }
            zoomButton(systemImage: "arrow.counterclockwise") {
                scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
            }
        }
        .padding(DBSpacing.sm)
    }

    private func zoomButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.dbCallout)
                .foregroundStyle(Color.dbPrimary)
                .frame(width: 34, height: 34)
                .background(.thinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Coordinate helpers

    private func point(_ unit: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: unit.x * size.width, y: unit.y * size.height)
    }

    private func clampScale(_ value: CGFloat) -> CGFloat {
        min(max(value, Self.minScale), Self.maxScale)
    }
}

// MARK: - Mastery heatmap chart (Swift Charts)

/// 学科 × 掌握档位 的热力网格：颜色深浅按计数渐变，0 计数留白。
private struct MasteryHeatmapChart: View {
    let cells: [MasteryHeatCell]

    private var maxCount: Int { max(cells.map(\.count).max() ?? 0, 1) }

    private var subjects: [Subject] {
        var seen = Set<Subject>()
        var ordered: [Subject] = []
        for c in cells where seen.insert(c.subject).inserted { ordered.append(c.subject) }
        return ordered
    }

    /// 单元格底色：按该掌握档位的语义色，亮度随计数（相对最大值）加深；
    /// 0 计数留一抹极浅底色保持网格可读。
    private func fill(for cell: MasteryHeatCell) -> Color {
        let base = KnowledgeMasteryStyle.color(for: cell.state)
        guard cell.count > 0 else { return Color.dbSeparator.opacity(0.12) }
        let intensity = Double(cell.count) / Double(maxCount)   // 0…1
        return base.opacity(0.25 + intensity * 0.6)
    }

    var body: some View {
        if cells.isEmpty {
            DBStateView(kind: .empty, title: "暂无掌握数据",
                        message: "做几道题，这里就会亮起来～")
                .frame(height: 160)
        } else {
            Chart(cells) { cell in
                RectangleMark(
                    x: .value("掌握档位", cell.state.displayName),
                    y: .value("学科", cell.subject.displayName))
                .foregroundStyle(fill(for: cell))
                .annotation(position: .overlay) {
                    if cell.count > 0 {
                        Text("\(cell.count)")
                            .font(.dbCaption2)
                            .foregroundStyle(Color.dbTextPrimary)
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: MasteryState.allCases.map(\.displayName)) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.dbCaption)
                                .foregroundStyle(Color.dbTextSecondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: subjects.map(\.displayName)) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.dbCaption)
                                .foregroundStyle(Color.dbTextSecondary)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
            .frame(height: CGFloat(subjects.count) * 44 + 24)
            .accessibilityLabel("掌握度热力图，按学科与掌握档位统计知识点数量")
        }
    }
}

// MARK: - Node detail sheet

/// 节点详情面板：知识点信息 + 掌握度，提供「讲一讲」「去练习」两个动作。
private struct NodeDetailSheet: View {
    let node: KnowledgeGraphNode
    /// 调用方先关闭 sheet，再执行传入的导航闭包。
    let perform: (@escaping () -> Void) -> Void

    @Environment(AppRouter.self) private var router
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isRegular: Bool { sizeClass != .compact }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DBSpacing.lg) {
                header
                masteryPanel
                if !node.summary.isEmpty {
                    summarySection
                }
                actions
            }
            .padding(DBSpacing.screenInset)
        }
        .background(Color.dbBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            HStack(spacing: DBSpacing.sm) {
                Image(systemName: KnowledgeMasteryStyle.symbol(for: node.mastery))
                    .font(.dbTitle2)
                    .foregroundStyle(KnowledgeMasteryStyle.color(for: node.mastery))
                Text(node.name)
                    .font(.dbTitle2)
                    .foregroundStyle(Color.dbTextPrimary)
            }
            HStack(spacing: DBSpacing.sm) {
                DBSubjectChip(node.subject)
                DBTag(node.grade.displayName, tint: .dbSecondary)
                if !node.chapter.isEmpty {
                    DBTag(node.chapter, tint: .dbInfo)
                }
            }
        }
    }

    private var masteryPanel: some View {
        DBCard(fill: .dbSurface, elevation: .low) {
            HStack(spacing: DBSpacing.lg) {
                DBProgressRing(
                    progress: node.progress, lineWidth: 8,
                    tint: KnowledgeMasteryStyle.color(for: node.mastery),
                    label: "\(Int((node.progress * 100).rounded()))%")
                    .frame(width: 72, height: 72)
                VStack(alignment: .leading, spacing: DBSpacing.xs) {
                    Text(node.mastery.displayName)
                        .font(.dbHeadline)
                        .foregroundStyle(KnowledgeMasteryStyle.color(for: node.mastery))
                    if node.hasRecord {
                        Text("已练习 \(node.attempts) 次 · 正确 \(node.correctCount) 次")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                        if let accuracy = node.accuracy {
                            Text("正确率 \(Int((accuracy * 100).rounded()))%")
                                .font(.dbFootnote)
                                .foregroundStyle(Color.dbTextSecondary)
                        }
                    } else {
                        Text("还没有练习记录，去试试这个知识点吧～")
                            .font(.dbFootnote)
                            .foregroundStyle(Color.dbTextSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: DBSpacing.sm) {
            DBSectionHeader("知识点简介", systemImage: "text.alignleft")
            Text(node.summary)
                .font(.dbBody)
                .foregroundStyle(Color.dbTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(spacing: DBSpacing.sm) {
            Button {
                let id = node.id
                let regular = isRegular
                perform { router.navigate(.knowledgePoint(id), regular: regular) }
            } label: {
                Label("讲一讲", systemImage: "sparkles")
            }
            .buttonStyle(.db(.primary, fullWidth: true))

            Button {
                let regular = isRegular
                perform { router.openTool(.drill, regular: regular) }
            } label: {
                Label("去练习", systemImage: "pencil.and.outline")
            }
            .buttonStyle(.db(.secondary, fullWidth: true))
        }
    }
}

// MARK: - Previews

#Preview("知识图谱") {
    NavigationStack { KnowledgeGraphView() }
        .modelContainer(PreviewSampleData.container)
        .environment(AppRouter())
}

#Preview("空状态") {
    NavigationStack { KnowledgeGraphView() }
        .modelContainer(for: [KnowledgePointEntity.self, MasteryRecord.self], inMemory: true)
        .environment(AppRouter())
}
