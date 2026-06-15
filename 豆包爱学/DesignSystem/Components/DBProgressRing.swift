//
//  DBProgressRing.swift
//  豆包爱学 — Design System
//

import SwiftUI

public struct DBProgressRing: View {
    public var progress: Double          // 0...1
    public var lineWidth: CGFloat
    public var tint: Color
    public var label: String?

    public init(progress: Double, lineWidth: CGFloat = 10, tint: Color = .dbPrimary, label: String? = nil) {
        self.progress = max(0, min(1, progress))
        self.lineWidth = lineWidth
        self.tint = tint
        self.label = label
    }

    public var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.16), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(duration: 0.5), value: progress)
            if let label {
                Text(label).font(.dbHeadline.monospacedDigit()).foregroundStyle(Color.dbTextPrimary)
            } else {
                Text("\(Int(progress * 100))%").font(.dbHeadline.monospacedDigit()).foregroundStyle(Color.dbTextPrimary)
            }
        }
        .accessibilityLabel("进度 \(Int(progress * 100)) 百分比")
    }
}

#Preview("Ring") {
    HStack(spacing: 24) {
        DBProgressRing(progress: 0.72).frame(width: 90, height: 90)
        DBProgressRing(progress: 0.4, tint: .dbSecondary, label: "4/10").frame(width: 90, height: 90)
    }
    .padding().background(Color.dbBackground)
}
