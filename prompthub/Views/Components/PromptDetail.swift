//
//  PromptDetail.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PromptDetail: View {
    @Bindable var prompt:Prompt
    @Environment(\.modelContext) private var modelContext
    
    @State private var editablePrompt: String = ""
    @State private var showOlderVersions: Bool = false
    @State private var selectedHistoryVersion: PromptHistory?
    @State private var isPreviewingOldVersion: Bool = false
    @EnvironmentObject var settings: AppSettings
    @State private var isGenerating = false

    private let cardBackground = Color(NSColor.controlBackgroundColor)
    private let borderColor = Color(NSColor.separatorColor)

    private var history: [PromptHistory] {
        prompt.history?.sorted { $0.version > $1.version } ?? []
    }

    private func copyPromptToClipboard(_ prompt: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(prompt, forType: .string)
    }
    
    private func copySharedLinkToClipboard(_ url: URL) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(url.absoluteString, forType: .string)
       
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let latestHistory = history.first {
                    LatestVersionView(
                        latestHistory: latestHistory,
                        prompt:prompt,
                        editablePrompt: $editablePrompt,
                        isGenerating: $isGenerating,
                        isPreviewingOldVersion: $isPreviewingOldVersion,
                        copyPromptToClipboard: copyPromptToClipboard,
                        copySharedLinkToClipboard: copySharedLinkToClipboard, modifyPromptWithOpenAIStream: modifyPromptWithOpenAIStream
                    )

                    Spacer()

                    if history.count > 1 {
                        HistorySectionView(
                            history: history,
                            showOlderVersions: $showOlderVersions,
                            selectedHistoryVersion: $selectedHistoryVersion,
                            isPreviewingOldVersion: $isPreviewingOldVersion,
                            editablePrompt: $editablePrompt,
                            copyPromptToClipboard: copyPromptToClipboard,
                            deleteHistoryItem: { historyItemToDelete in
                                modelContext.delete(historyItemToDelete) // Delete the object from the ModelContext
                            }
                        )
                    } else {
                        NoHistoryView()
                    }
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if let latest = history.first {
                editablePrompt = latest.content
            }
        }
        .onChange(of: history) { newHistory in
            if let latest = newHistory.first, !isPreviewingOldVersion {
                editablePrompt = latest.content
            }
        }
        .sheet(item: $selectedHistoryVersion) { version in
            versionDetailSheet(version)
        }
    }

    private var copiedSuccessMessage: some View {
        Label("Copied!", systemImage: "checkmark.circle.fill")
            .padding(8)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(radius: 2)
            .padding(8)
            .transition(.scale.combined(with: .opacity))
    }

    private func versionDetailSheet(_ version: PromptHistory) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Version \(version.version) Details")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Dismiss") {
                    selectedHistoryVersion = nil
                }
                .buttonStyle(PlainButtonStyle())
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Created: \(version.createdAt, formatter: dateFormatter)")
                    .font(.subheadline)
                Text("Updated: \(version.updatedAt, formatter: dateFormatter)")
                    .font(.subheadline)
            }

            Text("Prompt Content")
                .font(.headline)

            ScrollView {
                Text(version.content)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }

            HStack {
                Spacer()

                Button {
                    copyPromptToClipboard(version.content)
                } label: {
                    Label("Copy Content", systemImage: "doc.on.doc")
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    isPreviewingOldVersion = true
                    editablePrompt = version.content
                    selectedHistoryVersion = nil
                } label: {
                    Label("Preview in Editor", systemImage: "eye")
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())

                Spacer()
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }

    @MainActor
    private func modifyPromptWithOpenAIStream() async {
        guard settings.isTestPassed else { return }
        guard !settings.openaiApiKey.isEmpty else {
            print("OpenAI API key is missing.")
            return
        }
        guard let latestHistory = history.first else { return }
        isGenerating = true
        let userPrompt = latestHistory.content
        let systemPrompt = settings.prompt

        let urlString = "\(settings.baseURL)/chat/completions"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            isGenerating = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.openaiApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: [
            "model": settings.model, 
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "stream": true
        ])

        do {
            let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                print("Error: Received status code \(statusCode)")
                return
            }

            let version = (history.first?.version ?? 0) + 1
            let newHistory = prompt.createHistory(prompt: "", version: version)
            
            newHistory.createdAt = Date()
            newHistory.updatedAt = Date()
            newHistory.version = version
            try? modelContext.insert(newHistory);

            var accumulatedResponse = ""
            
            for try await line in asyncBytes.lines {
                if line.hasPrefix("data: ") {
                    let jsonDataString = line.dropFirst(6).trimmingCharacters(in: .whitespacesAndNewlines)
                    if jsonDataString == "[DONE]" {
                        break
                    }
                    if let jsonData = jsonDataString.data(using: .utf8) {
                        do {
                            let completionResponse = try JSONDecoder().decode(OpenAIStreamingChatResponse.self, from: jsonData)
                            if let choice = completionResponse.choices.first, let content = choice.delta?.content {
                                DispatchQueue.main.async {
                                    editablePrompt += content
                                }
                                accumulatedResponse += content
                            }
                        } catch {
                            print("Error decoding JSON data: \(error)")
                            print("Raw JSON: \(jsonDataString)")
                            isGenerating = false
                        }
                    }
                }
            }

            if !accumulatedResponse.isEmpty {
                newHistory.content = accumulatedResponse
                try? modelContext.save()
            }


            isGenerating = false

        } catch {
            print("Error making API request: \(error)")
            isGenerating = false
        }
    }
}

#Preview {
    PromptDetail(prompt: PreviewData.samplePrompt)
        .modelContainer(PreviewData.previewContainer)
        .environmentObject(AppSettings())
}
