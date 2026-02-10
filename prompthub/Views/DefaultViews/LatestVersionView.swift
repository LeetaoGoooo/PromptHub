//
//  LatestVersionView.swift
//  prompthub
//
//  Created by leetao on 2025/3/16.
//

import AlertToast
import SwiftData
import SwiftUI

struct LatestVersionView: View {
    let latestHistory: PromptHistory
    let prompt: Prompt
    @Binding var editablePrompt: String
    @Binding var isGenerating: Bool
    @Binding var isPreviewingOldVersion: Bool
    @Binding var isShowingDiff: Bool
    @Binding var isShowingSingleTestView: Bool
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

    @State private var mainContentHeight: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
                if isShowingDiff {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Review Changes")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Button("Discard") { undoChanges() }
                                .buttonStyle(.plain)
                                .foregroundColor(.red)
                            Button("Keep Changes") { keepChanges() }
                                .buttonStyle(.borderedProminent)
                        }

                        DiffRenderer(diffResults: diffResults)
                    }
                    .padding(16)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .padding(16)
                } else {
                    ZStack(alignment: .bottomTrailing) {
                        NoScrollBarTextEditor(text: $editablePrompt, font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), autoScroll: isGenerating)
                            .frame(minHeight: 300)
                            .padding(10)
                            .background(Color(NSColor.textBackgroundColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(borderColor, lineWidth: 1)
                                    .opacity(0.1)
                            )
                            .onChange(of: editablePrompt) { newValue in
                                if !isPreviewingOldVersion && !isShowingDiff {
                                    latestHistory.promptText = newValue
                                    latestHistory.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            }

                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(8)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                                .cornerRadius(8)
                                .padding([.bottom, .trailing], 40)
                        }

                        Button {
                            Task { await modifyPromptWithOpenAIStreamAndShowDiff() }
                        } label: {
                            Image(systemName: "wand.and.stars")
                        }
                        .padding(8)
                        .disabled(isGenerating)
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
    }

    private func modifyPromptWithOpenAIStreamAndShowDiff() async {
        originalText = editablePrompt

        await modifyPromptWithOpenAIStream()

        modifiedText = editablePrompt

        generateDiff()

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
    @Previewable @State var isGenerating = false
    @Previewable @State var isPreviewingOldVersion = false
    @Previewable @State var isShowingDiff = false
    @Previewable @State var isShowingSingleTestView = false

    LatestVersionView(
        latestHistory: PreviewData.samplePromptHistory.first!,
        prompt: PreviewData.samplePrompt,
        editablePrompt: $editablePrompt,
        isGenerating: $isGenerating,
        isPreviewingOldVersion: $isPreviewingOldVersion,
        isShowingDiff: $isShowingDiff,
        isShowingSingleTestView: $isShowingSingleTestView,
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
