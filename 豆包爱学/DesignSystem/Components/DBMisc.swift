//
//  DBMisc.swift
//  豆包爱学 — Design System
//
//  Smaller shared components: badge, streak, search field, value stat,
//  route badge, and a flow layout for chips.
//

import SwiftUI

// MARK: - Badge (notification dot / count)

public struct DBBadge: View {
    public var count: Int
    public var tint: Color
    public init(count: Int, tint: Color = .dbError) {
        self.count = count
        self.tint = tint
    }
    public var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(tint, in: Capsule())
        }
    }
}

// MARK: - Streak (打卡)

public struct DBStreakView: View {
    public var days: Int
    public init(days: Int) { self.days = days }
    public var body: some View {
        HStack(spacing: DBSpacing.xs) {
            Image(systemName: "flame.fill").foregroundStyle(Color.dbPrimary)
            Text("\(days)").font(.dbBodyEmph.monospacedDigit()).foregroundStyle(Color.dbTextPrimary)
            Text("天连续").font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
        }
        .padding(.horizontal, DBSpacing.md).padding(.vertical, DBSpacing.sm)
        .background(Color.dbPrimarySoft, in: Capsule())
        .accessibilityLabel("连续学习 \(days) 天")
    }
}

// MARK: - Value stat (profile/report metric)

public struct DBValueStat: View {
    public var value: String
    public var caption: String
    public var systemImage: String?
    public var tint: Color
    public init(value: String, caption: String, systemImage: String? = nil, tint: Color = .dbPrimary) {
        self.value = value
        self.caption = caption
        self.systemImage = systemImage
        self.tint = tint
    }
    public var body: some View {
        VStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage).font(.dbCallout).foregroundStyle(tint)
            }
            Text(value).font(.dbTitle2.monospacedDigit()).foregroundStyle(Color.dbTextPrimary)
            Text(caption).font(.dbCaption).foregroundStyle(Color.dbTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Route badge (on-device vs enhanced)

public struct DBRouteBadge: View {
    public var route: IntelligenceRoute
    public init(_ route: IntelligenceRoute) { self.route = route }
    public var body: some View {
        Label(route.badgeLabel, systemImage: route.symbolName)
            .font(.dbCaption2.weight(.semibold))
            .padding(.horizontal, DBSpacing.sm).padding(.vertical, 3)
            .foregroundStyle(Color.dbSecondary)
            .background(Color.dbSecondarySoft, in: Capsule())
            .accessibilityLabel("智能来源 \(route.badgeLabel)")
    }
}

// MARK: - Search field

public struct DBSearchField: View {
    @Binding public var text: String
    public var placeholder: String
    public init(text: Binding<String>, placeholder: String = "搜索题目、错题、单词、课程…") {
        self._text = text
        self.placeholder = placeholder
    }
    public var body: some View {
        HStack(spacing: DBSpacing.sm) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.dbTextTertiary)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.dbBody)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color.dbTextTertiary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, DBSpacing.md).padding(.vertical, DBSpacing.sm + 2)
        .background(Color.dbSurface, in: Capsule())
        .overlay(Capsule().stroke(Color.dbSeparator, lineWidth: 1))
    }
}

// MARK: - Simple wrapping flow layout for chips

public struct DBFlowLayout: Layout {
    public var spacing: CGFloat
    public init(spacing: CGFloat = 8) { self.spacing = spacing }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Misc") {
    VStack(spacing: 16) {
        HStack(spacing: 16) {
            DBStreakView(days: 12)
            DBRouteBadge(.onDevice)
            DBBadge(count: 5)
        }
        DBSearchField(text: .constant(""))
        HStack {
            DBValueStat(value: "128", caption: "已解题", systemImage: "checkmark.seal.fill")
            DBValueStat(value: "86%", caption: "掌握度", systemImage: "chart.pie.fill", tint: .dbSecondary)
        }
    }
    .padding().background(Color.dbBackground)
}
