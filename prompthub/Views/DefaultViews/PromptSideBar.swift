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
    @AppStorage("sidebar.recentPromptsExpanded") private var isRecentPromptsExpanded = false
    
    @State private var promptToDelete: Prompt?
    
    @Binding var promptSelection: PromptSelection
    let onCreateNewPrompt: () -> Void
    let onCreateNewSkill: () -> Void
    
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $promptSelection) {
                librarySection
                skillsSection
                recentPromptsSection
            }
            .listStyle(.sidebar)
            
            sidebarFooter
        }
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
    private var librarySection: some View {
        NavigationLink(value: PromptSelection.allPrompts) {
            Label("All Prompts", systemImage: "tray.full")
        }
        .help("View all saved prompts in your library")
        
        NavigationLink(value: PromptSelection.mine) {
            Label("My Prompts", systemImage: "person.circle")
        }
        .help("Prompts created by you")
        
        NavigationLink(value: PromptSelection.explore) {
            Label("Explore Gallery", systemImage: "safari")
        }
        .help("Discover community prompts")
        
        NavigationLink(value: PromptSelection.shared) {
            Label("Shared with Me", systemImage: "person.2")
        }
        .help("Prompts shared by others via CloudKit")
    }

    @ViewBuilder
    private var skillsSection: some View {
        Section("Skills") {
            NavigationLink(value: PromptSelection.mySkills) {
                Label("My Skills", systemImage: "wand.and.stars")
            }
            .help("Author and manage your own skill drafts")

            NavigationLink(value: PromptSelection.skillStore) {
                Label("Discover", systemImage: "sparkles")
            }
            .help("Discover and install skills from skills.sh")
            
            NavigationLink(value: PromptSelection.installedSkills) {
                Label("Installed", systemImage: "square.stack.3d.up.fill")
            }
            .help("Manage your installed skills")
        }
    }

    @ViewBuilder
    private var recentPromptsSection: some View {
        Section("Recent Prompts", isExpanded: $isRecentPromptsExpanded) {
            ForEach(prompts) { prompt in
                NavigationLink(value: PromptSelection.prompt(prompt)) {
                    Label {
                        Text(prompt.name)
                            .font(prompt.name == "Untitled Prompt" ? .body.italic() : .body)
                            .foregroundColor(prompt.name == "Untitled Prompt" ? .secondary : .primary)
                    } icon: {
                        Image(systemName: "doc.text")
                    }
                }
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        promptToDelete = prompt
                    }
                }
            }
            .onDelete(perform: deletePrompts)
        }
    }

    @ViewBuilder
    private var sidebarFooter: some View {
        VStack(spacing: 0) {
            Divider()
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
                        .labelStyle(.iconOnly)
                        .imageScale(.medium)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(footerActionHelp)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var footerActionTitle: String {
        switch promptSelection {
        case .mySkills, .skill, .skillStore, .installedSkills:
            return "New Skill"
        default:
            return "New Prompt"
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

    private func deletePrompts(at offsets: IndexSet) {
        let promptsToDelete = offsets.map { prompts[$0] }
        for prompt in promptsToDelete {
            promptToDelete = prompt
        }
    }

    private func deletePrompt(_ prompt: Prompt) {
        // Delete the prompt - SwiftData will automatically cascade delete related history
        modelContext.delete(prompt)
        
        do {
            try modelContext.save()
            
            // Reset selection if the deleted prompt was currently selected
            if case .prompt(let selectedPrompt) = promptSelection, selectedPrompt == prompt {
                promptSelection = .allPrompts
            }
        } catch {
            print("Failed to delete prompt: \(error.localizedDescription)")
        }
        promptToDelete = nil
    }
}
