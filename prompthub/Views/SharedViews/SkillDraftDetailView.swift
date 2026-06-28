import AlertToast
import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI

struct SkillDraftDetailView: View {
    @Bindable var skill: Skill
    @Environment(\.modelContext) var modelContext
    let onCloseWorkspace: (() -> Void)?

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
    @State var isShowingInspectorDrawer = false

    init(skill: Skill, onCloseWorkspace: (() -> Void)? = nil) {
        self.skill = skill
        self.onCloseWorkspace = onCloseWorkspace
    }

    var body: some View {
        VStack(spacing: 0) {
            workspaceHeader
            GeometryReader { proxy in
                ZStack(alignment: .topTrailing) {
                    HSplitView {
                        packageSidebar
                            .frame(minWidth: 180, idealWidth: 220, maxWidth: 300)

                        editorPane
                            .frame(minWidth: 300, maxWidth: .infinity)
                    }

                    if isShowingInspectorDrawer {
                        inspectorDrawer(maxHeight: proxy.size.height - 24)
                            .padding(.top, 12)
                            .padding(.trailing, 12)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .zIndex(1)
                    }
                }
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .animation(.easeInOut(duration: 0.18), value: isShowingInspectorDrawer)
        .task(id: skill.id) {
            loadPackageWorkspace(resetSelection: true)
        }
        .onChange(of: packageItems.map(\.relativePath)) { _, _ in
            ensureValidSelection()
        }
        .onDeleteCommand {
            requestDeleteSelectedItem()
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
