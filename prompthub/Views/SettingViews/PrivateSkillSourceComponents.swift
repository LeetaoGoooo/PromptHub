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
                .foregroundStyle(source.type == .githubPrivate ? PH.Color.accent : PH.Color.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(source.label).font(PH.Font.rowName)
                Text(source.location).font(PH.Font.mono).foregroundStyle(PH.Color.secondary).lineLimit(1)
                if !source.notes.isEmpty { Text(source.notes).font(PH.Font.rowSub).foregroundStyle(PH.Color.secondary).lineLimit(1) }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                SettingsTag(text: source.type.displayName, tint: PH.Color.secondary)
                if source.type == .githubPrivate {
                    HStack(spacing: 4) {
                        Image(systemName: hasToken ? "key.fill" : "key.slash").font(.caption2)
                        Text(hasToken ? "Token set" : "No token").font(.caption2)
                    }
                    .foregroundStyle(hasToken ? PH.Color.statusOK : PH.Color.statusWarn)
                }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(PH.Color.buttonBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PH.Color.buttonBorder, lineWidth: 1)
        )
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditing ? "Edit Private Source" : "Add Private Source")
                        .font(PH.Font.paneTitle)
                        .foregroundStyle(PH.Color.primary)
                    Text("GitHub repos and local folders use the same data model.")
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.secondary)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
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
                .buttonStyle(PHChromeButtonStyle(emphasis: .accent)).disabled(!isValid).keyboardShortcut(.return)
            }
            .padding(20)
            .background(PH.Color.windowBg)
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
        .background(PH.Color.windowBg)
        .frame(width: 480, height: 520)
        .onAppear {
            if let s = source { label = s.label; type = s.type; location = s.location; notes = s.notes }
        }
    }

    private var typePickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsFieldLabel("Source Type")
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
            SettingsFieldLabel("Label")
            TextField("My Private Skills", text: $label).textFieldStyle(.roundedBorder)
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsFieldLabel(type == .githubPrivate ? "Repository" : "Local Path")
            if type == .githubPrivate {
                TextField("myorg/private-skills", text: $location).textFieldStyle(.roundedBorder)
                Text("Format: owner/repo. Do not include the https:// prefix.")
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.secondary)
            } else {
                HStack {
                    TextField("/Volumes/teamshare/skills", text: $location).textFieldStyle(.roundedBorder)
                    Button("Browse…") {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false
                        if panel.runModal() == .OK, let url = panel.url { location = url.path }
                    }.buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                }
                Text("Use an absolute path to the shared skills directory.")
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.secondary)
            }
        }
    }

    private var tokenSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsFieldLabel("GitHub Personal Access Token")
            HStack {
                if showToken { TextField("ghp_…", text: $token).textFieldStyle(.roundedBorder).font(.system(.body, design: .monospaced)) }
                else { SecureField("ghp_…", text: $token).textFieldStyle(.roundedBorder) }
                Button(showToken ? "Hide" : "Show") { showToken.toggle() }
                    .buttonStyle(PHChromeButtonStyle(emphasis: .standard))
                    .controlSize(.small)
            }
            Text("Stored in the macOS Keychain. Needs repo scope for private repositories.")
                .font(PH.Font.rowSub)
                .foregroundStyle(PH.Color.secondary)
            if isEditing && token.isEmpty {
                Text("Leave blank to keep the existing token.")
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.statusWarn)
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsFieldLabel("Notes", caption: "Optional context for your team.")
            TextField("e.g. Internal engineering skills", text: $notes).textFieldStyle(.roundedBorder)
        }
    }
}
