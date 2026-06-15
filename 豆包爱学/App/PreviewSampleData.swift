//
//  PreviewSampleData.swift
//  豆包爱学
//
//  Shared in-memory, seeded SwiftData container for SwiftUI previews.
//  Usage: `.modelContainer(PreviewSampleData.container)`.
//

import SwiftData

@MainActor
enum PreviewSampleData {
    /// A fresh in-memory container seeded with the full sample dataset.
    static var container: ModelContainer {
        let container = ModelContainerFactory.make(inMemory: true)
        SampleData.seedIfNeeded(container.mainContext)
        return container
    }
}
