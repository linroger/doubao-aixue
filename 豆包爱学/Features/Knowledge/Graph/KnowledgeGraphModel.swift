//
//  KnowledgeGraphModel.swift
//  豆包爱学 — Features/Knowledge/Graph
//
//  支撑 知识图谱 (RESEARCH F13 / F39 / F44) 的纯数据与布局类型。
//
//  把 @Query 读到的 KnowledgePointEntity + MasteryRecord 折叠成一组可渲染的
//  节点 (GraphNode) 与连线 (GraphLink)，并为思维导图 (mind-map) 计算一个稳定、
//  确定的力导向式分层布局。所有类型都是纯值类型，标记为 `nonisolated` 以便
//  视图与（潜在的）非隔离上下文共享。返回 Color/Font 的展示助手保持在
//  @MainActor 上（见 KnowledgeMasteryStyle），因为设计系统颜色是 MainActor。
//

import Foundation
import CoreGraphics
import SwiftUI

// MARK: - Graph node (折叠后的知识点 + 掌握度)

/// 一个可渲染的知识点节点：知识点本体 + 它的掌握度快照。
nonisolated struct KnowledgeGraphNode: Identifiable, Hashable, Sendable {
    let id: String                 // = KnowledgePointEntity.id
    let name: String
    let subject: Subject
    let grade: GradeLevel
    let summary: String
    let chapter: String
    let parentIDs: [String]
    let relatedIDs: [String]

    /// 掌握度 0…1（无记录时为 nil → 视为「待学习」）。
    let masteryScore: Double?
    let attempts: Int
    let correctCount: Int
    let lastUpdated: Date?

    /// 派生掌握状态。无记录 → .new。
    var mastery: MasteryState {
        guard let masteryScore else { return .new }
        switch masteryScore {
        case ..<0.2: return .new
        case ..<0.5: return .weak
        case ..<0.85: return .developing
        default: return .mastered
        }
    }

    /// 是否有真实学习记录（用于「数据不足」判断）。
    var hasRecord: Bool { masteryScore != nil && attempts > 0 }

    /// 正确率 0…1（无尝试时为 nil）。
    var accuracy: Double? {
        guard attempts > 0 else { return nil }
        return Double(correctCount) / Double(attempts)
    }

    /// 用于排序/进度展示的 0…1 值。
    var progress: Double { masteryScore ?? mastery.progress }
}

// MARK: - Link between two nodes

nonisolated struct KnowledgeGraphLink: Identifiable, Hashable, Sendable {
    enum Kind: Sendable { case parent, related }
    let from: String
    let to: String
    let kind: Kind
    var id: String { "\(from)->\(to)-\(kind == .parent ? "p" : "r")" }
}

// MARK: - Positioned node (布局后)

/// 思维导图布局结果：节点 + 单位坐标 (0…1) 与可视半径。
nonisolated struct PositionedNode: Identifiable, Sendable {
    let node: KnowledgeGraphNode
    var position: CGPoint          // 单位空间 0…1
    var radius: CGFloat            // 像素半径（按掌握度缩放）
    var id: String { node.id }
}

// MARK: - Graph builder + layout

/// 把实体折叠成图，并生成确定性的分层环形布局。
/// 纯计算，可在视图里直接调用——没有副作用、可重复。
nonisolated enum KnowledgeGraphBuilder {

    /// 折叠：把知识点与掌握度记录配对成节点。
    static func makeNodes(
        points: [KnowledgePointSnapshot],
        masteries: [MasterySnapshot]
    ) -> [KnowledgeGraphNode] {
        let byPoint = Dictionary(masteries.map { ($0.knowledgePointID, $0) }) { a, _ in a }
        return points.map { p in
            let m = byPoint[p.id]
            return KnowledgeGraphNode(
                id: p.id, name: p.name, subject: p.subject, grade: p.grade,
                summary: p.summary, chapter: p.chapter,
                parentIDs: p.parentIDs, relatedIDs: p.relatedIDs,
                masteryScore: m?.score, attempts: m?.attempts ?? 0,
                correctCount: m?.correctCount ?? 0, lastUpdated: m?.lastUpdated
            )
        }
        .sorted { lhs, rhs in
            if lhs.subject != rhs.subject { return lhs.subject.displayName < rhs.subject.displayName }
            return lhs.grade.rawValue < rhs.grade.rawValue
        }
    }

    /// 生成连线：父子 (parentIDs) 与相关 (relatedIDs)，去重、双向 related 只保留一条。
    static func makeLinks(for nodes: [KnowledgeGraphNode]) -> [KnowledgeGraphLink] {
        let ids = Set(nodes.map(\.id))
        var links: [KnowledgeGraphLink] = []
        var seenRelated = Set<String>()
        for node in nodes {
            for parent in node.parentIDs where ids.contains(parent) {
                links.append(KnowledgeGraphLink(from: parent, to: node.id, kind: .parent))
            }
            for related in node.relatedIDs where ids.contains(related) {
                // 规范化无向键，避免 A↔B 出现两条。
                let key = [node.id, related].sorted().joined(separator: "|")
                if seenRelated.insert(key).inserted {
                    links.append(KnowledgeGraphLink(from: node.id, to: related, kind: .related))
                }
            }
        }
        return links
    }

    /// 确定性布局：按学科分簇，每个簇放在一个环上的扇区里，
    /// 簇内按年级/链路深度做半径分层。坐标在单位空间 0…1。
    /// 节点半径按掌握度从 22→34 px 缩放（掌握越好越大），薄弱点更醒目地放在簇外缘。
    static func layout(
        nodes: [KnowledgeGraphNode],
        canvasSize: CGSize
    ) -> [PositionedNode] {
        guard !nodes.isEmpty else { return [] }

        // 按学科分组（保持稳定顺序）。
        let subjects = orderedSubjects(in: nodes)
        let groups = Dictionary(grouping: nodes, by: \.subject)

        let center = CGPoint(x: 0.5, y: 0.5)
        let clusterCount = max(subjects.count, 1)
        // 单个学科时把簇放中央，多个学科时沿大环均匀铺开。
        let clusterRingRadius: CGFloat = clusterCount == 1 ? 0 : 0.30

        let minSide = min(canvasSize.width, canvasSize.height)
        let baseRadius = max(20, minSide * 0.018)

        var result: [PositionedNode] = []

        for (ci, subject) in subjects.enumerated() {
            let members = (groups[subject] ?? []).sorted { lhs, rhs in
                // 簇内：父节点（depth 小）靠中心，薄弱点排前面以便分布到外缘。
                if lhs.grade.rawValue != rhs.grade.rawValue {
                    return lhs.grade.rawValue < rhs.grade.rawValue
                }
                return lhs.id < rhs.id
            }
            let clusterAngle = (2 * Double.pi) * (Double(ci) / Double(clusterCount)) - .pi / 2
            let clusterCenter = CGPoint(
                x: center.x + clusterRingRadius * CGFloat(cos(clusterAngle)),
                y: center.y + clusterRingRadius * CGFloat(sin(clusterAngle))
            )

            // 簇内环形：成员数决定半径，单个成员落在簇心。
            let memberCount = members.count
            let innerRadius: CGFloat = memberCount <= 1 ? 0 : (clusterCount == 1 ? 0.34 : 0.155)

            for (mi, node) in members.enumerated() {
                let memberAngle = memberCount <= 1
                    ? 0
                    : (2 * Double.pi) * (Double(mi) / Double(memberCount)) + Double(ci) * 0.6
                // 已掌握的稍微向内、薄弱的略向外，制造「待攻克在外圈」的视觉。
                let masteryBias: CGFloat = 1.0 + (0.18 - CGFloat(node.progress) * 0.18)
                let r = innerRadius * masteryBias
                let pos = CGPoint(
                    x: clusterCenter.x + r * CGFloat(cos(memberAngle)),
                    y: clusterCenter.y + r * CGFloat(sin(memberAngle))
                )
                // 半径：掌握度越高越大；薄弱/新点保持中等，但用颜色与脉冲突出。
                let radius = baseRadius * (0.85 + CGFloat(node.progress) * 0.55)
                result.append(PositionedNode(
                    node: node,
                    position: clamp(pos),
                    radius: radius
                ))
            }
        }
        return result
    }

    /// 学科在节点集合中的稳定出现顺序。
    static func orderedSubjects(in nodes: [KnowledgeGraphNode]) -> [Subject] {
        var seen = Set<Subject>()
        var ordered: [Subject] = []
        for n in nodes where seen.insert(n.subject).inserted { ordered.append(n.subject) }
        return ordered
    }

    private static func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 0.06), 0.94), y: min(max(p.y, 0.06), 0.94))
    }
}

// MARK: - Plain snapshots (decouple SwiftData models from pure layout code)

/// 从 KnowledgePointEntity 拷出的纯快照（避免在非隔离布局里触碰 @Model）。
nonisolated struct KnowledgePointSnapshot: Sendable {
    let id: String
    let name: String
    let subject: Subject
    let grade: GradeLevel
    let summary: String
    let chapter: String
    let parentIDs: [String]
    let relatedIDs: [String]
}

/// 从 MasteryRecord 拷出的纯快照。
nonisolated struct MasterySnapshot: Sendable {
    let knowledgePointID: String
    let score: Double
    let attempts: Int
    let correctCount: Int
    let lastUpdated: Date
}

extension KnowledgePointSnapshot {
    /// 在 @MainActor 上从 SwiftData 实体安全拷贝（@Model 属性须在主线程读取）。
    @MainActor
    init(_ entity: KnowledgePointEntity) {
        self.init(
            id: entity.id, name: entity.name, subject: entity.subject,
            grade: entity.grade, summary: entity.summary, chapter: entity.chapter,
            parentIDs: entity.parentIDs, relatedIDs: entity.relatedIDs)
    }
}

extension MasterySnapshot {
    @MainActor
    init(_ record: MasteryRecord) {
        self.init(
            knowledgePointID: record.knowledgePointID, score: record.score,
            attempts: record.attempts, correctCount: record.correctCount,
            lastUpdated: record.lastUpdated)
    }
}

// MARK: - Heatmap aggregation

/// 热力图单元格：某学科在某掌握档位下的知识点计数。
nonisolated struct MasteryHeatCell: Identifiable, Sendable {
    let subject: Subject
    let state: MasteryState
    let count: Int
    var id: String { "\(subject.rawValue)-\(state.rawValue)" }
}

/// 学科级掌握度汇总（用于排序与薄弱预警）。
nonisolated struct SubjectMasterySummary: Identifiable, Sendable {
    let subject: Subject
    let averageProgress: Double      // 0…1
    let total: Int
    let weakCount: Int               // .new + .weak
    var id: String { subject.rawValue }
}

nonisolated enum KnowledgeHeatmapBuilder {
    /// 按 学科 × 掌握档位 聚合出热力图单元格（含计数为 0 的格子，保证网格完整）。
    static func cells(for nodes: [KnowledgeGraphNode]) -> [MasteryHeatCell] {
        let subjects = KnowledgeGraphBuilder.orderedSubjects(in: nodes)
        var counts: [String: Int] = [:]
        for n in nodes { counts[n.subject.rawValue + n.mastery.rawValue, default: 0] += 1 }
        var cells: [MasteryHeatCell] = []
        for subject in subjects {
            for state in MasteryState.allCases {
                cells.append(MasteryHeatCell(
                    subject: subject, state: state,
                    count: counts[subject.rawValue + state.rawValue] ?? 0))
            }
        }
        return cells
    }

    /// 每个学科的平均掌握度与薄弱点数（按平均掌握度升序——最弱在前）。
    static func summaries(for nodes: [KnowledgeGraphNode]) -> [SubjectMasterySummary] {
        let groups = Dictionary(grouping: nodes, by: \.subject)
        return KnowledgeGraphBuilder.orderedSubjects(in: nodes).map { subject in
            let members = groups[subject] ?? []
            let avg = members.isEmpty ? 0 : members.reduce(0) { $0 + $1.progress } / Double(members.count)
            let weak = members.filter { $0.mastery == .new || $0.mastery == .weak }.count
            return SubjectMasterySummary(
                subject: subject, averageProgress: avg,
                total: members.count, weakCount: weak)
        }
        .sorted { $0.averageProgress < $1.averageProgress }
    }
}

// MARK: - Mastery presentation (颜色/文案) — @MainActor，因设计系统颜色是 MainActor

/// 把掌握档位映射到展示用的颜色与图标。颜色取自设计系统语义色，自动适配深色模式。
@MainActor
enum KnowledgeMasteryStyle {
    /// 掌握档位对应的语义色：待学习→灰、薄弱→警示、巩固中→主色、已掌握→成功。
    static func color(for state: MasteryState) -> Color {
        switch state {
        case .new:        Color.dbTextTertiary
        case .weak:       Color.dbError
        case .developing: Color.dbPrimary
        case .mastered:   Color.dbSuccess
        }
    }

    /// 用于节点填充的柔和色（节点底色）。
    static func softColor(for state: MasteryState) -> Color {
        switch state {
        case .new:        Color.dbTextTertiary.opacity(0.18)
        case .weak:       Color.dbErrorSoft
        case .developing: Color.dbPrimarySoft
        case .mastered:   Color.dbSuccessSoft
        }
    }

    static func symbol(for state: MasteryState) -> String {
        switch state {
        case .new:        "circle.dashed"
        case .weak:       "exclamationmark.triangle.fill"
        case .developing: "arrow.up.forward.circle.fill"
        case .mastered:   "checkmark.seal.fill"
        }
    }
}
