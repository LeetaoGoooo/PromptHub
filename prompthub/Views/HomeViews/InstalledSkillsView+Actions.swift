import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - Business Logic Actions

extension InstalledSkillsView {

    func fetchInstalledSkills() {
        agentVisibility = []
        sourceIntegrity = nil
        structuralQuality = nil
        isLoadingVisibility = true
        isLoadingIntegrity = true
        isLoadingStructuralQuality = true
        installedWorkspaceStore.refresh(
            authoredDraftCount: skillDrafts.count,
            hasCLIAccess: cliAccessManager.anyAccessGranted
        )
    }

    func removeSkill(_ skill: InstalledSkillSnapshot, targetAgents: [AgentWorkflow]? = nil) {
        guard allowsMutation(for: skill) else {
            installedWorkspaceStore.setError("Switch to Active Project before removing project-scoped skills.")
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            removingSkillIDs.insert(skill.id)
            installedWorkspaceStore.setError(nil)
        }
        Task {
            do {
                let snapshot = try await workspaceService.removeInstalledSkill(
                    skill, targetAgents: targetAgents, authoredDraftCount: skillDrafts.count
                )
                await MainActor.run {
                    installedWorkspaceStore.apply(snapshot: snapshot)
                    syncSelection()
                }
                _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    removingSkillIDs.remove(skill.id)
                }
            } catch {
                withAnimation {
                    removingSkillIDs.remove(skill.id)
                    installedWorkspaceStore.setError("Failed to remove \(skill.displayName): \(workspaceService.userFacingErrorMessage(for: error))")
                }
            }
        }
        pendingRemoval = nil
    }

    func addSkillTargets(_ skill: InstalledSkillSnapshot, agents: [AgentWorkflow]) {
        guard !agents.isEmpty else { return }
        guard allowsMutation(for: skill) else {
            installedWorkspaceStore.setError("Switch to Active Project before changing CLI targets for project-scoped skills.")
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            addingSkillIDs.insert(skill.id)
            installedWorkspaceStore.setError(nil)
        }
        Task {
            do {
                let snapshot = try await workspaceService.addInstalledSkillTargets(
                    skill, targetAgents: agents, authoredDraftCount: skillDrafts.count
                )
                await MainActor.run {
                    installedWorkspaceStore.apply(snapshot: snapshot)
                    syncSelection()
                }
                _ = withAnimation(.easeInOut(duration: 0.2)) { addingSkillIDs.remove(skill.id) }
            } catch {
                withAnimation {
                    addingSkillIDs.remove(skill.id)
                    installedWorkspaceStore.setError("Failed to update \(skill.displayName): \(workspaceService.userFacingErrorMessage(for: error))")
                }
            }
        }
    }

    func linkedDraft(for skill: InstalledSkillSnapshot) -> Skill? {
        draftService.matchingDraft(for: skill, in: skillDrafts)
    }

    func allowsMutation(for skill: InstalledSkillSnapshot) -> Bool {
        return true
    }

    func openDraft(for installedSkill: InstalledSkillSnapshot) {
        installedWorkspaceStore.setError(nil)
        openingDraftForSkillID = installedSkill.id
        Task {
            do {
                let draft = try await draftService.openOrCreateDraft(
                    from: installedSkill,
                    existingDrafts: skillDrafts,
                    in: modelContext,
                    projectRootURL: installedSkill.isGlobal ? nil : workspaceService.selectedProjectRootURL
                )
                await MainActor.run {
                    editingInstalledSkillID = installedSkill.id
                    editingDraftSheet = draft
                    openingDraftForSkillID = nil
                }
            } catch {
                await MainActor.run {
                    openingDraftForSkillID = nil
                    installedWorkspaceStore.setError(draftServiceErrorMessage(for: error, skill: installedSkill))
                }
            }
        }
    }

    func syncSelection() {
        guard !filteredSkills.isEmpty else {
            return
        }

        if !filteredSkills.contains(where: { $0.id == selectedSkillID }) {
            selectedSkillID = filteredSkills.first?.id
        }
    }

    func chooseProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Select"
        panel.message = "Choose one or more project folders whose CLI skill roots should be managed."
        guard panel.runModal() == .OK else { return }
        let selectedURLs = panel.urls
        guard !selectedURLs.isEmpty else { return }
        workspaceService.addProjectRootURLs(selectedURLs, selecting: selectedURLs.last)
    }

    func removalMessage(for pending: PendingRemoval) -> String {
        let targetText: String
        if let agents = pending.targetAgents, let first = agents.first {
            targetText = " from \(first.displayName)"
        } else {
            targetText = ""
        }
        return "Are you sure you want to remove \"\(pending.skill.displayName)\"\(targetText)? This will uninstall it from your \(pending.skill.isGlobal ? "global" : "project") configuration."
    }

    func draftServiceErrorMessage(for error: Error, skill: InstalledSkillSnapshot) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return "Failed to open \(skill.displayName) as a draft: \(localized)"
        }
        return "Failed to open \(skill.displayName) as a draft."
    }

    /// Checks all remote-backed installed skills for available updates in parallel.
    func checkAllUpdates() {
        let remoteSkills = installedSkills.filter { $0.package.remoteInstallDescriptor != nil }
        guard !remoteSkills.isEmpty else { return }
        isCheckingUpdates = true
        selectedUpdateSkillIDs.removeAll()
        Task {
            await withTaskGroup(of: (String, Bool).self) { group in
                for skill in remoteSkills {
                    group.addTask {
                        let preview = await self.workspaceService.previewUpdate(for: skill)
                        return (skill.id, preview.status == .updateAvailable)
                    }
                }
                var updates: Set<String> = []
                for await (id, hasUpdate) in group {
                    if hasUpdate { updates.insert(id) }
                }
                skillsWithUpdates = updates
            }
            isCheckingUpdates = false
        }
    }

    var updateEligibleSkills: [InstalledSkillSnapshot] {
        filteredSkills.filter { skillsWithUpdates.contains($0.id) }
    }

    var updateSelectionActive: Bool {
        !skillsWithUpdates.isEmpty
    }

    func toggleUpdateSelection(for skill: InstalledSkillSnapshot) {
        guard skillsWithUpdates.contains(skill.id) else { return }
        if selectedUpdateSkillIDs.contains(skill.id) {
            selectedUpdateSkillIDs.remove(skill.id)
        } else {
            selectedUpdateSkillIDs.insert(skill.id)
        }
    }

    func clearUpdateSelection() {
        selectedUpdateSkillIDs.removeAll()
    }

    func selectAllVisibleUpdates() {
        selectedUpdateSkillIDs = Set(updateEligibleSkills.map(\.id))
    }

    func applyUpdates(for skills: [InstalledSkillSnapshot]) {
        let queuedSkills = skills.filter { skillsWithUpdates.contains($0.id) }
        guard !queuedSkills.isEmpty else { return }

        isApplyingBulkUpdates = true
        installedWorkspaceStore.setError(nil)

        Task {
            var failedNames: [String] = []

            for skill in queuedSkills {
                _ = await MainActor.run { updatingSkillIDs.insert(skill.id) }
                let preview = await workspaceService.previewUpdate(for: skill)

                guard preview.status == .updateAvailable else {
                    await MainActor.run {
                        updatingSkillIDs.remove(skill.id)
                        skillsWithUpdates.remove(skill.id)
                        selectedUpdateSkillIDs.remove(skill.id)
                    }
                    continue
                }

                do {
                    try await workspaceService.applyUpdate(preview: preview)
                    NotificationCenter.default.post(name: .skillInstallationsDidChange, object: nil)
                    await MainActor.run {
                        updatingSkillIDs.remove(skill.id)
                        skillsWithUpdates.remove(skill.id)
                        selectedUpdateSkillIDs.remove(skill.id)
                    }
                } catch {
                    failedNames.append(skill.displayName)
                    _ = await MainActor.run {
                        updatingSkillIDs.remove(skill.id)
                    }
                }
            }

            await MainActor.run {
                isApplyingBulkUpdates = false
                if failedNames.isEmpty {
                    fetchInstalledSkills()
                } else {
                    installedWorkspaceStore.setError("Failed to update \(failedNames.joined(separator: ", ")).")
                    fetchInstalledSkills()
                }
            }
        }
    }
}
