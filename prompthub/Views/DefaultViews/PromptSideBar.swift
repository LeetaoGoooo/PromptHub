//
//  PromptSideBar.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import SwiftUI

struct PromptSideBar: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Prompt.name) var prompts: [Prompt]
    @Query(sort: \Skill.updatedAt, order: .reverse) private var skillDrafts: [Skill]
    @Query private var sharedCreations: [SharedCreation]
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared
    @ObservedObject var installedWorkspaceStore: InstalledSkillsWorkspaceStore

    @Binding var promptSelection: PromptSelection
    @Binding var skillsScopeFilter: SkillsSidebarScopeFilter
    @Binding var skillsSourceFilter: SkillsSidebarSourceFilter
    @Binding var searchText: String
    let searchPlaceholder: String
    let isSearchEnabled: Bool
    let onCreateNewPrompt: () -> Void
    let onCreateNewSkill: () -> Void

    private var grantedAgentCount: Int { cliAccess.grantedDirectories.count }
    private var galleryCount: Int { BuiltInAgents.agents.count }
    private var installedSkills: [InstalledSkillSnapshot] { installedWorkspaceStore.installedSkills }

    private var promptsCount: Int { prompts.count + galleryCount }
    private var allInstalledCount: Int { installedSkills.count }
    private var globalInstalledCount: Int { installedSkills.filter(\.isGlobal).count }
    private var projectInstalledCount: Int { installedSkills.filter { !$0.isGlobal }.count }
    private var externalInstalledCount: Int { installedSkills.filter { $0.displaySource != nil }.count }
    private var localInstalledCount: Int { installedSkills.filter { $0.displaySource == nil }.count }
    private var currentPrimaryArea: SidebarPrimaryArea { promptSelection.sidebarPrimaryArea }
    
    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    primaryAreaSection

                    switch currentPrimaryArea {
                    case .skills:
                        skillsNavigationSection
                    case .prompts:
                        promptsNavigationSection
                    case .agents:
                        agentsNavigationSection
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
            }

            sidebarFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PromptHub")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .disabled(!isSearchEnabled)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(isSearchEnabled ? 1 : 0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(isSearchEnabled ? 1 : 0.72)
        }
        .padding(.horizontal, 12)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var primaryAreaSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(primaryAreaItems) { item in
                sidebarPrimaryButton(item)
            }
        }
    }

    private var promptsNavigationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sidebarSectionHeader("Prompts")

            VStack(spacing: 6) {
                sidebarSelectionButton(title: "All Prompts", icon: "square.grid.2x2", meta: "\(promptsCount)", isActive: promptSelection == .allPrompts) {
                    promptSelection = .allPrompts
                }
                sidebarSelectionButton(title: "My Prompts", icon: "person", meta: "\(prompts.count)", isActive: promptSelection == .mine) {
                    promptSelection = .mine
                }
                sidebarSelectionButton(title: "Shared with Me", icon: "link", meta: sharedCreations.isEmpty ? nil : "\(sharedCreations.count)", isActive: promptSelection == .shared) {
                    promptSelection = .shared
                }
                sidebarSelectionButton(title: "Explore Gallery", icon: "sparkles", meta: "\(galleryCount)", isActive: promptSelection == .explore) {
                    promptSelection = .explore
                }
            }
        }
    }

    private var skillsNavigationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                sidebarSectionHeader("Workspace")

                VStack(spacing: 6) {
                    sidebarSelectionButton(title: "Installed", icon: "square.stack.3d.up.fill", meta: "\(allInstalledCount)", isActive: promptSelection == .installedSkills) {
                        promptSelection = .installedSkills
                    }
                    sidebarSelectionButton(title: "Drafts", icon: "tag", meta: "\(skillDrafts.count)", isActive: promptSelection == .mySkills || isSkillDraftDetailSelected) {
                        promptSelection = .mySkills
                    }
                    sidebarSelectionButton(title: "Discover", icon: "globe.europe.africa", meta: nil, isActive: promptSelection == .skillStore) {
                        promptSelection = .skillStore
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                sidebarSectionHeader("Coverage")

                VStack(spacing: 6) {
                    sidebarInfoRow(title: "Global", icon: "globe", meta: "\(globalInstalledCount)")
                    sidebarInfoRow(title: "Project", icon: "folder", meta: "\(projectInstalledCount)")
                    sidebarInfoRow(title: "External", icon: "wrench.and.screwdriver", meta: "\(externalInstalledCount)")
                    sidebarInfoRow(title: "Local", icon: "laptopcomputer", meta: "\(localInstalledCount)")
                }
            }
        }
    }

    private var agentsNavigationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sidebarSectionHeader("Agents")

            VStack(spacing: 6) {
                sidebarSelectionButton(title: "Workspaces", icon: "terminal", meta: "\(grantedAgentCount)", isActive: promptSelection == .cliDashboard) {
                    promptSelection = .cliDashboard
                }
            }
        }
    }

    @ViewBuilder
    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    @ViewBuilder
    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                promptSelection = .onboarding
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .imageScale(.small)
                    Text("Get Started Guide")
                        .font(.caption.weight(.medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .help("Open the onboarding guide")

            HStack {
                Button {
                    promptSelection = .settings
                } label: {
                    Image(systemName: "gearshape")
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")

                Spacer()

                Button {
                    handleCreateAction()
                } label: {
                    Label(footerActionTitle, systemImage: footerActionSymbol)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(footerActionHelp)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var footerActionTitle: String {
        switch promptSelection {
        case .mySkills, .skill, .skillStore, .installedSkills:
            return "New skill"
        default:
            return "New prompt"
        }
    }

    private var footerActionSymbol: String {
        switch promptSelection {
        case .mySkills, .skill, .skillStore, .installedSkills:
            return "plus"
        default:
            return "plus"
        }
    }

    private var footerActionHelp: String {
        switch promptSelection {
        case .mySkills, .skill, .skillStore, .installedSkills:
            return "New Skill Draft (Cmd+N)"
        default:
            return "New Prompt (Cmd+N)"
        }
    }

    private func handleCreateAction() {
        switch promptSelection {
        case .mySkills, .skill, .skillStore, .installedSkills:
            onCreateNewSkill()
        default:
            onCreateNewPrompt()
        }
    }

    private var primaryAreaItems: [SidebarPrimaryButtonItem] {
        [
            SidebarPrimaryButtonItem(area: .skills, title: "Skills", systemImage: "wrench.and.screwdriver", meta: "\(max(allInstalledCount, skillDrafts.count))"),
            SidebarPrimaryButtonItem(area: .prompts, title: "Prompts", systemImage: "doc.text", meta: "\(promptsCount)"),
            SidebarPrimaryButtonItem(area: .agents, title: "Agents", systemImage: "gearshape.2", meta: "\(grantedAgentCount)")
        ]
    }

    private var isSkillDraftDetailSelected: Bool {
        if case .skill = promptSelection {
            return true
        }
        return false
    }

    @ViewBuilder
    private func sidebarPrimaryButton(_ item: SidebarPrimaryButtonItem) -> some View {
        Button {
            switch item.area {
            case .skills:
                if promptSelection.sidebarPrimaryArea != .skills {
                    skillsScopeFilter = .allInstalled
                    skillsSourceFilter = .all
                    promptSelection = .installedSkills
                }
            case .prompts:
                promptSelection = .allPrompts
            case .agents:
                promptSelection = .cliDashboard
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .frame(width: 16)
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                Spacer(minLength: 8)
                Text(item.meta)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(item.area == currentPrimaryArea ? Color.accentColor.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(item.area == currentPrimaryArea ? Color.accentColor.opacity(0.7) : Color(NSColor.separatorColor).opacity(0.35), lineWidth: item.area == currentPrimaryArea ? 1 : 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sidebarSelectionButton(title: String, icon: String, meta: String?, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(isActive ? Color.accentColor : .secondary)
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                if let meta {
                    Text(meta)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(isActive ? Color.accentColor : .secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func sidebarInfoRow(title: String, icon: String, meta: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 16)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(meta)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
    }

    private func deletePrompt(_ prompt: Prompt) {
        modelContext.delete(prompt)

        do {
            try modelContext.save()
            if case .prompt(let selectedPrompt) = promptSelection, selectedPrompt == prompt {
                promptSelection = .allPrompts
            }
        } catch {
            print("Failed to delete prompt: \(error.localizedDescription)")
        }
    }
}

private struct SidebarPrimaryButtonItem: Identifiable {
    let area: SidebarPrimaryArea
    let title: String
    let systemImage: String
    let meta: String
    var id: SidebarPrimaryArea { area }
}
