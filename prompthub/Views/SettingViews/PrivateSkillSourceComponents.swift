import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - Row

struct PrivateSkillSourceRow: View {
    let source: PrivateSkillSource
    let hasToken: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: source.type.systemImage)
                .font(.system(size: 16))
                .foregroundStyle(source.type == .githubPrivate ? Color.purple : Color.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.label).font(.callout.weight(.medium))
                Text(source.location).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(1)
                if !source.notes.isEmpty { Text(source.notes).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(source.type.displayName).font(.caption2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color(NSColor.controlBackgroundColor)).clipShape(Capsule())
                if source.type == .githubPrivate {
                    HStack(spacing: 4) {
                        Image(systemName: hasToken ? "key.fill" : "key.slash").font(.caption2)
                        Text(hasToken ? "Token set" : "No token").font(.caption2)
                    }
                    .foregroundStyle(hasToken ? Color.green : Color.orange)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
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
            HStack {
                Text(isEditing ? "Edit Private Source" : "Add Private Source").font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.escape)
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
                .buttonStyle(.borderedProminent).disabled(!isValid).keyboardShortcut(.return)
            }
            .padding(20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    typePickerSection
                    labelSection
                    locationSection
                    if type == .githubPrivate { tokenSection }
                    notesSection
                }
                .padding(20)
            }
        }
        .frame(width: 480, height: 520)
        .onAppear {
            if let s = source { label = s.label; type = s.type; location = s.location; notes = s.notes }
        }
    }

    private var typePickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Source Type").font(.subheadline.weight(.medium))
            Picker("", selection: $type) {
                ForEach(PrivateSkillSource.SourceType.allCases, id: \.self) { t in
                    Label(t.displayName, systemImage: t.systemImage).tag(t)
                }
            }
            .pickerStyle(.segmented).labelsHidden()
        }
    }

    private var labelSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Label").font(.subheadline.weight(.medium))
            TextField("My Private Skills", text: $label).textFieldStyle(.roundedBorder)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(type == .githubPrivate ? "Repository (owner/repo)" : "Local Path").font(.subheadline.weight(.medium))
            if type == .githubPrivate {
                TextField("myorg/private-skills", text: $location).textFieldStyle(.roundedBorder)
                Text("Format: owner/repo — no https:// prefix required.").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    TextField("/Volumes/teamshare/skills", text: $location).textFieldStyle(.roundedBorder)
                    Button("Browse…") {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url { location = url.path }
                    }.buttonStyle(.bordered)
                }
                Text("Absolute path to the shared skills directory (e.g. an NFS mount).").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GitHub Personal Access Token").font(.subheadline.weight(.medium))
            HStack {
                if showToken { TextField("ghp_…", text: $token).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)) }
                else { SecureField("ghp_…", text: $token).textFieldStyle(.roundedBorder) }
                Button(showToken ? "Hide" : "Show") { showToken.toggle() }.buttonStyle(.bordered).controlSize(.small)
            }
            Text("Token is stored in the macOS Keychain. Needs repo scope to read private repos.").font(.caption).foregroundStyle(.secondary)
            if isEditing && token.isEmpty { Text("Leave blank to keep the existing token.").font(.caption).foregroundStyle(.orange) }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Notes (optional)").font(.subheadline.weight(.medium))
            TextField("e.g. Internal engineering skills", text: $notes).textFieldStyle(.roundedBorder)
        }
    }
}
