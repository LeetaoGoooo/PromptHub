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
    @AppStorage("sidebar.recentPromptsExpanded") private var isRecentPromptsExpanded = true
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared

    @State private var promptToDelete: Prompt?

    @Binding var promptSelection: PromptSelection
    @Binding var searchText: String
    let searchPlaceholder: String
    let isSearchEnabled: Bool
    let onCreateNewPrompt: () -> Void
    let onCreateNewSkill: () -> Void

    private var grantedAgentCount: Int { cliAccess.grantedDirectories.count }
    private var galleryCount: Int { BuiltInAgents.agents.count }

    private var recentPrompts: [Prompt] {
        prompts
            .sorted { ($0.lastEditedAt ?? Date.distantPast) > ($1.lastEditedAt ?? Date.distantPast) }
            .prefix(8)
            .map { $0 }
    }

    private var sidebarRows: [SidebarSectionModel] {
        [
            SidebarSectionModel(
                title: "Library",
                items: [
                    .init(selection: .allPrompts, title: "All Prompts", systemImage: "square.grid.2x2", meta: "\(prompts.count + galleryCount)"),
                    .init(selection: .mine, title: "My Prompts", systemImage: "person", meta: "\(prompts.count)"),
                    .init(selection: .explore, title: "Explore Gallery", systemImage: "sparkles", meta: "\(galleryCount)"),
                    .init(selection: .shared, title: "Shared with Me", systemImage: "link", meta: sharedCreations.isEmpty ? nil : "\(sharedCreations.count)")
                ]
            ),
            SidebarSectionModel(
                title: "Skills",
                items: [
                    .init(selection: .mySkills, title: "My Skills", systemImage: "wand.and.stars", meta: skillDrafts.isEmpty ? nil : "\(skillDrafts.count)"),
                    .init(selection: .skillStore, title: "Discover", systemImage: "sparkles", meta: nil),
                    .init(selection: .installedSkills, title: "Installed", systemImage: "square.stack.3d.up.fill", meta: nil)
                ]
            )
        ]
    }
    
    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader

            List(selection: $promptSelection) {
                ForEach(sidebarRows) { section in
                    Section {
                        ForEach(section.items) { item in
                            NavigationLink(value: item.selection) {
                                sidebarRowLabel(item)
                            }
                        }
                    } header: {
                        sidebarSectionHeader(section.title)
                    }
                }

                cliSection

                if !recentPrompts.isEmpty {
                    recentPromptsSection
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            sidebarFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .alert("Delete Prompt", isPresented: Binding(
            get: { promptToDelete != nil },
            set: { if !$0 { promptToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { promptToDelete = nil }
            Button("Delete", role: .destructive) {
                if let prompt = promptToDelete {
                    deletePrompt(prompt)
                }
            }
        } message: {
            if let prompt = promptToDelete {
                Text("Are you sure you want to delete '\(prompt.name)'?")
            }
        }
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

    @ViewBuilder
    private func sidebarSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    @ViewBuilder
    private var cliSection: some View {
        Section {
            NavigationLink(value: PromptSelection.cliDashboard) {
                HStack(spacing: 10) {
                    ZStack(alignment: .bottomTrailing) {
                        Image(systemName: "terminal")
                            .frame(width: 16)
                        Circle()
                            .fill(grantedAgentCount > 0 ? Color.green : Color.secondary.opacity(0.45))
                            .frame(width: 7, height: 7)
                            .offset(x: 3, y: 3)
                    }
                    Text("Workspaces")
                        .font(.subheadline.weight(.medium))
                    Spacer(minLength: 8)
                    Text("\(grantedAgentCount)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .clipShape(Capsule())
                }
            }
        } header: {
            sidebarSectionHeader("Agents")
        }
    }

    @ViewBuilder
    private var recentPromptsSection: some View {
        Section("Recent Prompts", isExpanded: $isRecentPromptsExpanded) {
            ForEach(recentPrompts) { prompt in
                NavigationLink(value: PromptSelection.prompt(prompt)) {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .frame(width: 16)
                        Text(prompt.name)
                            .font(prompt.name == "Untitled Prompt" ? .body.italic() : .body)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("v\(max(prompt.latestVersionNumber, 1))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        promptToDelete = prompt
                    }
                }
            }
        }
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

    @ViewBuilder
    private func sidebarRowLabel(_ item: SidebarItemModel) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.systemImage)
                .frame(width: 16)
            Text(item.title)
                .font(.subheadline.weight(.medium))
            Spacer(minLength: 8)
            if let meta = item.meta {
                Text(meta)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
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
        promptToDelete = nil
    }
}

private struct SidebarSectionModel: Identifiable {
    let title: String
    let items: [SidebarItemModel]
    var id: String { title }
}

private struct SidebarItemModel: Identifiable {
    let selection: PromptSelection
    let title: String
    let systemImage: String
    let meta: String?
    var id: PromptSelection { selection }
}
