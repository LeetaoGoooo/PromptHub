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
import GenKit
import AlertToast

struct PromptDetail: View {
    @Bindable var prompt:Prompt
    @Environment(\.modelContext) private var modelContext
    @Environment(ServicesManager.self) private var servicesManager
    @Query private var sharedCreations: [SharedCreation]
    private let draftService = SkillDraftService.shared
    let onPromoteToSkill: (Skill) -> Void
    @State private var isCreateShareLink = false
    @State private var isTogglingPublic = false
    
    enum FocusableField: Hashable {
        case name
        case description
        case content
    }
    
    @FocusState private var focusedField: FocusableField?
    
    @State private var editablePrompt: String = ""
    @State private var showOlderVersions: Bool = false
    @State private var selectedHistoryVersion: PromptHistory?
    @State private var isPreviewingOldVersion: Bool = false
    @EnvironmentObject var settings: AppSettings
    @State private var isGenerating = false
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastType: AlertToast.AlertType = .regular
    
    @State private var isShowingDiff = false
    @State private var isShowingSingleTestView = false

    private let cardBackground = Color(NSColor.controlBackgroundColor)
    private let borderColor = Color(NSColor.separatorColor)

    private var history: [PromptHistory] {
        prompt.history?.sorted { $0.version > $1.version } ?? []
    }

    private var existingSharedCreation: SharedCreation? {
        let name = prompt.name
        let content = prompt.getLatestPromptContent()
        return sharedCreations.first(where: { $0.name == name && $0.prompt == content })
    }

    private func findExistingSharedCreation() -> SharedCreation? {
        let name = prompt.name
        let content = prompt.getLatestPromptContent()
        return sharedCreations.first(where: { $0.name == name && $0.prompt == content })
    }

    private func copyPromptToClipboard(_ prompt: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(prompt, forType: .string)
    }
    
    private func copySharedLinkToClipboard(_ url: URL) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(url.absoluteString, forType: .string)
       
    }

    @MainActor
    private func shareCreation() async {
        isCreateShareLink = true
        
        let latestHistoryText = history.first?.promptText ?? ""

        // Check if a shared creation already exists for this prompt
        if let existingSharedItem = findExistingSharedCreation() {
            let urlScheme = "sharedprompt"
            guard let shareURL = URL(string: "\(urlScheme)://creation/\(existingSharedItem.id.uuidString)") else {
                showToastMsg(msg: "Could not create share URL")
                isCreateShareLink = false
                return
            }

            let success = copySharedLinkToClipboard(shareURL)
            if success {
                showToastMsg(msg: "Existing Share Link Copied", alertType: .complete(Color.green))
            } else {
                showToastMsg(msg: "Copy Share Link Failed", alertType: .error(Color.red))
            }
            isCreateShareLink = false
            return
        }

        // Create new shared creation if none exists
        let dataSources = prompt.externalSource?.map { DataSource(data: $0) } ?? []
        let sharedItem = SharedCreation(name: prompt.name, prompt: latestHistoryText, desc: prompt.desc, dataSources: dataSources)
        modelContext.insert(sharedItem)

        do {
            try modelContext.save()
            let publicCloudKitSyncManager = try PublicCloudKitSyncManager(
                containerIdentifier: CloudKitAccess.publicContainerIdentifier,
                modelContext: modelContext
            )
            try await publicCloudKitSyncManager.pushItemToPublicCloud(sharedItem)
            try modelContext.save()
        } catch {
            showToastMsg(msg: "Error saving shared item: \(error)")
            isCreateShareLink = false
            return
        }

        let urlScheme = "sharedprompt"
        guard let shareURL = URL(string: "\(urlScheme)://creation/\(sharedItem.id.uuidString)") else {
            showToastMsg(msg: "Could not create share URL")
            isCreateShareLink = false
            return
        }

        let success = copySharedLinkToClipboard(shareURL)
        if success {
            showToastMsg(msg: "Share Link With Your Friends Now", alertType: .complete(Color.green))
        } else {
            showToastMsg(msg: "Create Share Link Failed", alertType: .error(Color.red))
        }
        isCreateShareLink = false
    }

    @MainActor
    private func togglePublicStatus() async {
        guard let sharedCreation = existingSharedCreation else { return }

        isTogglingPublic = true

        // Toggle the public status
        sharedCreation.isPublic.toggle()
        sharedCreation.lastModified = Date()

        do {
            try modelContext.save()
            let publicCloudKitSyncManager = try PublicCloudKitSyncManager(
                containerIdentifier: CloudKitAccess.publicContainerIdentifier,
                modelContext: modelContext
            )
            try await publicCloudKitSyncManager.pushItemToPublicCloud(sharedCreation)

            let statusMessage = sharedCreation.isPublic ? "Prompt Made Public" : "Prompt Made Private"
            showToastMsg(msg: statusMessage, alertType: .complete(Color.green))
        } catch {
            // Revert the change if saving failed
            sharedCreation.isPublic.toggle()
            showToastMsg(msg: "Error updating prompt status: \(error)")
        }

        isTogglingPublic = false
    }

    @State private var showInspector: Bool = true // Default to visible for Pro feel

    private func promotePromptToSkill() {
        do {
            let draft = try draftService.createDraft(from: prompt, in: modelContext)
            showToastMsg(msg: "Skill draft created", alertType: .complete(Color.green))
            onPromoteToSkill(draft)
        } catch {
            showToastMsg(msg: "Failed to create skill draft: \(error.localizedDescription)")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main Stage: Editor
            VStack(alignment: .leading, spacing: 0) {
                promptHeader
                
                if let latestHistory = history.first {
                    LatestVersionView(
                        latestHistory: latestHistory,
                        prompt: prompt,
                        editablePrompt: $editablePrompt,
                        isGenerating: $isGenerating,
                        isPreviewingOldVersion: $isPreviewingOldVersion,
                        isShowingDiff: $isShowingDiff,
                        isShowingSingleTestView: $isShowingSingleTestView,
                        copyPromptToClipboard: copyPromptToClipboard,
                        copySharedLinkToClipboard: copySharedLinkToClipboard,
                        modifyPromptWithOpenAIStream: modifyPromptWithOpenAIStream,
                        onShare: shareCreation
                    )
                } else {
                     ContentUnavailableView("No Content", systemImage: "doc.text")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Divider
            if showInspector {
                Divider()
                
                // Trailing Pane: Inspector
                InspectorView(
                    prompt: prompt,
                    showOlderVersions: $showOlderVersions,
                    selectedHistoryVersion: $selectedHistoryVersion,
                    isPreviewingOldVersion: $isPreviewingOldVersion,
                    editablePrompt: $editablePrompt,
                    showToastMsg: showToastMsg,
                    copyPromptToClipboard: copyPromptToClipboard,
                    deleteHistoryItem: { item in
                        modelContext.delete(item)
                    },
                    onShare: shareCreation,
                    onTogglePublic: togglePublicStatus
                )
                .transition(.move(edge: .trailing))
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if let latest = history.first {
                editablePrompt = latest.promptText
            }
            
            // Auto-focus name if it's a new "Untitled Prompt"
            if prompt.name == "Untitled Prompt" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .name
                }
            }
        }
        .onChange(of: history) {
            if let latest = history.first, !isPreviewingOldVersion {
                editablePrompt = latest.promptText
            }
        }
        .sheet(item: $selectedHistoryVersion) { version in
            versionDetailSheet(version)
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
        }
        .onChange(of: prompt.name) {
            try? modelContext.save()
        }
        .onChange(of: prompt.desc) {
            try? modelContext.save()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: promotePromptToSkill) {
                    Image(systemName: "wand.and.stars.inverse")
                }
                .help("Promote this prompt into a skill draft")
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showInspector.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help("Toggle Inspector")
            }
        }
    }

    @ViewBuilder
    private var promptHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Prompt Name", text: $prompt.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .bold))
                    .focused($focusedField, equals: .name)
                    .padding(.horizontal, -4) // Align with text below
                
                Spacer()
                
                headerActions
            }
            
            TextField("Add a description...", text: Binding(
                get: { prompt.desc ?? "" },
                set: { prompt.desc = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, -4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var headerActions: some View {
        HStack(spacing: 8) {
            // Test
            Button {
                isShowingSingleTestView.toggle()
            } label: {
                Label("Test", systemImage: "play.fill")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Test this prompt")
            
            // Diff Toggle
            Button {
                isShowingDiff.toggle()
            } label: {
                 Label("Diff", systemImage: "clock.arrow.circlepath")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Toggle Diff View")

            Divider().frame(height: 16).padding(.horizontal, 4)

            // Share
            Button {
                Task { await shareCreation() }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .padding(4)
            }
            .buttonStyle(.plain)
            .help("Share")
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
                Text(version.promptText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }

            HStack {
                Spacer()

                Button {
                    copyPromptToClipboard(version.promptText)
                } label: {
                    Label("Copy Content", systemImage: "doc.on.doc")
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    isPreviewingOldVersion = true
                    editablePrompt = version.promptText
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
    private func showToastMsg(msg: String, alertType: AlertToast.AlertType = .error(Color.red)) {
        showToast.toggle()
        toastTitle = msg
        toastType = alertType
    }

    @MainActor
    private func modifyPromptWithOpenAIStream() async {
        guard let latestHistory = history.first else { return }
        
        guard let selectedService = servicesManager.get(servicesManager.selectedServiceID) else {
            showToastMsg(msg: "No selected service found", alertType: .error(Color.red))
            return
        }
        
        guard !selectedService.token.isEmpty else {
            showToastMsg(msg: "Service token is missing", alertType: .error(Color.red))
            return
        }
        
        guard !(selectedService.preferredChatModel == nil) else {
            showToastMsg(msg: "Service model is missing", alertType: .error(Color.red))
            return
        }
        
        guard !selectedService.models.isEmpty && ((selectedService.models.first(where:{$0.id == selectedService.preferredChatModel})) != nil) else {
            showToastMsg(msg: "Service model is missing", alertType: .error(Color.red))
            return
        }
        
        isGenerating = true
        let userPrompt = latestHistory.promptText
        let systemPrompt = settings.prompt
        
        do {
            let service = selectedService.modelService(session: nil)
            
            let models = selectedService.models
            let modelId = selectedService.preferredChatModel!
            let model = selectedService.models.first(where:{$0.id == modelId})!
            
            var accumulatedResponse = ""
            
            // Create a basic chat completion request
            let request = ChatServiceRequest(
                model: model,
                messages: [
                    Message(role: .system, content: systemPrompt),
                    Message(role: .user, content: userPrompt)
                ]
            )
            
            if let chatService = service as? ChatService {
                do {
                    var streamRequest = ChatSessionRequest(service: chatService, model: model)
                    streamRequest.with(system: systemPrompt)
                    streamRequest.with(history: [Message(role: .user, content: userPrompt)])
                    
                    for try await message in ChatSession.shared.stream(streamRequest) {
                        if let content = message.content {
                            DispatchQueue.main.async {
                                // 只更新 editablePrompt，不创建历史记录
                                self.editablePrompt = content
                            }
                            accumulatedResponse = content
                        }
                    }
                } catch {
                    showToastMsg(msg: "Streaming failed, using fallback completion", alertType: .error(Color.orange))
                    let response = try await chatService.completion(request)
                    if let content = response.content {
                        DispatchQueue.main.async {
                            // 只更新 editablePrompt，不创建历史记录
                            self.editablePrompt = content
                        }
                        accumulatedResponse = content
                    }
                }
            } else {
                showToastMsg(msg: "Selected service does not support chat completion", alertType: .error(Color.red))
                isGenerating = false
                return
            }
            
            isGenerating = false
            
        } catch {
            showToastMsg(msg: "Error making GenKit API request: \(error)", alertType: .error(Color.red))
            isGenerating = false
        }
    }
}

#Preview {
    PromptDetail(
        prompt: PreviewData.samplePrompt,
        onPromoteToSkill: { _ in }
    )
        .modelContainer(PreviewData.previewContainer)
        .environmentObject(AppSettings())
        .environment(ServicesManager())
}
