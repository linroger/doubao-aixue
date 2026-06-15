//
//  HapticEngine.swift
//  豆包爱学
//
//  Cross-platform haptic feedback helper.
//

import SwiftUI

@MainActor
public enum HapticEngine {
    public enum Feedback { case success, warning, error, light, selection }

    public static func play(_ feedback: Feedback) {
        #if canImport(UIKit) && os(iOS)
        switch feedback {
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        }
        #elseif canImport(AppKit)
        let pattern: NSHapticFeedbackManager.FeedbackPattern
        switch feedback {
        case .success, .selection: pattern = .alignment
        case .warning, .error: pattern = .levelChange
        case .light: pattern = .generic
        }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
        #endif
    }
}
