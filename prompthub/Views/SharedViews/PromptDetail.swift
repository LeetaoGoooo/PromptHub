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
    @State var showInspector: Bool = true
    @State var isCreateShareLink = false
    @State var isTogglingPublic = false
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

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
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

            if showInspector {
                Divider()
                InspectorView(
                    prompt: prompt,
                    selectedHistoryVersion: $selectedHistoryVersion,
                    showToastMsg: showToastMsg,
                    copyPromptToClipboard: copyPromptToClipboard,
                    deleteHistoryItem: { modelContext.delete($0) },
                    onShare: shareCreation,
                    onTogglePublic: togglePublicStatus
                )
                .transition(.move(edge: .trailing))
            }
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
        .toast(isPresenting: $showToast) { AlertToast(type: toastType, title: toastTitle) }
        .onChange(of: prompt.name)  { try? modelContext.save() }
        .onChange(of: prompt.desc)  { try? modelContext.save() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: promotePromptToSkill) {
                    Image(systemName: "wand.and.stars.inverse")
                }
                .help("Promote this prompt into a skill draft")
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { showInspector.toggle() }
                } label: {
                    Image(systemName: "sidebar.right")
                }
                .help("Toggle Inspector")
            }
        }
    }
}

#Preview {
    PromptDetail(prompt: PreviewData.samplePrompt, onPromoteToSkill: { _ in })
        .modelContainer(PreviewData.previewContainer)
        .environmentObject(AppSettings())
        .environment(ServicesManager())
}
