//
//  PromptSideBar.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import SwiftUI

struct PromptSideBar: View {
    @Environment(\.controlActiveState) private var controlActiveState
    @Query(sort: \Prompt.name) var prompts: [Prompt]
    @Query private var sharedCreations: [SharedCreation]
    @Query(sort: \Skill.updatedAt, order: .reverse) private var skillDrafts: [Skill]
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared
    @ObservedObject var installedWorkspaceStore: InstalledSkillsWorkspaceStore

    @Binding var navigationState: WorkspaceNavigationState
    let onCreateNewPrompt: () -> Void
    let onCreateNewSkill: () -> Void

    private var grantedAgentCount: Int { cliAccess.grantedDirectories.count }
    private var galleryCount: Int { BuiltInAgents.agents.count }
    private var installedSkills: [InstalledSkillSnapshot] { installedWorkspaceStore.installedSkills }

    private var promptsCount: Int { prompts.count + galleryCount }
    private var myPromptsCount: Int { prompts.count }
    private var sharedPromptsCount: Int { sharedCreations.count }
    private var allInstalledCount: Int { installedSkills.count }
    private var mySkillsCount: Int { skillDrafts.count }

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    promptsNavigationSection
                    Divider().opacity(0.6).padding(.vertical, 10)
                    skillsNavigationSection
                    Divider().opacity(0.6).padding(.vertical, 10)
                    agentsNavigationSection
                    Divider().opacity(0.6).padding(.vertical, 10)
                    specialNavigationSection
                }
                .padding(.horizontal, PH.Spacing.sbPad)
                .padding(.top, 2)
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
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(PH.Color.primary)
            .padding(.horizontal, PH.Spacing.sbPad)
            .padding(.top, 18)
            .padding(.bottom, 12)
    }

    private var promptsNavigationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sidebarSectionHeader("Prompts")

            VStack(spacing: 4) {
                sidebarSelectionButton(
                    title: "All",
                    icon: "square.grid.2x2",
                    meta: metaCount(promptsCount),
                    isActive: navigationState.domain == .prompts && navigationState.promptLens == .all
                ) {
                    navigationState.showPrompts(.all)
                }
                .keyboardShortcut("1", modifiers: .command)

                sidebarSelectionButton(
                    title: "Mine",
                    icon: "person.crop.circle",
                    meta: metaCount(myPromptsCount),
                    isActive: navigationState.domain == .prompts && navigationState.promptLens == .mine
                ) {
                    navigationState.showPrompts(.mine)
                }

                sidebarSelectionButton(
                    title: "Shared",
                    icon: "square.and.arrow.up",
                    meta: metaCount(sharedPromptsCount),
                    isActive: navigationState.domain == .prompts && navigationState.promptLens == .shared
                ) {
                    navigationState.showPrompts(.shared)
                }

                sidebarSelectionButton(
                    title: "Explore",
                    icon: "globe",
                    meta: nil,
                    isActive: navigationState.domain == .prompts && navigationState.promptLens == .explore
                ) {
                    navigationState.showPrompts(.explore)
                }
            }
        }
    }

    private var skillsNavigationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sidebarSectionHeader("Skills")

            VStack(spacing: 4) {
                sidebarSelectionButton(
                    title: "Installed",
                    icon: "square.stack.3d.up.fill",
                    meta: metaCount(allInstalledCount),
                    isActive: navigationState.domain == .skills && navigationState.skillLens == .installed
                ) {
                    navigationState.showSkills(.installed)
                }
                .keyboardShortcut("2", modifiers: .command)

                sidebarSelectionButton(
                    title: "My Skills",
                    icon: "wand.and.stars",
                    meta: metaCount(mySkillsCount),
                    isActive: navigationState.domain == .skills && navigationState.skillLens == .drafts
                ) {
                    navigationState.showSkills(.drafts)
                }

                sidebarSelectionButton(
                    title: "Store",
                    icon: "sparkles.rectangle.stack",
                    meta: nil,
                    isActive: navigationState.domain == .skills && navigationState.skillLens == .store
                ) {
                    navigationState.showSkills(.store)
                }
            }
        }
    }

    private var agentsNavigationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sidebarSectionHeader("Agents")

            VStack(spacing: 4) {
                sidebarSelectionButton(
                    title: "Workspaces",
                    icon: "terminal",
                    meta: metaCount(grantedAgentCount),
                    isActive: navigationState.domain == .agents
                ) {
                    navigationState.showAgents(.workspaces)
                }
                .keyboardShortcut("3", modifiers: .command)
            }
        }
    }

    private var specialNavigationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sidebarSectionHeader("Special")

            VStack(spacing: 4) {
                sidebarSelectionButton(
                    title: "Settings",
                    icon: "gearshape",
                    meta: nil,
                    isActive: navigationState.domain == .special && navigationState.specialPage == .settings
                ) {
                    navigationState.showSpecial(.settings)
                }

                sidebarSelectionButton(
                    title: "CLI Dashboard",
                    icon: "terminal",
                    meta: nil,
                    isActive: navigationState.domain == .special && navigationState.specialPage == .cliDashboard
                ) {
                    navigationState.showSpecial(.cliDashboard)
                }
            }
        }
    }

    @ViewBuilder
    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(PH.Font.groupLabel)
            .foregroundStyle(PH.Color.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    @ViewBuilder
    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                navigationState.showSpecial(.onboarding)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .imageScale(.small)
                    Text("Get Started Guide")
                        .font(.system(size: 11, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(PH.Color.statusOK)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(PH.Color.chipBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, PH.Spacing.sbPad)
            .padding(.top, 8)
            .help("Open the onboarding guide")

            HStack {
                Spacer()

                Button {
                    handleCreateAction()
                } label: {
                    Label(footerActionTitle, systemImage: footerActionSymbol)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PH.Color.secondary)
                }
                .buttonStyle(.plain)
                .help(footerActionHelp)
            }
            .padding(.horizontal, PH.Spacing.sbPad)
            .padding(.vertical, 10)
        }
    }

    private var footerActionTitle: String {
        switch navigationState.domain {
        case .skills:
            return "New skill"
        default:
            return "New prompt"
        }
    }

    private var footerActionSymbol: String {
        "plus"
    }

    private var footerActionHelp: String {
        switch navigationState.domain {
        case .skills:
            return "New Skill Draft (Cmd+N)"
        default:
            return "New Prompt (Cmd+N)"
        }
    }

    private func handleCreateAction() {
        switch navigationState.domain {
        case .skills:
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
        SidebarSelectionButton(title: title, icon: icon, meta: meta, isActive: isActive, action: action)
    }
}

private struct SidebarSelectionButton: View {
    @Environment(\.controlActiveState) private var controlActiveState

    let title: String
    let icon: String
    let meta: String?
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false

    private var backgroundFill: Color {
        if isActive {
            return controlActiveState == .key ? PH.Color.accentTint : PH.Color.accentTint.opacity(0.72)
        }

        if isHovering {
            return PH.Color.hoverFill
        }

        return .clear
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: PH.Spacing.sbRowGap) {
                Image(systemName: icon)
                    .frame(width: 16)
                    .foregroundStyle(isActive ? PH.Color.accent : PH.Color.secondary)
                Text(title)
                    .font(PH.Font.rowName)
                    .foregroundStyle(isActive ? PH.Color.primary : PH.Color.primary)
                Spacer(minLength: 8)
                if let meta {
                    Text(meta)
                        .font(PH.Font.badge)
                        .foregroundStyle(isActive ? PH.Color.accent : PH.Color.secondary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(backgroundFill, in: RoundedRectangle(cornerRadius: PH.Spacing.rowCorner, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: PH.Spacing.rowCorner, style: .continuous)
                    .stroke(isActive ? PH.Color.accent.opacity(0.18) : PH.Color.stroke.opacity(isHovering ? 1 : 0), lineWidth: 1)
            }
            .contentShape(Rectangle())
            .animation(PH.Motion.hover, value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}
