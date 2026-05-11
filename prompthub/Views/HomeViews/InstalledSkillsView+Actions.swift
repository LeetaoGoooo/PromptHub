import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - Business Logic Actions

extension InstalledSkillsView {

    func fetchInstalledSkills() {
        guard cliAccessManager.anyAccessGranted else { return }
        fetchTask?.cancel()
        isLoading = true
        agentVisibility = []
        sourceIntegrity = nil
        isLoadingVisibility = true
        isLoadingIntegrity = true
        errorMessage = nil
        fetchTask = Task {
            do {
                let snapshot = try await workspaceService.loadInstalledWorkspace(
                    authoredDraftCount: skillDrafts.count
                )
                guard !Task.isCancelled else { return }
                workspaceSnapshot = snapshot
                syncSelection()
                isLoading = false
                if let skill = selectedSkill {
                    async let visTask = workspaceService.auditAgentVisibility(for: skill)
                    async let intTask = workspaceService.auditSourceIntegrity(for: skill)
                    let vis = await visTask
                    guard !Task.isCancelled else { return }
                    agentVisibility = vis
                    isLoadingVisibility = false
                    let int = await intTask
                    guard !Task.isCancelled else { return }
                    sourceIntegrity = int
                    isLoadingIntegrity = false
                } else {
                    isLoadingVisibility = false
                    isLoadingIntegrity = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                errorMessage = workspaceService.userFacingErrorMessage(for: error)
                isLoading = false
                isLoadingVisibility = false
                isLoadingIntegrity = false
            }
        }
    }

    func removeSkill(_ skill: InstalledSkillSnapshot, targetAgents: [AgentWorkflow]? = nil) {
        withAnimation(.easeInOut(duration: 0.2)) {
            removingSkillIDs.insert(skill.id)
            errorMessage = nil
        }
        Task {
            do {
                workspaceSnapshot = try await workspaceService.removeInstalledSkill(
                    skill, targetAgents: targetAgents, authoredDraftCount: skillDrafts.count
                )
                syncSelection()
                _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    removingSkillIDs.remove(skill.id)
                }
            } catch {
                withAnimation {
                    removingSkillIDs.remove(skill.id)
                    errorMessage = "Failed to remove \(skill.displayName): \(workspaceService.userFacingErrorMessage(for: error))"
                }
            }
        }
        pendingRemoval = nil
    }

    func addSkillTargets(_ skill: InstalledSkillSnapshot, agents: [AgentWorkflow]) {
        guard !agents.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            addingSkillIDs.insert(skill.id)
            errorMessage = nil
        }
        Task {
            do {
                workspaceSnapshot = try await workspaceService.addInstalledSkillTargets(
                    skill, targetAgents: agents, authoredDraftCount: skillDrafts.count
                )
                syncSelection()
                _ = withAnimation(.easeInOut(duration: 0.2)) { addingSkillIDs.remove(skill.id) }
            } catch {
                withAnimation {
                    addingSkillIDs.remove(skill.id)
                    errorMessage = "Failed to update \(skill.displayName): \(workspaceService.userFacingErrorMessage(for: error))"
                }
            }
        }
    }

    func linkedDraft(for skill: InstalledSkillSnapshot) -> Skill? {
        draftService.matchingDraft(for: skill, in: skillDrafts)
    }

    func openDraft(for installedSkill: InstalledSkillSnapshot) {
        errorMessage = nil
        Task {
            do {
                let draft = try await draftService.openOrCreateDraft(
                    from: installedSkill,
                    existingDrafts: skillDrafts,
                    in: modelContext,
                    projectRootURL: installedSkill.isGlobal ? nil : workspaceService.selectedProjectRootURL
                )
                onSelectSkillDraft(draft)
            } catch {
                errorMessage = draftServiceErrorMessage(for: error, skill: installedSkill)
            }
        }
    }

    func syncSelection() {
        if !filteredSkills.contains(where: { $0.id == selectedSkillID }) {
            selectedSkillID = filteredSkills.first?.id
        }
    }

    func chooseProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the project folder whose CLI skill roots should be managed."
        guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
        workspaceService.setSelectedProjectRootURL(selectedURL)
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
}
