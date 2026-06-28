//
//  LatestVersionView.swift
//  prompthub
//
//  Created by leetao on 2025/3/16.
//

import AlertToast
import MarkdownUI
import SwiftData
import SwiftUI

struct LatestVersionView: View {
    let latestHistory: PromptHistory
    let prompt: Prompt
    @Binding var editablePrompt: String
    @Binding var isEditing: Bool
    @Binding var isGenerating: Bool
    @Binding var isPreviewingOldVersion: Bool
    @Binding var isShowingDiff: Bool
    @Binding var isShowingSingleTestView: Bool
    @Binding var optimizeRequestID: Int
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) var openURL
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastType: AlertToast.AlertType = .regular
    @Environment(ServicesManager.self) private var servicesManager

    @State private var originalText = ""
    @State private var modifiedText = ""
    @State private var diffResults: [DiffResult] = []

    let copyPromptToClipboard: (_ prompt: String) -> Bool
    let copySharedLinkToClipboard: (_ url: URL) -> Bool
    let modifyPromptWithOpenAIStream: () async -> Void
    let onShare: () async -> Void
    
    private let borderColor = Color(NSColor.separatorColor)

    private var promptVariables: [String] {
        let pattern = #"\{\{[^{}]+\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let text = editablePrompt as NSString
        let matches = regex.matches(in: editablePrompt, range: NSRange(location: 0, length: text.length))
        var seen = Set<String>()
        var ordered: [String] = []
        for match in matches {
            let variable = text.substring(with: match.range)
            if seen.insert(variable).inserted {
                ordered.append(variable)
            }
        }
        return ordered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isShowingDiff {
                AIOptimizeDiffPanel(
                    diffResults: diffResults,
                    originalText: originalText,
                    modifiedText: modifiedText,
                    onKeep: keepChanges,
                    onDiscard: undoChanges
                )
                .padding(16)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    if !promptVariables.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Variables")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(promptVariables, id: \.self) { variable in
                                        Text(variable)
                                            .font(.system(.caption, design: .monospaced))
                                            .foregroundStyle(.accent)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.accentColor.opacity(0.08))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if isEditing {
                                NoScrollBarTextEditor(text: $editablePrompt, font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), autoScroll: isGenerating)
                                    .onChange(of: editablePrompt) { _, newValue in
                                        if !isPreviewingOldVersion && !isShowingDiff {
                                            latestHistory.promptText = newValue
                                            latestHistory.updatedAt = Date()
                                            try? modelContext.save()
                                            PromptHubBridge.shared.exportPrompt(prompt)
                                        }
                                    }
                            } else {
                                ScrollView {
                                    if editablePrompt.isEmpty {
                                        Text("No prompt content.")
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        Markdown(editablePrompt)
                                            .markdownSoftBreakMode(.lineBreak)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                        }
                        .frame(minHeight: 300, maxHeight: .infinity, alignment: .topLeading)
                        .padding(10)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColor, lineWidth: 1)
                                .opacity(0.1)
                        )

                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(8)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                                .cornerRadius(8)
                                .padding(12)
                        }
                    }
                }
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(12)
                .padding(16)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
        }
        .sheet(isPresented: $isShowingSingleTestView) {
            SinglePromptTestView(prompt: editablePrompt)
        }
        .onChange(of: optimizeRequestID) {
            Task { await modifyPromptWithOpenAIStreamAndShowDiff() }
        }
    }

    private func modifyPromptWithOpenAIStreamAndShowDiff() async {
        originalText = editablePrompt

        await modifyPromptWithOpenAIStream()

        modifiedText = editablePrompt

        generateDiff()

        guard originalText != modifiedText, !diffResults.isEmpty else {
            showToastMsg(msg: "No changes suggested", alertType: .complete(Color.orange))
            return
        }

        isShowingDiff = true
    }

    private func generateDiff() {
        let oldLines = originalText.components(separatedBy: .newlines)
        let newLines = modifiedText.components(separatedBy: .newlines)
        diffResults = createDiffWithDifferenceKit(old: oldLines, new: newLines)
    }

    private func keepChanges() {
        let version = (prompt.history?.map { $0.version }.max() ?? 0) + 1
        let newHistory = prompt.createHistory(prompt: modifiedText, version: version)

        newHistory.createdAt = Date()
        newHistory.updatedAt = Date()
        newHistory.version = version

        modelContext.insert(newHistory)

        editablePrompt = modifiedText

        do {
            try modelContext.save()
            showToastMsg(msg: "Changes Saved", alertType: .complete(Color.green))
        } catch {
            showToastMsg(msg: "Error saving changes: \(error)")
        }

        resetDiffState()
    }

    private func undoChanges() {
        editablePrompt = originalText

        showToastMsg(msg: "Changes Undone", alertType: .complete(Color.orange))
        resetDiffState()
    }

    private func resetDiffState() {
        isShowingDiff = false
        originalText = ""
        modifiedText = ""
        diffResults = []
    }

    @MainActor
    private func showToastMsg(msg: String, alertType: AlertToast.AlertType = .error(Color.red)) {
        print(msg)
        showToast.toggle()
        toastTitle = msg
        toastType = alertType
    }
}

#Preview {
    @Previewable @State var editablePrompt = "Sample editable prompt content"
    @Previewable @State var isEditing = false
    @Previewable @State var isGenerating = false
    @Previewable @State var isPreviewingOldVersion = false
    @Previewable @State var isShowingDiff = false
    @Previewable @State var isShowingSingleTestView = false
    @Previewable @State var optimizeRequestID = 0

    LatestVersionView(
        latestHistory: PreviewData.samplePromptHistory.first!,
        prompt: PreviewData.samplePrompt,
        editablePrompt: $editablePrompt,
        isEditing: $isEditing,
        isGenerating: $isGenerating,
        isPreviewingOldVersion: $isPreviewingOldVersion,
        isShowingDiff: $isShowingDiff,
        isShowingSingleTestView: $isShowingSingleTestView,
        optimizeRequestID: $optimizeRequestID,
        copyPromptToClipboard: { prompt in
            print("Copied: \(prompt)")
            return true
        },
        copySharedLinkToClipboard: { url in
            print("Copied link: \(url)")
            return true
        },
        modifyPromptWithOpenAIStream: {
            print("OpenAI modify requested")
        },
        onShare: {
            print("Share requested")
        }
    )
    .modelContainer(PreviewData.previewContainer)
    .environmentObject(AppSettings())
    .padding()
}
