import AlertToast
import SwiftUI

// MARK: - Sub Views

extension PromptDetail {

    @ViewBuilder
    var promptHeader: some View {
        SkillLibraryInspectorCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    TextField("Prompt Name", text: $prompt.name)
                        .textFieldStyle(.plain)
                        .font(.system(size: 28, weight: .bold))
                        .focused($focusedField, equals: .name)
                        .padding(.horizontal, -4)
                    Spacer()
                    if let latestHistory = history.first {
                        Text("v\(max(latestHistory.version, 1))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                TextField("Add a description...", text: Binding(
                    get: { prompt.desc ?? "" },
                    set: { prompt.desc = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, -4)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    @ViewBuilder
    var promptActionCard: some View {
        SkillLibraryInspectorCard(title: "Actions") {
            HStack(spacing: 8) {
                headerActions
                Spacer()
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    var headerActions: some View {
        HStack(spacing: 8) {
            Button { isShowingSingleTestView.toggle() } label: { Label("Test", systemImage: "play.fill") }
                .buttonStyle(.bordered).controlSize(.small).help("Test this prompt")

            Button { isShowingDiff.toggle() } label: { Label("Diff", systemImage: "clock.arrow.circlepath") }
                .buttonStyle(.bordered).controlSize(.small).help("Toggle Diff View")

            Button(action: promotePromptToSkill) {
                Label("Promote to Skill", systemImage: "wand.and.stars.inverse")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Promote this prompt into a skill draft")

            Button {
                Task { await shareCreation() }
            } label: {
                Label(existingSharedCreation == nil ? "Share" : "Copy Share Link", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isCreateShareLink)
            .help("Share")

            Button(role: .destructive) {
                showingDeletePromptConfirmation = true
            } label: {
                Label(isEphemeralDraft ? "Discard" : "Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(isEphemeralDraft ? "Discard this empty prompt draft" : "Delete this prompt")
        }
    }

    @ViewBuilder
    func promptInfoCard(latestHistory: PromptHistory) -> some View {
        SkillLibraryInspectorCard(title: "Information") {
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Version", value: "v\(max(latestHistory.version, 1))")
                LabeledContent("Created", value: latestHistory.createdAt, format: .dateTime)
                LabeledContent("Updated", value: latestHistory.updatedAt, format: .dateTime)
                LabeledContent("Link", value: prompt.link?.isEmpty == false ? "Attached" : "None")
                LabeledContent("External Sources", value: (prompt.externalSources?.isEmpty ?? true) ? "None" : "Attached")
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    var promptSharingCard: some View {
        SkillLibraryInspectorCard(title: "Sharing") {
            if let shared = existingSharedCreation {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shared.isPublic ? "Visible to community" : "Private link only")
                                .font(.headline)
                            Text("Reuse the current share record or switch its visibility.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { shared.isPublic },
                            set: { _ in Task { await togglePublicStatus() } }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(isTogglingPublic)
                    }

                    HStack(spacing: 8) {
                        Button {
                            Task { await shareCreation() }
                        } label: {
                            Label("Copy Share Link", systemImage: "link")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isCreateShareLink)

                        if isTogglingPublic {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Not shared yet")
                        .font(.headline)
                    Text("Create a share link for this prompt without leaving the editor.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await shareCreation() }
                    } label: {
                        Label("Share to Community", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreateShareLink)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    var promptHistoryCard: some View {
        SkillLibraryInspectorCard(title: "History") {
            if history.isEmpty {
                Text("No history yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(history) { item in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Version \(item.version)")
                                    .font(.headline)
                                Text(item.updatedAt, formatter: dateFormatter)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                selectedHistoryVersion = item
                            } label: {
                                Label("Preview", systemImage: "eye")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button {
                                let copied = copyPromptToClipboard(item.promptText)
                                showToastMsg(
                                    msg: copied ? "Copied version \(item.version)" : "Failed to copy version \(item.version)",
                                    alertType: copied ? .complete(Color.green) : .error(Color.red)
                                )
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(.horizontal, 24)
    }

    func versionDetailSheet(_ version: PromptHistory) -> some View {
        let isCurrentVersion = history.first?.id == version.id

        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version \(version.version)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(isCurrentVersion ? "Current editor version" : "Read-only history preview")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Dismiss") { selectedHistoryVersion = nil }
                    .buttonStyle(.bordered)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Created: \(version.createdAt, formatter: dateFormatter)").font(.subheadline)
                Text("Updated: \(version.updatedAt, formatter: dateFormatter)").font(.subheadline)
            }
            Text("Prompt Content").font(.headline)
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
                    let copied = copyPromptToClipboard(version.promptText)
                    showToastMsg(
                        msg: copied ? "Copied version \(version.version)" : "Failed to copy version \(version.version)",
                        alertType: copied ? .complete(Color.green) : .error(Color.red)
                    )
                } label: {
                    Label("Copy Content", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                Button {
                    applyHistoryVersionToEditor(version)
                } label: {
                    Label(isCurrentVersion ? "Already Current" : "Apply to Editor", systemImage: isCurrentVersion ? "checkmark.circle" : "arrow.down.doc")
                }
                .disabled(isCurrentVersion)
                .modifier(HistoryApplyButtonStyle(isCurrentVersion: isCurrentVersion))
                .help(isCurrentVersion ? "This version is already current" : "Create a new current version from this history entry")
                Spacer()
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}

private struct HistoryApplyButtonStyle: ViewModifier {
    let isCurrentVersion: Bool

    func body(content: Content) -> some View {
        if isCurrentVersion {
            content.buttonStyle(.bordered)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
