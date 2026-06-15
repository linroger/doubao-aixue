//
//  DBMascot.swift
//  豆包爱学 — Design System
//
//  The friendly "豆包" study companion, drawn in pure SwiftUI so it scales
//  crisply and needs no asset. Used in onboarding, empty states, and the tutor.
//

import SwiftUI

public enum DBMascotMood {
    case happy, thinking, cheering, sleepy, curious
}

public struct DBMascot: View {
    public var mood: DBMascotMood
    public var size: CGFloat

    public init(mood: DBMascotMood = .happy, size: CGFloat = 96) {
        self.mood = mood
        self.size = size
    }

    public var body: some View {
        ZStack {
            // Soft body — a rounded "bean".
            RoundedRectangle(cornerRadius: size * 0.42, style: .continuous)
                .fill(Color.dbHeroGradient)
                .frame(width: size * 0.86, height: size)
                .rotationEffect(.degrees(-6))
                .dbShadow(.low)

            // Cheeks.
            HStack(spacing: size * 0.30) {
                cheek
                cheek
            }
            .offset(y: size * 0.12)

            // Face.
            VStack(spacing: size * 0.06) {
                HStack(spacing: size * 0.18) {
                    eye
                    eye
                }
                mouth
            }
            .offset(y: -size * 0.02)

            // Little sprout on top.
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.22))
                .foregroundStyle(Color.dbSecondary)
                .offset(y: -size * 0.58)
                .rotationEffect(.degrees(18))
        }
        .frame(width: size, height: size * 1.1)
        .accessibilityHidden(true)
    }

    private var eye: some View {
        Group {
            switch mood {
            case .sleepy:
                Capsule().fill(.white).frame(width: size * 0.14, height: size * 0.04)
            case .cheering, .happy:
                Circle().fill(.white).frame(width: size * 0.16, height: size * 0.16)
                    .overlay(Circle().fill(Color.dbTextPrimary).frame(width: size * 0.08, height: size * 0.08).offset(y: size * 0.02))
            default:
                Circle().fill(.white).frame(width: size * 0.16, height: size * 0.16)
                    .overlay(Circle().fill(Color.dbTextPrimary).frame(width: size * 0.08, height: size * 0.08))
            }
        }
    }

    private var cheek: some View {
        Circle().fill(Color.white.opacity(0.35)).frame(width: size * 0.16, height: size * 0.16)
    }

    private var mouth: some View {
        Group {
            switch mood {
            case .cheering:
                Circle().trim(from: 0.0, to: 0.5).stroke(.white, lineWidth: size * 0.035)
                    .frame(width: size * 0.22, height: size * 0.22).rotationEffect(.degrees(0))
            case .thinking, .curious:
                Capsule().fill(.white).frame(width: size * 0.10, height: size * 0.05)
            default:
                Capsule().fill(.white).frame(width: size * 0.18, height: size * 0.06)
            }
        }
    }
}

#Preview("Mascot moods") {
    HStack(spacing: 20) {
        DBMascot(mood: .happy, size: 80)
        DBMascot(mood: .thinking, size: 80)
        DBMascot(mood: .cheering, size: 80)
        DBMascot(mood: .sleepy, size: 80)
    }
    .padding(40)
    .background(Color.dbBackground)
}
