import SwiftUI
import PromptHubSkillKit

/// Sheet presented from the Skill Store "Import → Install from Private Source…" button.
/// Lists all configured private sources, lets the user pick one, select skills, scope, and agents.
struct PrivateSourceInstallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = PrivateSkillSourceStore.shared
    private let cliService = SkillCLIService.shared
    private let workspaceService = SkillWorkspaceService.shared

    @State private var selectedSourceID: String?
    @State private var availableSkillNames: [String] = []
    @State private var selectedSkillNames: Set<String> = []
    @State private var isGlobal = true
    @State private var targetAgents = Set(AgentWorkflow.defaultTargets)
    @State private var isLoadingSkillList = false
    @State private var isInstalling = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    private var selectedSource: PrivateSkillSource? {
        store.sources.first { $0.id == selectedSourceID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Install from Private Source")
                        .font(.headline)
                    Text("Select a configured private source and choose which skills to install.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.escape)
            }
            .padding(20)

            Divider()

            if store.sources.isEmpty {
                noSourcesState
            } else {
                mainContent
            }
        }
        .frame(width: 560, height: 560)
        .onChange(of: selectedSourceID) { _, _ in
            loadSkillsForSelectedSource()
        }
    }

    private var noSourcesState: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.rectangle.stack")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No Private Sources Configured")
                .font(.headline)
            Text("Add private sources in Settings → Private Sources.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Open Settings") {
                // Post notification that main window can observe to open settings
                NotificationCenter.default.post(name: .openPrivateSourcesSettings, object: nil)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Source picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Source")
                            .font(.subheadline.weight(.semibold))
                        VStack(spacing: 0) {
                            ForEach(store.sources) { source in
                                HStack(spacing: 12) {
                                    Image(systemName: source.type.systemImage)
                                        .foregroundStyle(source.type == .githubPrivate ? Color.purple : Color.blue)
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(source.label)
                                            .font(.callout.weight(.medium))
                                        Text(source.location)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if selectedSourceID == source.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(selectedSourceID == source.id ? Color.blue.opacity(0.08) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                                .contentShape(Rectangle())
                                .onTapGesture { selectedSourceID = source.id }
                                if source.id != store.sources.last?.id { Divider() }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
                    }

                    // Skill selection
                    if let source = selectedSource {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Skills in \(source.label)")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                if isLoadingSkillList {
                                    ProgressView().controlSize(.mini)
                                } else if !availableSkillNames.isEmpty {
                                    Button(selectedSkillNames.count == availableSkillNames.count ? "Deselect All" : "Select All") {
                                        if selectedSkillNames.count == availableSkillNames.count {
                                            selectedSkillNames = []
                                        } else {
                                            selectedSkillNames = Set(availableSkillNames)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                }
                            }
                            if availableSkillNames.isEmpty && !isLoadingSkillList {
                                Text(source.type == .localShared
                                     ? "No SKILL.md folders found at the configured path."
                                     : "Could not enumerate skills — check the repo name and token.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                VStack(spacing: 0) {
                                    ForEach(availableSkillNames, id: \.self) { name in
                                        Toggle(name, isOn: Binding(
                                            get: { selectedSkillNames.contains(name) },
                                            set: { checked in
                                                if checked { selectedSkillNames.insert(name) }
                                                else { selectedSkillNames.remove(name) }
                                            }
                                        ))
                                        .toggleStyle(.checkbox)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                                        if name != availableSkillNames.last { Divider() }
                                    }
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
                            }
                        }

                        // Scope
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Scope")
                                .font(.subheadline.weight(.semibold))
                            Picker("", selection: $isGlobal) {
                                Text("Global").tag(true)
                                Text("Project").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }

                    if let err = errorMessage {
                        Label(err, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                    if let suc = successMessage {
                        Label(suc, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                    Text("Installing…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Install Selected") {
                    Task { await installSelectedSkills() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedSkillNames.isEmpty || selectedSource == nil || isInstalling)
            }
            .padding(16)
        }
    }

    private func loadSkillsForSelectedSource() {
        guard let source = selectedSource else { availableSkillNames = []; return }
        selectedSkillNames = []
        availableSkillNames = []

        if source.type == .localShared {
            availableSkillNames = cliService.listSkillsInSharedPath(source.location)
        } else {
            // For GitHub private repos we can't easily enumerate without a Tree API call;
            // show a text field approach — leave empty and let user type skill name(s).
            // For now, show a placeholder indicating manual entry.
            availableSkillNames = []
        }
    }

    private func installSelectedSkills() async {
        guard let source = selectedSource, !selectedSkillNames.isEmpty else { return }
        isInstalling = true
        errorMessage = nil
        successMessage = nil

        do {
            try await cliService.installFromPrivateSource(
                source: source,
                skillNames: Array(selectedSkillNames).sorted(),
                isGlobal: isGlobal,
                targetAgents: Array(targetAgents),
                projectRootURL: workspaceService.selectedProjectRootURL
            )
            NotificationCenter.default.post(name: .skillInstallationsDidChange, object: nil)
            successMessage = "Installed \(selectedSkillNames.count) skill(s) successfully."
            selectedSkillNames = []
        } catch {
            errorMessage = cliService.userFacingErrorMessage(for: error)
        }
        isInstalling = false
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openPrivateSourcesSettings = Notification.Name("openPrivateSourcesSettings")
}
