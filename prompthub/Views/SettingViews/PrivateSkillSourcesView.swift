import SwiftUI
import PromptHubSkillKit

// MARK: - Private Sources Settings View

struct PrivateSkillSourcesView: View {
    @ObservedObject private var store = PrivateSkillSourceStore.shared
    @State private var showingAddSheet = false
    @State private var editingSource: PrivateSkillSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if store.sources.isEmpty {
                emptyState
            } else {
                sourcesList
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            PrivateSkillSourceEditSheet(source: nil) { newSource, token in
                store.add(newSource)
                if let token { store.saveToken(token, for: newSource.id) }
            }
        }
        .sheet(item: $editingSource) { source in
            PrivateSkillSourceEditSheet(source: source) { updated, token in
                store.update(updated)
                if let token { store.saveToken(token, for: updated.id) }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.rectangle.stack")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text("No Private Sources")
                .font(.headline)
            Text("Add a private GitHub repo or team-shared directory to install skills that aren't in the public registry.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Button("Add Private Source…") { showingAddSheet = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var sourcesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Private Skill Sources")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            VStack(spacing: 0) {
                ForEach(store.sources) { source in
                    PrivateSkillSourceRow(
                        source: source,
                        hasToken: store.hasToken(for: source.id)
                    )
                    .contextMenu {
                        Button("Edit…") { editingSource = source }
                        Divider()
                        Button("Delete", role: .destructive) { store.remove(id: source.id) }
                    }
                    .onTapGesture(count: 2) { editingSource = source }
                    if source.id != store.sources.last?.id {
                        Divider()
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Row

private struct PrivateSkillSourceRow: View {
    let source: PrivateSkillSource
    let hasToken: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.type.systemImage)
                .font(.system(size: 16))
                .foregroundStyle(source.type == .githubPrivate ? Color.purple : Color.blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(source.label)
                    .font(.callout.weight(.medium))
                Text(source.location)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !source.notes.isEmpty {
                    Text(source.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(source.type.displayName)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(Capsule())

                if source.type == .githubPrivate {
                    HStack(spacing: 4) {
                        Image(systemName: hasToken ? "key.fill" : "key.slash")
                            .font(.caption2)
                        Text(hasToken ? "Token set" : "No token")
                            .font(.caption2)
                    }
                    .foregroundStyle(hasToken ? Color.green : Color.orange)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Edit / Add Sheet

struct PrivateSkillSourceEditSheet: View {
    let source: PrivateSkillSource?
    let onSave: (PrivateSkillSource, String?) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var label = ""
    @State private var type = PrivateSkillSource.SourceType.githubPrivate
    @State private var location = ""
    @State private var notes = ""
    @State private var token = ""
    @State private var showToken = false

    private var isEditing: Bool { source != nil }
    private var isValid: Bool {
        !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(isEditing ? "Edit Private Source" : "Add Private Source")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button(isEditing ? "Save" : "Add") {
                    let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    let src = PrivateSkillSource(
                        id: source?.id ?? UUID().uuidString,
                        label: label.trimmingCharacters(in: .whitespacesAndNewlines),
                        type: type,
                        location: location.trimmingCharacters(in: .whitespacesAndNewlines),
                        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                        createdAt: source?.createdAt ?? Date()
                    )
                    onSave(src, trimmedToken.isEmpty ? nil : trimmedToken)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isValid)
                .keyboardShortcut(.return)
            }
            .padding(20)

            Divider()

            // Form
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Type picker
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Source Type")
                            .font(.subheadline.weight(.medium))
                        Picker("", selection: $type) {
                            ForEach(PrivateSkillSource.SourceType.allCases, id: \.self) { t in
                                Label(t.displayName, systemImage: t.systemImage).tag(t)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }

                    // Label
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Label")
                            .font(.subheadline.weight(.medium))
                        TextField("My Private Skills", text: $label)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Location
                    VStack(alignment: .leading, spacing: 6) {
                        Text(type == .githubPrivate ? "Repository (owner/repo)" : "Local Path")
                            .font(.subheadline.weight(.medium))
                        if type == .githubPrivate {
                            TextField("myorg/private-skills", text: $location)
                                .textFieldStyle(.roundedBorder)
                            Text("Format: owner/repo — no https:// prefix required.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            HStack {
                                TextField("/Volumes/teamshare/skills", text: $location)
                                    .textFieldStyle(.roundedBorder)
                                Button("Browse…") {
                                    let panel = NSOpenPanel()
                                    panel.canChooseDirectories = true
                                    panel.canChooseFiles = false
                                    if panel.runModal() == .OK, let url = panel.url {
                                        location = url.path
                                    }
                                }
                                .buttonStyle(.bordered)
                            }
                            Text("Absolute path to the shared skills directory (e.g. an NFS mount).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // GitHub token (only for private GitHub)
                    if type == .githubPrivate {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GitHub Personal Access Token")
                                .font(.subheadline.weight(.medium))
                            HStack {
                                if showToken {
                                    TextField("ghp_…", text: $token)
                                        .textFieldStyle(.roundedBorder)
                                        .font(.system(.body, design: .monospaced))
                                } else {
                                    SecureField("ghp_…", text: $token)
                                        .textFieldStyle(.roundedBorder)
                                }
                                Button(showToken ? "Hide" : "Show") {
                                    showToken.toggle()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            Text("Token is stored in the macOS Keychain. Needs repo scope to read private repos.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if isEditing && token.isEmpty {
                                Text("Leave blank to keep the existing token.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes (optional)")
                            .font(.subheadline.weight(.medium))
                        TextField("e.g. Internal engineering skills", text: $notes)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 520)
        .onAppear {
            if let s = source {
                label = s.label
                type = s.type
                location = s.location
                notes = s.notes
                // Don't pre-fill token — user must explicitly re-enter to update.
            }
        }
    }
}
