import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - Card Sub Views

extension SkillDraftDetailView {

    var metadataCard: some View {
        section(title: "Metadata", subtitle: "Edit the draft fields that become skill metadata and library labels.") {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Skill Name", text: $skill.name)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: skill.name) { skill.slug = Skill.makeSlug(from: skill.name); saveDraftMetadata() }

                TextField("Description", text: descriptionBinding, axis: .vertical)
                    .lineLimit(2...4).textFieldStyle(.roundedBorder)
                    .onChange(of: descriptionBinding.wrappedValue) { saveDraftMetadata() }

                HStack(spacing: 12) {
                    TextField("Slug", text: $skill.slug).textFieldStyle(.roundedBorder)
                        .onChange(of: skill.slug) { skill.slug = Skill.makeSlug(from: skill.slug); saveDraftMetadata() }
                    TextField("Identifier", text: $skill.identifier).textFieldStyle(.roundedBorder)
                        .onChange(of: skill.identifier) { saveDraftMetadata() }
                }
                HStack(spacing: 12) {
                    TextField("Category", text: $skill.category).textFieldStyle(.roundedBorder)
                        .onChange(of: skill.category) { saveDraftMetadata() }
                    TextField("Tags (comma separated)", text: $tagText).textFieldStyle(.roundedBorder)
                        .onChange(of: tagText) {
                            skill.tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                            saveDraftMetadata()
                        }
                }
                HStack(spacing: 12) {
                    TextField("Input Schema", text: inputSchemaBinding, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                        .onChange(of: inputSchemaBinding.wrappedValue) { saveDraftMetadata() }
                    TextField("Output Schema", text: outputSchemaBinding, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                        .onChange(of: outputSchemaBinding.wrappedValue) { saveDraftMetadata() }
                }
                TextField("Safety Policy", text: safetyPolicyBinding, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                    .onChange(of: safetyPolicyBinding.wrappedValue) { saveDraftMetadata() }
            }
        }
    }

    var instructionsCard: some View {
        section(title: "Instructions", subtitle: "These instructions are exported as the body of SKILL.md and installed into target agents.") {
            TextEditor(text: $instructionsText)
                .font(.system(.body, design: .monospaced)).frame(minHeight: 280).padding(12)
                .background(Color(NSColor.textBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 10))
                .onChange(of: instructionsText) { saveInstructions() }
        }
    }

    var installCard: some View {
        section(title: "Quick Actions", subtitle: "Install the current draft directly into your configured agent skills directory.") {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Scope", selection: $installScope) {
                    Text("Project").tag(SkillInstallScope.project)
                    Text("Global").tag(SkillInstallScope.global)
                }.pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Agents").font(.subheadline.weight(.medium))
                    ForEach(AgentWorkflow.allCases, id: \.rawValue) { agent in
                        Toggle(agent.displayName, isOn: Binding(
                            get: { selectedAgents.contains(agent) },
                            set: { if $0 { selectedAgents.insert(agent) } else { selectedAgents.remove(agent) } }
                        )).toggleStyle(.checkbox)
                    }
                }
                HStack {
                    Button(action: installDraft) {
                        if isInstalling { ProgressView().controlSize(.small) }
                        else { Label("Install Current Draft", systemImage: "arrow.down.circle") }
                    }.disabled(isInstalling)
                    if let lastInstalledAt = skill.lastInstalledAt {
                        Text("Last installed \(lastInstalledAt.formatted(date: .abbreviated, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    var versionsCard: some View {
        section(title: "Version History", subtitle: "Version snapshots let you keep stable points while continuing to edit the draft.") {
            if skill.sortedVersions.isEmpty {
                Text("No saved versions yet.").foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(skill.sortedVersions) { version in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(version.version).font(.subheadline.monospaced().weight(.semibold))
                                Text(version.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Duplicate Into Latest") { duplicateVersion(version) }
                        }
                        Text(version.instructions).font(.caption).foregroundStyle(.secondary).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                        if version.id != skill.sortedVersions.last?.id { Divider() }
                    }
                }
            }
        }
    }

    var markdownPreviewCard: some View {
        section(title: "SKILL.md Preview", subtitle: "This is the markdown that will be copied or installed.") {
            ScrollView([.horizontal, .vertical]) {
                Text(draftService.exportMarkdown(for: skill))
                    .font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 220, idealHeight: 280, maxHeight: 340)
            .padding(12)
            .background(Color(NSColor.textBackgroundColor).opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Helper bindings

    var descriptionBinding: Binding<String> { Binding(get: { skill.desc ?? "" }, set: { skill.desc = $0.isEmpty ? nil : $0 }) }
    var inputSchemaBinding: Binding<String>  { Binding(get: { skill.inputSchema ?? "" }, set: { skill.inputSchema = $0.isEmpty ? nil : $0 }) }
    var outputSchemaBinding: Binding<String> { Binding(get: { skill.outputSchema ?? "" }, set: { skill.outputSchema = $0.isEmpty ? nil : $0 }) }
    var safetyPolicyBinding: Binding<String> { Binding(get: { skill.safetyPolicy ?? "" }, set: { skill.safetyPolicy = $0.isEmpty ? nil : $0 }) }

    func section<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
