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
    @Environment(\.controlActiveState) private var controlActiveState
    @Query(sort: \Prompt.name) var prompts: [Prompt]
    @Query(sort: \Skill.updatedAt, order: .reverse) private var skillDrafts: [Skill]
    @Query private var sharedCreations: [SharedCreation]
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared
    @ObservedObject var installedWorkspaceStore: InstalledSkillsWorkspaceStore

    @Binding var promptSelection: PromptSelection
    let onCreateNewPrompt: () -> Void
    let onCreateNewSkill: () -> Void

    private var grantedAgentCount: Int { cliAccess.grantedDirectories.count }
    private var galleryCount: Int { BuiltInAgents.agents.count }
    private var installedSkills: [InstalledSkillSnapshot] { installedWorkspaceStore.installedSkills }

    private var promptsCount: Int { prompts.count + galleryCount }
    private var allInstalledCount: Int { installedSkills.count }

    private var isPromptDetailSelected: Bool {
        if case .prompt = promptSelection { return true }
        return false
    }
    private var isSkillDraftDetailSelected: Bool {
        if case .skill = promptSelection { return true }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    promptsNavigationSection
                    Divider().opacity(0.5).padding(.vertical, 10)
                    skillsNavigationSection
                    Divider().opacity(0.5).padding(.vertical, 10)
                    agentsNavigationSection
                }
                .padding(.horizontal, 12)
                .padding(.top, 4)
                .padding(.bottom, 18)
            }

            sidebarFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PH.Color.sidebarBg)
    }

    @ViewBuilder
    private var sidebarHeader: some View {
        Text("PromptHub")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }

    private var promptsNavigationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sidebarSectionHeader("Prompts")

            VStack(spacing: 6) {
                sidebarSelectionButton(
                    title: "Prompts",
                    icon: "square.grid.2x2",
                    meta: metaCount(promptsCount),
                    isActive: promptSelection == .allPrompts || promptSelection == .mine || promptSelection == .shared || promptSelection == .explore || isPromptDetailSelected
                ) {
                    if promptSelection != .allPrompts && promptSelection != .mine && promptSelection != .shared && promptSelection != .explore && !isPromptDetailSelected {
                        promptSelection = .allPrompts
                    }
                }
                .keyboardShortcut("1", modifiers: .command)
            }
        }
    }

    private var skillsNavigationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sidebarSectionHeader("Skills")

            VStack(spacing: 6) {
                sidebarSelectionButton(
                    title: "Skills",
                    icon: "square.stack.3d.up.fill",
                    meta: metaCount(allInstalledCount),
                    isActive: promptSelection == .installedSkills || promptSelection == .mySkills || promptSelection == .skillStore || isSkillDraftDetailSelected
                ) {
                    if promptSelection != .installedSkills && promptSelection != .mySkills && promptSelection != .skillStore && !isSkillDraftDetailSelected {
                        promptSelection = .installedSkills
                    }
                }
                .keyboardShortcut("2", modifiers: .command)
            }
        }
    }

    private var agentsNavigationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sidebarSectionHeader("Agents")

            VStack(spacing: 6) {
                sidebarSelectionButton(title: "Workspaces", icon: "terminal", meta: metaCount(grantedAgentCount), isActive: promptSelection == .cliDashboard) {
                    promptSelection = .cliDashboard
                }
                .keyboardShortcut("3", modifiers: .command)
            }
        }
    }

    @ViewBuilder
    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(PH.Font.sectionHead)
            .foregroundStyle(PH.Color.secondary)
            .textCase(.uppercase)
            .tracking(0.3)
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

    private func metaCount(_ value: Int) -> String? {
        value > 0 ? "\(value)" : nil
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
            .background(isActive ? (controlActiveState == .key ? PH.Color.accentTint : PH.Color.accentTint.opacity(0.45)) : Color.clear, in: RoundedRectangle(cornerRadius: PH.Spacing.rowCorner, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
