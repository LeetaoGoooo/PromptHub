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
    @Binding var promptId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query var history: [PromptHistory]
    @State private var editablePrompt: String = ""
    @State private var isCopySuccess: Bool = false
    @State private var showOlderVersions: Bool = false
    @State private var selectedHistoryVersion: PromptHistory?
    @State private var isPreviewingOldVersion: Bool = false
    @EnvironmentObject var settings: AppSettings
    @State private var isGenerating = false

    // Colors based on Apple design
    private let cardBackground = Color(NSColor.controlBackgroundColor)
    private let borderColor = Color(NSColor.separatorColor)

    init(promptId: Binding<UUID>) {
        _promptId = promptId
        let currentPromptId = promptId.wrappedValue

        _history = Query(filter: #Predicate<PromptHistory> { history in
            history.promptId == currentPromptId
        }, sort: [SortDescriptor(\.version, order: .reverse)])
    }

    private func copyPromptToClipboard(_ prompt: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        withAnimation {
            isCopySuccess = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isCopySuccess = false
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let latestHistory = history.first {
                    LatestVersionView(
                        latestHistory: latestHistory,
                        editablePrompt: $editablePrompt,
                        isCopySuccess: $isCopySuccess,
                        isGenerating: $isGenerating,
                        isPreviewingOldVersion: $isPreviewingOldVersion,
                        copyPromptToClipboard: copyPromptToClipboard,
                        modifyPromptWithOpenAIStream: modifyPromptWithOpenAIStream
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
                editablePrompt = latest.prompt
            }
        }
        .onChange(of: history) { newHistory in
            if let latest = newHistory.first, !isPreviewingOldVersion {
                editablePrompt = latest.prompt
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
                Text(version.prompt)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }

            HStack {
                Spacer()

                Button {
                    copyPromptToClipboard(version.prompt)
                } label: {
                    Label("Copy Content", systemImage: "doc.on.doc")
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    isPreviewingOldVersion = true
                    editablePrompt = version.prompt
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
        let userPrompt = latestHistory.prompt
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
            "model": "gpt-3.5-turbo", // Or another suitable model
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

            let newHistory = PromptHistory(promptId: promptId, prompt: "")
            let version = (history.first?.version ?? 0) + 1
            
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
                newHistory.prompt = accumulatedResponse
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
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: PromptHistory.self, configurations: config)

    // Create a sample prompt ID
    let promptId = UUID()

    // Create sample history entries
    let sampleHistory1 = PromptHistory(
        promptId: promptId,
        prompt: "This is the latest version of the prompt with some edits and improvements.",
        version: 1
    )

    let sampleHistory2 = PromptHistory(
        promptId: promptId,
        prompt: "This is the original version of the prompt.",
        createdAt: Date().addingTimeInterval(-86400), // 1 day ago
        updatedAt: Date().addingTimeInterval(-86400),
        version: 1
    )

    // Add the sample data to the container
    let context = ModelContext(container)
    context.insert(sampleHistory1)
    context.insert(sampleHistory2)

    // Return the view with the sample data
    return PromptDetail(promptId: .constant(promptId))
        .environment(\.modelContext, context)
}
