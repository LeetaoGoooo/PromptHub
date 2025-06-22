//
//  PreviewData.swift
//  prompthub
//
//  Created by leetao on 2025/6/20.
//

import Foundation
import SwiftData

/// Helper class to provide mock data for SwiftUI previews
@MainActor
class PreviewData {
    
    static let shared = PreviewData()
    
    // MARK: - Sample Prompt
    static var samplePrompt: Prompt {
        Prompt(
            name: "Sample Prompt",
            desc: "This is a sample prompt for preview purposes",
            link: "https://example.com"
        )
    }
    
    // MARK: - Sample Prompt History Data
    static var samplePromptHistoryData: [(prompt: String, version: Int)] {
        return [
            (
                prompt: "This is the latest version of the prompt. It contains multiple lines and demonstrates how the UI handles longer content.",
                version: 2
            ),
            (
                prompt: "This is an older version of the prompt.",
                version: 1
            )
        ]
    }
    
    // MARK: - Sample Prompt History (for backward compatibility)
    static var samplePromptHistory: [PromptHistory] {
        return samplePromptHistoryData.map { data in
            PromptHistory(
                promptText: data.prompt,
                version: data.version
            )
        }
    }
    
    // MARK: - Sample Gallery Prompt
    static var sampleGalleryPrompt: GalleryPrompt {
        GalleryPrompt(
            id: "sample-1",
            name: "Sample Gallery Prompt",
            description: "This is a sample gallery prompt with a longer description to demonstrate how the UI handles multi-line content.",
            prompt: "This is the content of the gallery prompt that users can copy and use."
        )
    }
    
    @MainActor
    static var previewContainer: ModelContainer {
        do {
            let config = ModelConfiguration(isStoredInMemoryOnly: true)
            
            let container = try ModelContainer(
                for: Schema([
                    Prompt.self,
                    PromptHistory.self,
                    SharedCreation.self,
                ]),
                configurations: config
            )
            
            let context = container.mainContext
            
            let prompt = Prompt(
                name: "Sample Prompt",
                desc: "This is a sample prompt for preview purposes",
                link: "https://example.com"
            )
            context.insert(prompt)
            
            for historyData in samplePromptHistoryData {
                let history = PromptHistory(
                    promptText: historyData.prompt,
                    version: historyData.version
                )
                history.prompt = prompt
                context.insert(history)
                
                prompt.history.append(history)
            }
            
            return container
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
}
