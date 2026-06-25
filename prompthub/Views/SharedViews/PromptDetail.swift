import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import GenKit
import AlertToast

struct PromptDetail: View {
    @Bindable var prompt: Prompt
    @Environment(\.modelContext) var modelContext
    @Environment(ServicesManager.self) var servicesManager
    @Query var sharedCreations: [SharedCreation]
    let onPromoteToSkill: (Skill) -> Void
    let onDeletePrompt: (Prompt) -> Void

    let draftService = SkillDraftService.shared

    enum FocusableField: Hashable { case name, description, content }
    @FocusState var focusedField: FocusableField?

    @State var editablePrompt: String = ""
    @State var selectedHistoryVersion: PromptHistory?
    @State var isPreviewingOldVersion: Bool = false
    @State var isGenerating = false
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastType: AlertToast.AlertType = .regular
    @State var isShowingDiff = false
    @State var isShowingSingleTestView = false
    @State var isCreateShareLink = false
    @State var isTogglingPublic = false
    @State var showingDeletePromptConfirmation = false
    @EnvironmentObject var settings: AppSettings

    // MARK: - Computed

    var history: [PromptHistory] { prompt.history?.sorted { $0.version > $1.version } ?? [] }

    var existingSharedCreation: SharedCreation? {
        let name = prompt.name; let content = prompt.getLatestPromptContent()
        return sharedCreations.first(where: { $0.name == name && $0.prompt == content })
    }

    func findExistingSharedCreation() -> SharedCreation? {
        let name = prompt.name; let content = prompt.getLatestPromptContent()
        return sharedCreations.first(where: { $0.name == name && $0.prompt == content })
    }

    @discardableResult
    func copyPromptToClipboard(_ prompt: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(prompt, forType: .string)
    }

    @discardableResult
    func copySharedLinkToClipboard(_ url: URL) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    var isEphemeralDraft: Bool {
        let trimmedName = prompt.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = (prompt.desc ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = prompt.getLatestPromptContent().trimmingCharacters(in: .whitespacesAndNewlines)
        let hasExternalSources = !(prompt.externalSources?.isEmpty ?? true)

        return !hasExternalSources
            && prompt.link == nil
            && history.count <= 1
            && trimmedDescription.isEmpty
            && trimmedContent.isEmpty
            && (trimmedName.isEmpty || trimmedName == "Untitled Prompt")
    }

    var deletePromptTitle: String {
        isEphemeralDraft ? "Discard Draft" : "Delete Prompt"
    }

    var deletePromptMessage: String {
        isEphemeralDraft
            ? "Discard this empty prompt draft and return to your prompt list?"
            : "Delete \"\(prompt.name)\"? This action cannot be undone."
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                promptHeader
                promptActionCard
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    promptInfoCard(latestHistory: latestHistory)
                    promptSharingCard
                    promptHistoryCard
                } else {
                    ContentUnavailableView("No Content", systemImage: "doc.text")
                        .frame(maxWidth: .infinity, minHeight: 320)
                        .padding(.horizontal, 24)
                }
            }
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if let latest = history.first { editablePrompt = latest.promptText }
            if prompt.name == "Untitled Prompt" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { focusedField = .name }
            }
        }
        .onChange(of: history) {
            if let latest = history.first, !isPreviewingOldVersion { editablePrompt = latest.promptText }
        }
        .sheet(item: $selectedHistoryVersion) { version in versionDetailSheet(version) }
        .alert(deletePromptTitle, isPresented: $showingDeletePromptConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button(isEphemeralDraft ? "Discard" : "Delete", role: .destructive) {
                onDeletePrompt(prompt)
            }
        } message: {
            Text(deletePromptMessage)
        }
        .toast(isPresenting: $showToast) { AlertToast(type: toastType, title: toastTitle) }
        .onChange(of: prompt.name)  { try? modelContext.save() }
        .onChange(of: prompt.desc)  { try? modelContext.save() }
    }
}

#Preview {
    PromptDetail(prompt: PreviewData.samplePrompt, onPromoteToSkill: { _ in }, onDeletePrompt: { _ in })
        .modelContainer(PreviewData.previewContainer)
        .environmentObject(AppSettings())
        .environment(ServicesManager())
}
