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

    let borderColor = Color(NSColor.separatorColor)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                metadataCard
                instructionsCard
                installCard
                versionsCard
                markdownPreviewCard
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .navigationTitle(skill.displayName)
        .task(id: skill.id) {
            do {
                let latest = try draftService.ensureLatestVersion(for: skill, in: modelContext)
                syncEditorState(from: latest)
            } catch {
                showToastMsg("Failed to load draft: \(error.localizedDescription)")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: createVersionSnapshot) {
                    Label("Save Version", systemImage: "square.stack.3d.up.fill")
                }.help("Save the current draft as a new version snapshot")

                Button(action: copySkillMarkdown) {
                    Label("Copy SKILL.md", systemImage: "doc.on.doc")
                }.help("Copy the exported SKILL.md to the clipboard")
            }
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
        }
    }
}
