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
    
    @State private var editablePrompt: String = ""
    @State private var showOlderVersions: Bool = false
    @State private var selectedHistoryVersion: PromptHistory?
    @State private var isPreviewingOldVersion: Bool = false
    @EnvironmentObject var settings: AppSettings
    @State private var isGenerating = false
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastType: AlertToast.AlertType = .regular

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
                editablePrompt = latest.promptText
            }
        }
        .onChange(of: history) { newHistory in
            if let latest = newHistory.first, !isPreviewingOldVersion {
                editablePrompt = latest.promptText
            }
        }
        .sheet(item: $selectedHistoryVersion) { version in
            versionDetailSheet(version)
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
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
    PromptDetail(prompt: PreviewData.samplePrompt)
        .modelContainer(PreviewData.previewContainer)
        .environmentObject(AppSettings())
        .environment(ServicesManager())
}
