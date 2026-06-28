import AppKit
import AlertToast
import PromptHubSkillKit
import SwiftUI

// MARK: - Actions

extension SkillStoreView {

    func fetchSkills(query overrideQuery: String? = nil) {
        guard cliAccessManager.anyAccessGranted else { return }
        searchTask?.cancel()
        isLoading = true
        errorMessage = nil
        let query = overrideQuery ?? activeCatalogQuery
        let task = Task {
            do {
                workspaceSnapshot = try await workspaceService.loadSkillStore(
                    query: query, authoredDraftCount: skillDrafts.count
                )
                syncSelection()
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = workspaceService.userFacingErrorMessage(for: error)
            }
            guard !Task.isCancelled else { return }
            isLoading = false
        }
        searchTask = task
    }

    func handleSearchTextChange() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cliAccessManager.anyAccessGranted else { return }

        if query.isEmpty {
            fetchSkills(query: "")
            return
        }

        guard query.count >= 2 else {
            searchTask?.cancel()
            isLoading = false
            errorMessage = nil
            selectedSkillID = nil
            return
        }

        searchTask?.cancel()
        let task = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                fetchSkills(query: query)
            }
        }
        searchTask = task
    }

    func installSkill(_ skill: CatalogSkill, scope: SkillInstallScope, targetAgents: [AgentWorkflow]) {
        let wasInstalled = installationRegistry[skill.package.normalizedKey]?.isInstalled == true
        _ = withAnimation(.easeInOut(duration: 0.2)) { installingSkillIDs.insert(skill.id) }
        Task {
            do {
                let snapshot = try await workspaceService.installCatalogSkill(
                    skill, query: activeCatalogQuery, scope: scope, targetAgents: targetAgents,
                    authoredDraftCount: skillDrafts.count, existingSnapshot: workspaceSnapshot
                )
                workspaceSnapshot = snapshot
                syncSelection()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    installingSkillIDs.remove(skill.id)
                    recentlyInstalledIDs.insert(skill.id)
                }
                showToastMessage(
                    "\(wasInstalled ? "Updated" : "Installed") \(skill.displayName) in \(scope.displayName.lowercased())",
                    .complete(.green)
                )
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    _ = withAnimation(.easeOut(duration: 0.3)) { recentlyInstalledIDs.remove(skill.id) }
                }
            } catch {
                _ = withAnimation { installingSkillIDs.remove(skill.id) }
                errorMessage = "Failed to install \(skill.displayName): \(workspaceService.userFacingErrorMessage(for: error))"
            }
        }
    }

    func removeInstalledSkill(_ skill: CatalogSkill, scope: SkillInstallScope) {
        Task {
            do {
                let snapshot = try await workspaceService.removeCatalogSkill(
                    skill, query: activeCatalogQuery, scope: scope, installedSkills: installedSkills,
                    authoredDraftCount: skillDrafts.count, existingSnapshot: workspaceSnapshot
                )
                workspaceSnapshot = snapshot
                syncSelection()
                showToastMessage("Removed \(skill.displayName) from \(scope.displayName.lowercased())", .complete(.green))
            } catch {
                errorMessage = "Failed to remove \(skill.displayName): \(workspaceService.userFacingErrorMessage(for: error))"
            }
        }
    }

    func openSourcePage(for skill: CatalogSkill) {
        guard let urlString = skill.url, let url = URL(string: urlString) else {
            errorMessage = "Failed to open source page for \(skill.displayName)."
            return
        }
        NSWorkspace.shared.open(url)
    }

    func installLocalSkill(isGlobal: Bool) {
        guard !isInstallingLocalSkill else { return }
        if !isGlobal && workspaceService.selectedProjectRootURL == nil {
            chooseProjectRoot()
            guard workspaceService.selectedProjectRootURL != nil else { return }
        }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText]
        panel.message = "Select a local SKILL.md file or a skill directory"
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        isInstallingLocalSkill = true
        Task {
            defer { isInstallingLocalSkill = false }
            do {
                let snapshot = try await workspaceService.installLocalSkill(
                    at: selectedURL, query: activeCatalogQuery,
                    scope: isGlobal ? .global : .project,
                    targetAgents: AgentWorkflow.defaultTargets,
                    authoredDraftCount: skillDrafts.count,
                    existingSnapshot: workspaceSnapshot
                )
                workspaceSnapshot = snapshot
                syncSelection()
                showToastMessage(
                    "Imported local skill into \((isGlobal ? SkillInstallScope.global : .project).displayName.lowercased())",
                    .complete(.green)
                )
            } catch {
                errorMessage = "Failed to install local skill: \(workspaceService.userFacingErrorMessage(for: error))"
            }
        }
    }

    @MainActor
    func showToastMessage(_ message: String, _ type: AlertToast.AlertType) {
        toastMessage = message; toastType = type; showToast = true
    }

    func chooseProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true
        panel.prompt = "Select"
        panel.message = "Choose one or more project folders whose CLI skill roots should be used for project-scope installs."
        guard panel.runModal() == .OK else { return }
        let selectedURLs = panel.urls
        guard !selectedURLs.isEmpty else { return }
        workspaceService.addProjectRootURLs(selectedURLs, selecting: selectedURLs.last)
    }
}
