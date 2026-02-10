import SwiftUI

struct InstalledSkillsView: View {
    @State private var installedSkills: [SkillCLIService.SkillInfo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    // Delete interaction state
    @State private var skillToDelete: SkillCLIService.SkillInfo?
    @State private var removingSkillIDs: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading && installedSkills.isEmpty {
                ProgressView("Loading installed skills...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, installedSkills.isEmpty {
                ContentUnavailableView {
                    Label("Error Loading Skills", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") { fetchInstalledSkills() }
                }
            } else if filteredSkills.isEmpty {
                ContentUnavailableView {
                    Label(searchText.isEmpty ? "No Skills Installed" : "No Matches",
                          systemImage: searchText.isEmpty ? "square.stack.3d.up.slash" : "magnifyingglass")
                } description: {
                    Text(searchText.isEmpty ? "Install skills from the Skill Store to extend your agents' capabilities." : "Try a different search term.")
                }
            } else {
                ZStack {
                    Color(NSColor.textBackgroundColor)
                        .ignoresSafeArea()
                    
                    List {
                        if !projectSkills.isEmpty {
                            Section {
                                ForEach(projectSkills) { skill in
                                    SkillRow(
                                        skill: skill,
                                        isRemoving: removingSkillIDs.contains(skill.id),
                                        onRemove: {
                                            skillToDelete = skill
                                        }
                                    )
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                                }
                            } header: {
                                Text("Project Skills")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                                    .padding(.bottom, 4)
                            }
                        }
                        
                        if !globalSkills.isEmpty {
                            Section {
                                ForEach(globalSkills) { skill in
                                    SkillRow(
                                        skill: skill,
                                        isRemoving: removingSkillIDs.contains(skill.id),
                                        onRemove: {
                                            skillToDelete = skill
                                        }
                                    )
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                                }
                            } header: {
                                Text("Global Skills")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 8)
                                    .padding(.bottom, 4)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            
            // Error banner for non-fatal errors (e.g., delete failure)
            if let error = errorMessage, !installedSkills.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Dismiss") {
                        withAnimation { errorMessage = nil }
                    }
                    .font(.caption.bold())
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.orange.opacity(0.08))
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Installed Skills")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search installed skills...")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: fetchInstalledSkills) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            fetchInstalledSkills()
        }
        // Confirmation alert
        .alert("Remove Skill", isPresented: Binding(
            get: { skillToDelete != nil },
            set: { if !$0 { skillToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { skillToDelete = nil }
            Button("Remove", role: .destructive) {
                if let skill = skillToDelete {
                    removeSkill(skill)
                }
            }
        } message: {
            if let skill = skillToDelete {
                Text("Are you sure you want to remove \"\(skill.name.titleCased)\"? This will uninstall it from your \(skill.isGlobal ? "global" : "project") configuration.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredSkills: [SkillCLIService.SkillInfo] {
        if searchText.isEmpty {
            return installedSkills
        } else {
            return installedSkills.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var projectSkills: [SkillCLIService.SkillInfo] {
        filteredSkills.filter { !$0.isGlobal }
    }
    
    private var globalSkills: [SkillCLIService.SkillInfo] {
        filteredSkills.filter { $0.isGlobal }
    }
    
    // MARK: - Actions
    
    private func fetchInstalledSkills() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                installedSkills = try await SkillCLIService.shared.listInstalledSkills()
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    private func removeSkill(_ skill: SkillCLIService.SkillInfo) {
        // Set per-row loading state
        withAnimation(.easeInOut(duration: 0.2)) {
            removingSkillIDs.insert(skill.id)
            errorMessage = nil
        }
        
        Task {
            do {
                try await SkillCLIService.shared.removeSkill(name: skill.name, isGlobal: skill.isGlobal)
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    removingSkillIDs.remove(skill.id)
                    installedSkills.removeAll { $0.id == skill.id }
                }
            } catch {
                withAnimation {
                    removingSkillIDs.remove(skill.id)
                    errorMessage = "Failed to remove \(skill.name.titleCased): \(error.localizedDescription)"
                }
            }
        }
        
        skillToDelete = nil
    }
}

// MARK: - SkillRow

struct SkillRow: View {
    let skill: SkillCLIService.SkillInfo
    let isRemoving: Bool
    let onRemove: () -> Void
    @State private var isHovering = false
    @State private var isButtonHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name.titleCased)
                    .font(.headline)
                    .foregroundColor(isRemoving ? .secondary : (isHovering ? .primary : .primary.opacity(0.9)))
                
                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .opacity(isRemoving ? 0.5 : 1.0)
            
            Spacer()
            
            if isRemoving {
                // Spinner during removal
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Removing...")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .transition(.opacity)
            } else if isHovering {
                Button(role: .destructive) {
                    onRemove()
                } label: {
                    Text("Remove")
                        .font(.caption2.bold())
                        .foregroundColor(isButtonHovering ? .white : .red.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isButtonHovering ? Color.red.opacity(0.85) : Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .onHover { h in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isButtonHovering = h
                    }
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity.combined(with: .scale(scale: 0.9))
                ))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(rowBackground)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            Button("Remove Skill", role: .destructive, action: onRemove)
        }
        .disabled(isRemoving)
    }
    
    private var rowBackground: Color {
        if isRemoving {
            return Color.orange.opacity(0.06)
        } else if isHovering {
            return Color.secondary.opacity(0.08)
        } else {
            return Color.clear
        }
    }
}
