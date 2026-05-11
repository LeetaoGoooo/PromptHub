import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - View Builders

extension SkillStoreView {

    @ViewBuilder
    var accessoryBar: some View {
        HStack(spacing: 6) {
            SkillsWorkspacePicker(promptSelection: $promptSelection)

            Divider().frame(height: 14)

            if isInstallingLocalSkill { ProgressView().controlSize(.small) }

            Menu {
                Button { chooseProjectRoot() }
                label: { Label("Choose Project…", systemImage: "folder") }

                if workspaceService.selectedProjectRootURL != nil {
                    Button(role: .destructive) { workspaceService.setSelectedProjectRootURL(nil) }
                    label: { Label("Clear Project", systemImage: "xmark.circle") }
                }
            } label: {
                Label(workspaceService.selectedProjectDisplayName, systemImage: "folder")
                    .labelStyle(.titleAndIcon)
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .controlSize(.small)
            .fixedSize()

            Button { fetchSkills(query: searchText) } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Refresh catalog")

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
            } label: { Image(systemName: "square.and.arrow.down") }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .controlSize(.small)
            .fixedSize()
            .help("Import a local or private skill")

            Divider().frame(height: 14)

            CLIStatusIndicator(manager: cliAccessManager) {
                showingCLIAccessManager = true
            }
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
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Results")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("\(availableSkills.count) catalog skills")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.82))

            List {
                if !availableSkills.isEmpty {
                    Section("Catalog (\(availableSkills.count))") {
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
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)

            // Private sources tip
            Button {
                showingPrivateSourceInstall = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield.fill").foregroundStyle(Color.purple).font(.caption)
                    Text("Install from a private source…")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14).padding(.vertical, 9)
            }
            .buttonStyle(.plain)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(Divider(), alignment: .top)
            .help("Install a skill from a private GitHub repo or local directory (Settings → Sources to configure)")
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
