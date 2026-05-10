import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - View Builders

extension SkillStoreView {

    @ViewBuilder
    var accessoryBar: some View {
        HStack(spacing: 10) {
            if isInstallingLocalSkill { ProgressView().controlSize(.small) }

            Button { fetchSkills(query: searchText) }
            label: { Label("Refresh", systemImage: "arrow.clockwise") }
            .buttonStyle(.bordered)

            Menu {
                Button { chooseProjectRoot() }
                label: { Label("Choose Project…", systemImage: "folder") }

                if workspaceService.selectedProjectRootURL != nil {
                    Button(role: .destructive) { workspaceService.setSelectedProjectRootURL(nil) }
                    label: { Label("Clear Project", systemImage: "xmark.circle") }
                }
            } label: {
                Label(workspaceService.selectedProjectDisplayName, systemImage: "folder")
            }
            .menuStyle(.borderedButton)

            Menu {
                Section("Install Local Skill") {
                    Button { installLocalSkill(isGlobal: false) }
                    label: { Label("Project Scope", systemImage: "folder.badge.plus") }

                    Button { installLocalSkill(isGlobal: true) }
                    label: { Label("Global Scope", systemImage: "globe") }
                }
                Section("Private Sources") {
                    Button { showingPrivateSourceInstall = true }
                    label: { Label("Install from Private Source…", systemImage: "lock.shield") }
                }
            } label: { Label("Import", systemImage: "plus.circle") }
            .menuStyle(.borderedButton)

            Button(action: { showingCLIAccessManager = true }) {
                Label("CLI Access", systemImage: "lock.shield")
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    var mainContent: some View {
        if isLoading && availableSkills.isEmpty {
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text("Loading skills catalog…").font(.subheadline).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage, availableSkills.isEmpty {
            SkillLibraryEmptyState(
                title: "Connection Error",
                systemImage: "exclamationmark.triangle.fill",
                description: error
            ) {
                Button("Retry") { fetchSkills(query: searchText) }.buttonStyle(.borderedProminent)
            }
        } else if !isLoading && availableSkills.isEmpty && !searchText.isEmpty {
            SkillLibraryEmptyState(
                title: "No Skills Found",
                systemImage: "magnifyingglass",
                description: "No skills match \"\(searchText)\". Try a different search term."
            )
        } else if !cliAccessManager.anyAccessGranted {
            SkillLibraryEmptyState(
                title: "CLI Access Required",
                systemImage: "lock.shield",
                description: "PromptHub needs access to CLI agent folders (like ~/.claude, ~/.cursor) to manage their skills."
            ) {
                Button("Configure Access\u{2026}") { showingCLIAccessManager = true }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            skillBrowser
        }
    }

    var skillBrowser: some View {
        SkillLibraryBrowser { skillListPane } detail: { skillDetailPane }
    }

    var skillListPane: some View {
        VStack(spacing: 0) {
            if isLoading && !availableSkills.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Refreshing catalog…").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
            }
            List {
                ForEach(availableSkills) { skill in
                    let info = workspaceService.installationState(for: skill, registry: installationRegistry)
                    Button { selectedSkillID = skill.id } label: {
                        SkillStoreListRow(
                            skill: skill,
                            installationState: info,
                            isInstalling: installingSkillIDs.contains(skill.id),
                            justInstalled: recentlyInstalledIDs.contains(skill.id),
                            isSelected: selectedSkillID == skill.id
                        )
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    var skillDetailPane: some View {
        if let selectedSkill {
            let info = workspaceService.installationState(for: selectedSkill, registry: installationRegistry)
            ScrollView {
                SkillStoreDetailPane(
                    skill: selectedSkill,
                    installationState: info,
                    isInstalling: installingSkillIDs.contains(selectedSkill.id),
                    justInstalled: recentlyInstalledIDs.contains(selectedSkill.id),
                    onConfigureInstall: { scope in
                        pendingInstall = PendingCatalogInstall(
                            skill: selectedSkill, installationState: info, preferredScope: scope)
                    },
                    onRemove: { scope in removeInstalledSkill(selectedSkill, scope: scope) },
                    onOpenSourcePage: { openSourcePage(for: selectedSkill) }
                )
                .padding(24)
            }
        } else {
            SkillLibraryEmptyState(
                title: "No Skill Selected",
                systemImage: "square.on.square.badge.person.crop",
                description: "Choose a skill from the catalog to inspect its install state and manage where it is available."
            )
        }
    }
}
