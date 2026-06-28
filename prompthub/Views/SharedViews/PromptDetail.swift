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
    @State var isEditing = false
    @State var isPreviewingOldVersion: Bool = false
    @State var isGenerating = false
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastType: AlertToast.AlertType = .regular
    @State var isShowingDiff = false
    @State var isShowingSingleTestView = false
    @State var optimizeRequestID = 0
    @State var isShowingHistoryDrawer = false
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

    private var startsEditingOnAppear: Bool {
        isEphemeralDraft || prompt.name == "Untitled Prompt"
    }

    private var promptBrowserItem: PromptBrowserItem {
        let latestText = history.first?.promptText ?? ""
        let summary = (prompt.desc?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? (prompt.desc ?? "")
            : "No description"
        let metadata: [PromptBrowserMetadataRow] = [
            PromptBrowserMetadataRow(label: "Version", value: "v\(max(history.first?.version ?? 1, 1))"),
            PromptBrowserMetadataRow(label: "Created", value: formattedDate(history.first?.createdAt ?? Date())),
            PromptBrowserMetadataRow(label: "Updated", value: formattedDate(history.first?.updatedAt ?? Date())),
            PromptBrowserMetadataRow(label: "Link", value: prompt.link?.isEmpty == false ? "Attached" : "None"),
            PromptBrowserMetadataRow(label: "External Sources", value: (prompt.externalSources?.isEmpty ?? true) ? "None" : "Attached")
        ]
        let historyEntries = history.map { item in
            PromptBrowserHistoryEntry(
                id: item.id.uuidString,
                versionLabel: "v\(item.version)",
                timestamp: formattedDate(item.updatedAt),
                summary: historySummary(for: item.promptText),
                isCurrent: item.id == history.first?.id,
                onRestore: item.id == history.first?.id ? nil : { applyHistoryVersionToEditor(item) }
            )
        }

        return PromptBrowserItem(
            id: prompt.id.uuidString,
            title: prompt.name,
            summary: summary,
            promptText: latestText,
            systemImage: "doc.text",
            iconTint: PH.Color.accent,
            badges: [],
            trailingDetail: nil,
            metadata: metadata,
            historyEntries: historyEntries,
            primaryActionTitle: nil,
            primaryActionSystemImage: nil,
            isPrimaryActionDisabled: false,
            onPrimaryAction: nil,
            secondaryActionTitle: nil,
            secondaryActionSystemImage: nil,
            onSecondaryAction: nil,
            quickActions: promptQuickActions,
            isEditable: true,
            onSaveEdits: saveEdits,
            hasExternalSources: !((prompt.externalSources?.isEmpty) ?? true),
            isShared: existingSharedCreation != nil
        )
    }

    private var promptQuickActions: [PromptBrowserQuickAction] {
        [
            PromptBrowserQuickAction(
                id: "test-\(prompt.id.uuidString)",
                title: "Test",
                systemImage: "play.fill",
                emphasis: .standard,
                isDisabled: false,
                onSelect: { isShowingSingleTestView.toggle() }
            ),
            PromptBrowserQuickAction(
                id: "optimize-\(prompt.id.uuidString)",
                title: "Optimize",
                systemImage: "wand.and.stars",
                emphasis: .standard,
                isDisabled: false,
                onSelect: { optimizeRequestID += 1 }
            ),
            PromptBrowserQuickAction(
                id: "share-\(prompt.id.uuidString)",
                title: "Share",
                systemImage: "square.and.arrow.up",
                emphasis: .standard,
                isDisabled: isCreateShareLink,
                onSelect: { Task { await shareCreation() } }
            ),
            PromptBrowserQuickAction(
                id: "skill-\(prompt.id.uuidString)",
                title: "Promote",
                systemImage: "wand.and.stars.inverse",
                emphasis: .standard,
                isDisabled: false,
                onSelect: { promotePromptToSkill() }
            ),
            PromptBrowserQuickAction(
                id: "copy-\(prompt.id.uuidString)",
                title: "Copy",
                systemImage: "doc.on.doc",
                emphasis: .standard,
                isDisabled: false,
                onSelect: { _ = copyPromptToClipboard(prompt.getLatestPromptContent()) }
            ),
            PromptBrowserQuickAction(
                id: "delete-\(prompt.id.uuidString)",
                title: isEphemeralDraft ? "Discard" : "Delete",
                systemImage: "trash",
                emphasis: .standard,
                isDisabled: false,
                onSelect: { showingDeletePromptConfirmation = true }
            )
        ]
    }

    // MARK: - Body

    var body: some View {
        PromptBrowserDetail(
            item: promptBrowserItem,
            startsEditing: startsEditingOnAppear
        )
        .background(PH.Color.windowBg)
        .onAppear {
            if let latest = history.first { editablePrompt = latest.promptText }
        }
        .onChange(of: history) {
            if let latest = history.first, !isPreviewingOldVersion { editablePrompt = latest.promptText }
        }
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

    private func saveEdits(_ title: String, _ summary: String?, _ content: String) {
        prompt.name = title.isEmpty ? "Untitled Prompt" : title
        prompt.desc = summary
        prompt.latestHistoryEntry?.promptText = content
        prompt.latestHistoryEntry?.updatedAt = Date()
        editablePrompt = content
        try? modelContext.save()
        PromptHubBridge.shared.exportPrompt(prompt)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func historySummary(for text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "No content" : normalized
    }
}

#Preview {
    PromptDetail(
        prompt: PreviewData.samplePrompt,
        onPromoteToSkill: { _ in },
        onDeletePrompt: { _ in }
    )
        .modelContainer(PreviewData.previewContainer)
        .environmentObject(AppSettings())
        .environment(ServicesManager())
}
