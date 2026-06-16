//
//  EssayRadarChart.swift
//  豆包爱学 — Features/Practice/Essay
//
//  Per-dimension 雷达图 (radar / spider chart) for 作文批改 rubric scores.
//
//  Swift Charts ships great Cartesian marks but no first-class polygonal radar
//  mark for an arbitrary set of categories, so we draw the radar with a `Canvas`
//  (matching the house pattern in KnowledgeGraphView): all design-system colors
//  are resolved to plain `Color` values *before* entering the render closure so
//  the closure stays free of MainActor helpers.
//
//  Accessibility: the canvas exposes one combined a11y label plus a hidden, fully
//  labelled list of每个维度的得分 so VoiceOver users get the same information the
//  sighted chart conveys. Reduced-motion is honoured — the reveal animation is
//  skipped when the user asked for less motion.
//

import SwiftUI

/// A radar/spider chart of rubric dimensions. Each spoke is one `RubricDimension`;
/// the filled polygon shows the normalised score (score / maxScore) per spoke.
struct EssayRadarChart: View {
    let dimensions: [RubricDimension]
    /// Polygon fill / stroke tint (caller passes a resolved semantic color).
    var tint: Color = .dbPrimary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: CGFloat = 0

    /// Radar needs at least three spokes to read as a polygon; the caller falls
    /// back to a bar layout below this threshold.
    static func canRender(_ dimensions: [RubricDimension]) -> Bool {
        dimensions.count >= 3
    }

    var body: some View {
        let spokes = makeSpokes()
        let gridColor = Color.dbSeparator
        let axisLabelColor = Color.dbTextSecondary
        let valueLabelColor = Color.dbTextTertiary
        let fillTint = tint

        Canvas { context, size in
            guard spokes.count >= 3 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            // Leave room for the outer labels so they never clip.
            let radius = min(size.width, size.height) / 2 - 34
            guard radius > 0 else { return }

            drawGrid(context: context, center: center, radius: radius,
                     spokeCount: spokes.count, color: gridColor)
            drawSpokes(context: context, center: center, radius: radius,
                       spokes: spokes, color: gridColor)
            drawValuePolygon(context: context, center: center, radius: radius,
                             spokes: spokes, tint: fillTint, reveal: reveal)
            drawLabels(context: context, center: center, radius: radius,
                       spokes: spokes,
                       nameColor: axisLabelColor, valueColor: valueLabelColor)
        }
        .frame(height: 260)
        .padding(.vertical, DBSpacing.xs)
        .onAppear {
            if reduceMotion {
                reveal = 1
            } else {
                withAnimation(.easeOut(duration: 0.55)) { reveal = 1 }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
        // A hidden, per-dimension读出 so VoiceOver users hear每一项的具体得分。
        .background(
            VStack(alignment: .leading, spacing: 0) {
                ForEach(dimensions) { dim in
                    Text("\(dim.name)：\(Int(dim.score.rounded())) 分，满分 \(Int(dim.maxScore.rounded())) 分")
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(detailedReadout)
            .frame(width: 0, height: 0)
            .hidden()
        )
    }

    // MARK: - Geometry

    /// One spoke of the radar: its angle, normalised value, and labels.
    private struct Spoke {
        let angle: Double      // radians, 0 = up
        let fraction: Double   // 0…1 normalised score
        let name: String
        let scoreText: String
    }

    private func makeSpokes() -> [Spoke] {
        let count = dimensions.count
        guard count > 0 else { return [] }
        let step = (2 * Double.pi) / Double(count)
        return dimensions.enumerated().map { index, dim in
            let fraction = dim.maxScore > 0
                ? min(max(dim.score / dim.maxScore, 0), 1)
                : 0
            // Start at the top (-90°) and go clockwise.
            let angle = -Double.pi / 2 + step * Double(index)
            return Spoke(
                angle: angle,
                fraction: fraction,
                name: dim.name,
                scoreText: "\(Int(dim.score.rounded()))/\(Int(dim.maxScore.rounded()))"
            )
        }
    }

    private func vertex(center: CGPoint, radius: CGFloat, angle: Double, fraction: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * radius * fraction,
            y: center.y + sin(angle) * radius * fraction
        )
    }

    // MARK: - Drawing

    private func drawGrid(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                          spokeCount: Int, color: Color) {
        // Concentric rings at 25 / 50 / 75 / 100% so scores are easy to read off.
        let rings: [CGFloat] = [0.25, 0.5, 0.75, 1.0]
        let step = (2 * Double.pi) / Double(spokeCount)
        for ring in rings {
            var path = Path()
            for i in 0..<spokeCount {
                let angle = -Double.pi / 2 + step * Double(i)
                let p = CGPoint(
                    x: center.x + cos(angle) * radius * ring,
                    y: center.y + sin(angle) * radius * ring
                )
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
            context.stroke(path, with: .color(color.opacity(ring == 1.0 ? 0.7 : 0.35)), lineWidth: ring == 1.0 ? 1.2 : 0.8)
        }
    }

    private func drawSpokes(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                            spokes: [Spoke], color: Color) {
        for spoke in spokes {
            var path = Path()
            path.move(to: center)
            path.addLine(to: vertex(center: center, radius: radius, angle: spoke.angle, fraction: 1))
            context.stroke(path, with: .color(color.opacity(0.4)), lineWidth: 0.8)
        }
    }

    private func drawValuePolygon(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                                  spokes: [Spoke], tint: Color, reveal: CGFloat) {
        guard !spokes.isEmpty else { return }
        var path = Path()
        for (index, spoke) in spokes.enumerated() {
            let p = vertex(center: center, radius: radius, angle: spoke.angle,
                           fraction: CGFloat(spoke.fraction) * reveal)
            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()

        context.fill(path, with: .color(tint.opacity(0.22)))
        context.stroke(path, with: .color(tint), lineWidth: 2)

        // Dots at each measured vertex for legibility.
        for spoke in spokes {
            let p = vertex(center: center, radius: radius, angle: spoke.angle,
                           fraction: CGFloat(spoke.fraction) * reveal)
            let dot = CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)
            context.fill(Circle().path(in: dot), with: .color(tint))
        }
    }

    private func drawLabels(context: GraphicsContext, center: CGPoint, radius: CGFloat,
                            spokes: [Spoke], nameColor: Color, valueColor: Color) {
        for spoke in spokes {
            let anchor = vertex(center: center, radius: radius + 20, angle: spoke.angle, fraction: 1)
            let name = Text(spoke.name)
                .font(.dbCaption.weight(.medium))
                .foregroundStyle(nameColor)
            let value = Text(spoke.scoreText)
                .font(.dbCaption2.monospacedDigit())
                .foregroundStyle(valueColor)
            context.draw(name, at: CGPoint(x: anchor.x, y: anchor.y - 6))
            context.draw(value, at: CGPoint(x: anchor.x, y: anchor.y + 8))
        }
    }

    // MARK: - Accessibility text

    private var accessibilitySummary: String {
        "各维度雷达图，共 \(dimensions.count) 个维度。\(detailedReadout)"
    }

    private var detailedReadout: String {
        dimensions
            .map { "\($0.name) \(Int($0.score.rounded())) 分（满分 \(Int($0.maxScore.rounded())) 分）" }
            .joined(separator: "，")
    }
}

// MARK: - Preview

#Preview("雷达图") {
    EssayRadarChart(
        dimensions: [
            RubricDimension(name: "立意", score: 18, maxScore: 20, comment: ""),
            RubricDimension(name: "结构", score: 16, maxScore: 20, comment: ""),
            RubricDimension(name: "语言", score: 15, maxScore: 20, comment: ""),
            RubricDimension(name: "书写", score: 19, maxScore: 20, comment: ""),
            RubricDimension(name: "亮点", score: 13, maxScore: 20, comment: "")
        ],
        tint: .dbPrimary
    )
    .padding(DBSpacing.lg)
    .background(Color.dbBackground)
}
