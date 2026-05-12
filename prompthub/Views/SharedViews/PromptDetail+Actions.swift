import SwiftUI
import SwiftData
import GenKit
import AlertToast

// MARK: - Actions

extension PromptDetail {

    func promotePromptToSkill() {
        do {
            let draft = try draftService.createDraft(from: prompt, in: modelContext)
            showToastMsg(msg: "Skill draft created", alertType: .complete(Color.green))
            onPromoteToSkill(draft)
        } catch {
            showToastMsg(msg: "Failed to create skill draft: \(error.localizedDescription)")
        }
    }

    @MainActor
    func shareCreation() async {
        isCreateShareLink = true
        let latestHistoryText = history.first?.promptText ?? ""

        if let existingSharedItem = findExistingSharedCreation() {
            let urlScheme = "sharedprompt"
            guard let shareURL = URL(string: "\(urlScheme)://creation/\(existingSharedItem.id.uuidString)") else {
                showToastMsg(msg: "Could not create share URL"); isCreateShareLink = false; return
            }
            showToastMsg(
                msg: copySharedLinkToClipboard(shareURL) ? "Existing Share Link Copied" : "Copy Share Link Failed",
                alertType: copySharedLinkToClipboard(shareURL) ? .complete(Color.green) : .error(Color.red)
            )
            isCreateShareLink = false; return
        }

        let dataSources = prompt.externalSource?.map { DataSource(data: $0) } ?? []
        let sharedItem = SharedCreation(name: prompt.name, prompt: latestHistoryText, desc: prompt.desc, dataSources: dataSources)
        modelContext.insert(sharedItem)
        do {
            try modelContext.save()
            let syncManager = try PublicCloudKitSyncManager(
                containerIdentifier: CloudKitAccess.publicContainerIdentifier,
                modelContext: modelContext
            )
            try await syncManager.pushItemToPublicCloud(sharedItem)
            try modelContext.save()
        } catch {
            showToastMsg(msg: "Error saving shared item: \(error)"); isCreateShareLink = false; return
        }

        let urlScheme = "sharedprompt"
        guard let shareURL = URL(string: "\(urlScheme)://creation/\(sharedItem.id.uuidString)") else {
            showToastMsg(msg: "Could not create share URL"); isCreateShareLink = false; return
        }
        showToastMsg(
            msg: copySharedLinkToClipboard(shareURL) ? "Share Link With Your Friends Now" : "Create Share Link Failed",
            alertType: copySharedLinkToClipboard(shareURL) ? .complete(Color.green) : .error(Color.red)
        )
        isCreateShareLink = false
    }

    @MainActor
    func togglePublicStatus() async {
        guard let sharedCreation = existingSharedCreation else { return }
        isTogglingPublic = true
        sharedCreation.isPublic.toggle()
        sharedCreation.lastModified = Date()
        do {
            try modelContext.save()
            let syncManager = try PublicCloudKitSyncManager(
                containerIdentifier: CloudKitAccess.publicContainerIdentifier,
                modelContext: modelContext
            )
            try await syncManager.pushItemToPublicCloud(sharedCreation)
            showToastMsg(msg: sharedCreation.isPublic ? "Prompt Made Public" : "Prompt Made Private", alertType: .complete(Color.green))
        } catch {
            sharedCreation.isPublic.toggle()
            showToastMsg(msg: "Error updating prompt status: \(error)")
        }
        isTogglingPublic = false
    }

    @MainActor
    func showToastMsg(msg: String, alertType: AlertToast.AlertType = .error(Color.red)) {
        showToast.toggle(); toastTitle = msg; toastType = alertType
    }

    @MainActor
    func applyHistoryVersionToEditor(_ version: PromptHistory) {
        if history.first?.id == version.id {
            selectedHistoryVersion = nil
            showToastMsg(msg: "Version \(version.version) is already current", alertType: .complete(Color.orange))
            return
        }

        let nextVersion = (prompt.history?.map(\ .version).max() ?? 0) + 1
        let newHistory = prompt.createHistory(prompt: version.promptText, version: nextVersion)
        newHistory.createdAt = Date()
        newHistory.updatedAt = Date()
        newHistory.version = nextVersion
        modelContext.insert(newHistory)

        do {
            try modelContext.save()
            isPreviewingOldVersion = true
            editablePrompt = version.promptText
            PromptHubBridge.shared.exportPrompt(prompt)
            selectedHistoryVersion = nil
            showToastMsg(msg: "Applied version \(version.version) as v\(nextVersion)", alertType: .complete(Color.green))
            Task { @MainActor in
                isPreviewingOldVersion = false
            }
        } catch {
            modelContext.delete(newHistory)
            showToastMsg(msg: "Failed to apply version: \(error.localizedDescription)")
        }
    }

    @MainActor
    func modifyPromptWithOpenAIStream() async {
        guard let latestHistory = history.first else { return }
        guard let selectedService = servicesManager.get(servicesManager.selectedServiceID) else {
            showToastMsg(msg: "No selected service found"); return
        }
        guard !selectedService.token.isEmpty else {
            showToastMsg(msg: "Service token is missing"); return
        }
        guard selectedService.preferredChatModel != nil else {
            showToastMsg(msg: "Service model is missing"); return
        }
        guard !selectedService.models.isEmpty,
              selectedService.models.first(where: { $0.id == selectedService.preferredChatModel }) != nil else {
            showToastMsg(msg: "Service model is missing"); return
        }

        isGenerating = true
        let userPrompt  = latestHistory.promptText
        let systemPrompt = settings.prompt
        let model = selectedService.models.first(where: { $0.id == selectedService.preferredChatModel! })!

        do {
            let service = selectedService.modelService(session: nil)
            if let chatService = service as? ChatService {
                var streamRequest = ChatSessionRequest(service: chatService, model: model)
                streamRequest.with(system: systemPrompt)
                streamRequest.with(history: [Message(role: .user, content: userPrompt)])
                do {
                    for try await message in ChatSession.shared.stream(streamRequest) {
                        if let content = message.content { editablePrompt = content }
                    }
                } catch {
                    showToastMsg(msg: "Streaming failed, using fallback", alertType: .error(Color.orange))
                    let request = ChatServiceRequest(model: model, messages: [
                        Message(role: .system, content: systemPrompt),
                        Message(role: .user, content: userPrompt)
                    ])
                    let response = try await chatService.completion(request)
                    if let content = response.content { editablePrompt = content }
                }
            } else {
                showToastMsg(msg: "Selected service does not support chat completion")
            }
        } catch {
            showToastMsg(msg: "Error making GenKit API request: \(error)")
        }
        isGenerating = false
    }
}
