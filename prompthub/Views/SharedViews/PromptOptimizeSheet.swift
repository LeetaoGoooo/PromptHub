import AlertToast
import GenKit
import SwiftData
import SwiftUI

struct PromptOptimizeSheet: View {
    @Bindable var prompt: Prompt
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ServicesManager.self) private var servicesManager
    @EnvironmentObject private var settings: AppSettings

    @State private var workingPrompt = ""
    @State private var originalText = ""
    @State private var modifiedText = ""
    @State private var diffResults: [DiffResult] = []
    @State private var isGenerating = false
    @State private var isShowingDiff = false
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastType: AlertToast.AlertType = .regular

    private var latestHistory: PromptHistory? {
        prompt.latestHistoryEntry
    }

    private var promptVariables: [String] {
        let pattern = #"\{\{[^{}]+\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let text = workingPrompt as NSString
        let matches = regex.matches(in: workingPrompt, range: NSRange(location: 0, length: text.length))

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

    private var propertyRows: [(String, String)] {
        [
            ("Version", "v\(max(prompt.latestVersionNumber, 1))"),
            ("Updated", prompt.lastEditedAt.map(PromptViewHelpers.relativeDateString(from:)) ?? "Unknown"),
            ("Variables", "\(promptVariables.count)"),
            ("Mode", isShowingDiff ? "Reviewing AI changes" : "Ready to optimize")
        ]
    }

    private var quickActions: [PromptBrowserQuickAction] {
        [
            PromptBrowserQuickAction(
                id: "optimize",
                title: isGenerating ? "Optimizing…" : "Optimize with AI",
                systemImage: "wand.and.stars",
                emphasis: .prominent,
                isDisabled: isGenerating || latestHistory == nil || isShowingDiff,
                onSelect: { Task { await optimizeWithAI() } }
            ),
            PromptBrowserQuickAction(
                id: "copy",
                title: "Copy Prompt",
                systemImage: "doc.on.doc",
                emphasis: .standard,
                isDisabled: false,
                onSelect: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(workingPrompt, forType: .string)
                    showToastMsg(msg: "Prompt copied", alertType: .complete(.green))
                }
            ),
            PromptBrowserQuickAction(
                id: "back",
                title: "Back to Library",
                systemImage: "sidebar.left",
                emphasis: .standard,
                isDisabled: false,
                onSelect: { dismiss() }
            )
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("AI Optimize Prompt")
                        .font(.title3.weight(.semibold))
                    Text(prompt.name)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PromptCollectionInspectorPanel(title: "Properties") {
                        VStack(alignment: .leading, spacing: 14) {
                            PromptCollectionKVList(items: propertyRows)

                            if !promptVariables.isEmpty {
                                Divider()

                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Variables")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)

                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                                        ForEach(promptVariables, id: \.self) { variable in
                                            Text(variable)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.accent)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 5)
                                                .background(Color.accentColor.opacity(0.10), in: Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }

                    PromptCollectionInspectorPanel(title: "Quick Actions") {
                        PromptQuickActionWrap(actions: quickActions)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(isShowingDiff ? "AI Diff Review" : "Prompt Content")
                            .font(.headline)

                        if isShowingDiff {
                            AIOptimizeDiffPanel(
                                diffResults: diffResults,
                                originalText: originalText,
                                modifiedText: modifiedText,
                                onKeep: keepChanges,
                                onDiscard: discardChanges
                            )
                        } else {
                            ScrollView {
                                Text(workingPrompt)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .textSelection(.enabled)
                            }
                            .frame(minHeight: 260, idealHeight: 320, maxHeight: 360)
                            .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(minWidth: 760, minHeight: 620)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            workingPrompt = latestHistory?.promptText ?? prompt.getLatestPromptContent()
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
        }
    }

    @MainActor
    private func optimizeWithAI() async {
        guard let latestHistory else {
            showToastMsg(msg: "No prompt content available")
            return
        }

        guard let selectedService = servicesManager.get(servicesManager.selectedServiceID) else {
            showToastMsg(msg: "No selected service found")
            return
        }
        guard !selectedService.token.isEmpty else {
            showToastMsg(msg: "Service token is missing")
            return
        }
        guard let preferredModelID = selectedService.preferredChatModel,
              let model = selectedService.models.first(where: { $0.id == preferredModelID }) else {
            showToastMsg(msg: "Service model is missing")
            return
        }

        let userPrompt = latestHistory.promptText
        originalText = userPrompt
        isGenerating = true

        do {
            let service = selectedService.modelService(session: nil)
            if let chatService = service as? ChatService {
                var streamRequest = ChatSessionRequest(service: chatService, model: model)
                streamRequest.with(system: settings.prompt)
                streamRequest.with(history: [Message(role: .user, content: userPrompt)])

                workingPrompt = ""
                do {
                    for try await message in ChatSession.shared.stream(streamRequest) {
                        if let content = message.content {
                            workingPrompt = content
                        }
                    }
                } catch {
                    showToastMsg(msg: "Streaming failed, using fallback", alertType: .error(.orange))
                    let request = ChatServiceRequest(model: model, messages: [
                        Message(role: .system, content: settings.prompt),
                        Message(role: .user, content: userPrompt)
                    ])
                    let response = try await chatService.completion(request)
                    if let content = response.content {
                        workingPrompt = content
                    }
                }
            } else {
                showToastMsg(msg: "Selected service does not support chat completion")
                isGenerating = false
                return
            }
        } catch {
            showToastMsg(msg: "Error making GenKit API request: \(error)")
            isGenerating = false
            return
        }

        isGenerating = false
        modifiedText = workingPrompt
        diffResults = createDiffWithDifferenceKit(
            old: originalText.components(separatedBy: .newlines),
            new: modifiedText.components(separatedBy: .newlines)
        )

        guard originalText != modifiedText, !diffResults.isEmpty else {
            showToastMsg(msg: "No changes suggested", alertType: .complete(.orange))
            return
        }

        isShowingDiff = true
    }

    private func keepChanges() {
        let version = (prompt.history?.map { $0.version }.max() ?? 0) + 1
        let newHistory = prompt.createHistory(prompt: modifiedText, version: version)
        newHistory.createdAt = Date()
        newHistory.updatedAt = Date()
        newHistory.version = version

        modelContext.insert(newHistory)

        do {
            try modelContext.save()
            PromptHubBridge.shared.exportPrompt(prompt)
            workingPrompt = modifiedText
            isShowingDiff = false
            diffResults = []
            originalText = ""
            modifiedText = ""
            showToastMsg(msg: "Optimized version saved", alertType: .complete(.green))
        } catch {
            showToastMsg(msg: "Error saving changes: \(error)")
        }
    }

    private func discardChanges() {
        workingPrompt = originalText
        isShowingDiff = false
        diffResults = []
        modifiedText = ""
        originalText = ""
        showToastMsg(msg: "Changes discarded", alertType: .complete(.orange))
    }

    @MainActor
    private func showToastMsg(msg: String, alertType: AlertToast.AlertType = .error(.red)) {
        toastTitle = msg
        toastType = alertType
        showToast.toggle()
    }
}