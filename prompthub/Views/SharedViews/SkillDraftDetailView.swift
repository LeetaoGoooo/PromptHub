import AlertToast
import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI

struct SkillDraftDetailView: View {
    @Bindable var skill: Skill
    @Environment(\.modelContext) var modelContext

    let draftService = SkillDraftService.shared

    @State var instructionsText = ""
    @State var tagText = ""
    @State var installScope: SkillInstallScope = .project
    @State var selectedAgents = Set(AgentWorkflow.defaultTargets)
    @State var isInstalling = false
    @State var showToast = false
    @State var toastTitle = ""
    @State var toastType: AlertToast.AlertType = .regular
    @State var packageItems: [SkillDraftPackageItem] = []
    @State var selectedRelativePath: String = "SKILL.md"
    @State var editorText = ""
    @State var persistedEditorText = ""
    @State var selectedItemIsEditableText = true
    @State var isLoadingPackage = false
    @State var showingNewItemSheet = false
    @State var newItemKind: SkillDraftPackageStore.NewItemKind = .file
    @State var newItemName = ""
    @State var expandedDirectories: Set<String> = []
    @State var pendingDeletionItem: SkillDraftPackageItem?

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            Divider()
            HSplitView {
                packageSidebar
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

                editorPane
                    .frame(minWidth: 300, maxWidth: .infinity)

                inspectorPane
                    .frame(minWidth: 240, idealWidth: 280, maxWidth: 340)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .task(id: skill.id) {
            loadPackageWorkspace(resetSelection: true)
        }
        .onDeleteCommand {
            requestDeleteSelectedItem()
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: saveSelectedFile) {
                    Label("Save File", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!hasUnsavedChanges || !selectedItemIsEditableText)

                Button(action: createVersionSnapshot) {
                    Label("Save Version", systemImage: "square.stack.3d.up.fill")
                }.help("Save the current draft as a new version snapshot")

                Button(action: copySkillMarkdown) {
                    Label("Copy SKILL.md", systemImage: "doc.on.doc")
                }.help("Copy the exported SKILL.md to the clipboard")

                Button(action: revealSelectedItemInFinder) {
                    Label("Reveal in Finder", systemImage: "finder")
                }
                .help("Reveal the selected package item in Finder")
            }
        }
        .sheet(isPresented: $showingNewItemSheet) {
            newItemSheet
        }
        .alert("Delete Item", isPresented: Binding(
            get: { pendingDeletionItem != nil },
            set: { if !$0 { pendingDeletionItem = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                pendingDeletionItem = nil
            }
            Button("Delete", role: .destructive) {
                if let item = pendingDeletionItem {
                    deletePackageItem(item)
                }
            }
        } message: {
            if let item = pendingDeletionItem {
                Text("Delete \(item.displayName)? This removes it from the draft package.")
            }
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
        }
    }
}
