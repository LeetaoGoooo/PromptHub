import PromptHubSkillKit
import SwiftUI

/// Sheet for quickly installing one or more skills from a GitHub repository.
/// The user pastes a GitHub URL or `owner/repo/skill-name` path and hits Install.
struct GitHubRepoInstallSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let cliService = SkillCLIService.shared
    private let workspaceService = SkillWorkspaceService.shared

    @State private var repoInput = ""
    @State private var isGlobal = true
    @State private var isInstalling = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                formContent
                    .padding(20)
            }
            Divider()
            footer
        }
        .frame(width: 480, height: 320)
    }

    // MARK: - Sub-views

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Install from GitHub")
                    .font(.headline)
                Text("Paste a GitHub URL or enter owner/repo/skill-name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Close") { dismiss() }
                .keyboardShortcut(.escape)
        }
        .padding(20)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Repository / Skill Path")
                    .font(.subheadline.weight(.semibold))
                TextField(
                    "e.g. https://github.com/owner/repo/skill-name or owner/repo/skill-name",
                    text: $repoInput
                )
                .textFieldStyle(.roundedBorder)
                .disableAutocorrection(true)

                Text("Supports: full GitHub URL, owner/repo/skill-name, or owner/repo (installs all skills in that repo).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Scope")
                    .font(.subheadline.weight(.semibold))
                Picker("", selection: $isGlobal) {
                    Text("Global").tag(true)
                    Text("Project").tag(false)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
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
    }

    private var footer: some View {
        HStack {
            if isInstalling {
                ProgressView().controlSize(.small)
                Text("Installing…").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Install") {
                Task { await performInstall() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(repoInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isInstalling)
        }
        .padding(16)
    }

    // MARK: - Logic

    /// Normalises user input to a `(source, skillNames)` pair.
    /// Accepts:
    ///   - `https://github.com/owner/repo/skill-name`  → source=owner/repo, skills=[skill-name]
    ///   - `https://github.com/owner/repo`             → source=owner/repo, skills=[]
    ///   - `github.com/owner/repo/skill`               → same as above
    ///   - `owner/repo/skill-name`                      → source=owner/repo, skills=[skill-name]
    ///   - `owner/repo`                                 → source=owner/repo, skills=[]
    private func parseInput(_ raw: String) -> (source: String, skillNames: [String])? {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip URL scheme and host
        for prefix in ["https://github.com/", "http://github.com/", "github.com/"] {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }

        // Strip trailing slash
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        let parts = cleaned.split(separator: "/", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return nil }

        let source = "\(parts[0])/\(parts[1])"
        let skillNames: [String] = parts.count >= 3 ? [parts[2]] : []
        return (source, skillNames)
    }

    private func performInstall() async {
        errorMessage = nil
        successMessage = nil
        isInstalling = true

        guard let (source, skillNames) = parseInput(repoInput) else {
            errorMessage = "Invalid input. Use owner/repo or owner/repo/skill-name format."
            isInstalling = false
            return
        }

        do {
            try await cliService.addSkills(
                source: source,
                skillNames: skillNames,
                isGlobal: isGlobal,
                projectRootURL: workspaceService.selectedProjectRootURL
            )
            NotificationCenter.default.post(name: .skillInstallationsDidChange, object: nil)
            let label = skillNames.isEmpty ? "all skills from \(source)" : skillNames.joined(separator: ", ")
            successMessage = "Installed \(label) successfully."
            repoInput = ""
        } catch {
            errorMessage = cliService.userFacingErrorMessage(for: error)
        }

        isInstalling = false
    }
}
