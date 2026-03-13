import AlertToast
import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI

struct SkillDraftDetailView: View {
    @Bindable var skill: Skill
    @Environment(\.modelContext) private var modelContext

    private let draftService = SkillDraftService.shared

    @State private var instructionsText = ""
    @State private var tagText = ""
    @State private var installScope: SkillInstallScope = .project
    @State private var selectedAgents = Set(AgentWorkflow.defaultTargets)
    @State private var isInstalling = false
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastType: AlertToast.AlertType = .regular

    private let borderColor = Color(NSColor.separatorColor)

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
                }
                .help("Save the current draft as a new version snapshot")

                Button(action: copySkillMarkdown) {
                    Label("Copy SKILL.md", systemImage: "doc.on.doc")
                }
                .help("Copy the exported SKILL.md to the clipboard")
            }
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
        }
    }

    private var metadataCard: some View {
        card(title: "Metadata", subtitle: "Edit the draft fields that become skill metadata and library labels.") {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Skill Name", text: $skill.name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: skill.name) {
                        skill.slug = Skill.makeSlug(from: skill.name)
                        saveDraftMetadata()
                    }

                TextField("Description", text: descriptionBinding, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: descriptionBinding.wrappedValue) {
                        saveDraftMetadata()
                    }

                HStack(spacing: 12) {
                    TextField("Slug", text: $skill.slug)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: skill.slug) {
                            skill.slug = Skill.makeSlug(from: skill.slug)
                            saveDraftMetadata()
                        }

                    TextField("Identifier", text: $skill.identifier)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: skill.identifier) {
                            saveDraftMetadata()
                        }
                }

                HStack(spacing: 12) {
                    TextField("Category", text: $skill.category)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: skill.category) {
                            saveDraftMetadata()
                        }

                    TextField("Tags (comma separated)", text: $tagText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: tagText) {
                            skill.tags = tagText
                                .split(separator: ",")
                                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                .filter { !$0.isEmpty }
                            saveDraftMetadata()
                        }
                }

                HStack(spacing: 12) {
                    TextField("Input Schema", text: inputSchemaBinding, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: inputSchemaBinding.wrappedValue) {
                            saveDraftMetadata()
                        }

                    TextField("Output Schema", text: outputSchemaBinding, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: outputSchemaBinding.wrappedValue) {
                            saveDraftMetadata()
                        }
                }

                TextField("Safety Policy", text: safetyPolicyBinding, axis: .vertical)
                    .lineLimit(2...4)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: safetyPolicyBinding.wrappedValue) {
                        saveDraftMetadata()
                    }
            }
        }
    }

    private var instructionsCard: some View {
        card(title: "Instructions", subtitle: "These instructions are exported as the body of SKILL.md and installed into target agents.") {
            TextEditor(text: $instructionsText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 280)
                .padding(12)
                .background(Color(NSColor.textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(borderColor.opacity(0.4), lineWidth: 1)
                }
                .onChange(of: instructionsText) {
                    saveInstructions()
                }
        }
    }

    private var installCard: some View {
        card(title: "Install Draft", subtitle: "Install the current draft directly into your configured agent skills directory.") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Scope", selection: $installScope) {
                    Text("Project").tag(SkillInstallScope.project)
                    Text("Global").tag(SkillInstallScope.global)
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Agents")
                        .font(.subheadline.weight(.medium))

                    ForEach(AgentWorkflow.allCases, id: \.rawValue) { agent in
                        Toggle(agent.displayName, isOn: Binding(
                            get: { selectedAgents.contains(agent) },
                            set: { isSelected in
                                if isSelected {
                                    selectedAgents.insert(agent)
                                } else {
                                    selectedAgents.remove(agent)
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                    }
                }

                HStack {
                    Button(action: installDraft) {
                        if isInstalling {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Label("Install Current Draft", systemImage: "arrow.down.circle")
                        }
                    }
                    .disabled(isInstalling)

                    if let lastInstalledAt = skill.lastInstalledAt {
                        Text("Last installed \(lastInstalledAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var versionsCard: some View {
        card(title: "Version History", subtitle: "Version snapshots let you keep stable points while continuing to edit the draft.") {
            if skill.sortedVersions.isEmpty {
                Text("No saved versions yet.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(skill.sortedVersions) { version in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(version.version)
                                    .font(.subheadline.monospaced().weight(.semibold))
                                Text(version.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Duplicate Into Latest") {
                                duplicateVersion(version)
                            }
                        }

                        Text(version.instructions)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if version.id != skill.sortedVersions.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var markdownPreviewCard: some View {
        card(title: "SKILL.md Preview", subtitle: "This is the markdown that will be copied or installed.") {
            ScrollView(.horizontal) {
                Text(draftService.exportMarkdown(for: skill))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color(NSColor.textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor.opacity(0.4), lineWidth: 1)
            }
        }
    }

    private var descriptionBinding: Binding<String> {
        Binding(
            get: { skill.desc ?? "" },
            set: { skill.desc = $0.isEmpty ? nil : $0 }
        )
    }

    private var inputSchemaBinding: Binding<String> {
        Binding(
            get: { skill.inputSchema ?? "" },
            set: { skill.inputSchema = $0.isEmpty ? nil : $0 }
        )
    }

    private var outputSchemaBinding: Binding<String> {
        Binding(
            get: { skill.outputSchema ?? "" },
            set: { skill.outputSchema = $0.isEmpty ? nil : $0 }
        )
    }

    private var safetyPolicyBinding: Binding<String> {
        Binding(
            get: { skill.safetyPolicy ?? "" },
            set: { skill.safetyPolicy = $0.isEmpty ? nil : $0 }
        )
    }

    private func card<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor.opacity(0.4), lineWidth: 1)
        }
    }

    private func syncEditorState(from latestVersion: SkillVersion) {
        instructionsText = latestVersion.instructions
        tagText = skill.tags.joined(separator: ", ")
        if selectedAgents.isEmpty {
            selectedAgents = Set(AgentWorkflow.defaultTargets)
        }
    }

    private func saveDraftMetadata() {
        skill.touch()
        try? modelContext.save()
    }

    private func saveInstructions() {
        if let latest = skill.latestVersion {
            latest.instructions = instructionsText
            latest.parentSkillID = skill.id
        }
        skill.touch()
        try? modelContext.save()
    }

    private func createVersionSnapshot() {
        do {
            _ = try draftService.snapshotVersion(for: skill, using: instructionsText, in: modelContext)
            showToastMsg("Saved \(skill.latestVersion?.version ?? "new")")
        } catch {
            showToastMsg("Failed to save snapshot: \(error.localizedDescription)")
        }
    }

    private func duplicateVersion(_ version: SkillVersion) {
        do {
            _ = try draftService.snapshotVersion(for: skill, using: version.instructions, in: modelContext)
            instructionsText = version.instructions
            showToastMsg("Duplicated \(version.version) into a new latest draft")
        } catch {
            showToastMsg("Failed to duplicate version: \(error.localizedDescription)")
        }
    }

    private func copySkillMarkdown() {
        NSPasteboard.general.clearContents()
        let markdown = draftService.exportMarkdown(for: skill)
        let didCopy = NSPasteboard.general.setString(markdown, forType: .string)
        showToastMsg(didCopy ? "Copied SKILL.md" : "Failed to copy SKILL.md", alertType: didCopy ? .complete(.green) : .error(.red))
    }

    private func installDraft() {
        isInstalling = true
        let agents = selectedAgents.isEmpty ? AgentWorkflow.defaultTargets : Array(selectedAgents).sorted { $0.rawValue < $1.rawValue }

        Task {
            do {
                try await draftService.installDraft(skill, scope: installScope, targetAgents: agents, in: modelContext)
                isInstalling = false
                showToastMsg("Installed \(skill.displayName)", alertType: .complete(.green))
            } catch {
                isInstalling = false
                showToastMsg("Failed to install draft: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func showToastMsg(_ message: String, alertType: AlertToast.AlertType = .error(.red)) {
        toastTitle = message
        toastType = alertType
        showToast = true
    }
}
