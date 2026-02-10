import SwiftUI
import Observation

struct SkillStoreView: View {
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var availableSkills: [SkillCLIService.SkillInfo] = []
    @State private var errorMessage: String?
    @State private var installedSkills: [SkillCLIService.SkillInfo] = []
    @State private var selectedSkillForDetail: SkillCLIService.SkillInfo?
    
    // Per-card install state
    @State private var installingSkillIDs: Set<String> = []
    @State private var recentlyInstalledIDs: Set<String> = []
    
    // Search debounce
    @State private var searchTask: Task<Void, Never>?
    
    let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 360), spacing: 24)
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading && availableSkills.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Connecting to skills.sh...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, availableSkills.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Connection Error")
                        .font(.headline)
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button("Retry") {
                        fetchSkills(query: searchText)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    // Inline loading indicator for search refinements
                    if isLoading && !availableSkills.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 16)
                    }
                    
                    if !isLoading && availableSkills.isEmpty && !searchText.isEmpty {
                        ContentUnavailableView {
                            Label("No Skills Found", systemImage: "magnifyingglass")
                        } description: {
                            Text("No skills match \"\(searchText)\". Try a different search term.")
                        }
                        .padding(.top, 60)
                    } else {
                        LazyVGrid(columns: columns, spacing: 24) {
                            ForEach(availableSkills) { skill in
                                SkillStoreCard(
                                    skill: skill,
                                    isInstalled: isSkillInstalled(skill),
                                    isInstalling: installingSkillIDs.contains(skill.id),
                                    justInstalled: recentlyInstalledIDs.contains(skill.id),
                                    onInstall: { isGlobal in
                                        installSkill(skill, isGlobal: isGlobal)
                                    },
                                    onShowDetails: {
                                        selectedSkillForDetail = skill
                                    }
                                )
                            }
                        }
                        .padding(24)
                    }
                }
            }
        }
        .navigationTitle("Skill Store")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search skills.sh...")
        .onChange(of: searchText) { _, newValue in
            debouncedSearch(query: newValue)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: { fetchSkills(query: searchText) }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
        .sheet(item: $selectedSkillForDetail) { skill in
            if let urlString = skill.url, let url = URL(string: urlString) {
                SkillDetailWebView(url: url, title: skill.name)
            }
        }
        .onAppear {
            fetchSkills()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Helpers
    
    private func isSkillInstalled(_ skill: SkillCLIService.SkillInfo) -> Bool {
        return installedSkills.contains { installed in
            if installed.name == skill.name { return true }
            if let skillNameOnly = skill.name.components(separatedBy: "@").last,
               installed.name == skillNameOnly {
                return true
            }
            return false
        }
    }
    
    // MARK: - Debounced Search
    
    private func debouncedSearch(query: String) {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000) // 400ms debounce
            guard !Task.isCancelled else { return }
            await MainActor.run {
                fetchSkills(query: query)
            }
        }
    }
    
    // MARK: - Fetch Skills
    
    private func fetchSkills(query: String = "") {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                availableSkills = try await SkillCLIService.shared.findSkills(query: query)
                installedSkills = try await SkillCLIService.shared.listInstalledSkills()
                isLoading = false
            } catch {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // MARK: - Install Skill (with per-card feedback)
    
    private func installSkill(_ skill: SkillCLIService.SkillInfo, isGlobal: Bool) {
        // Set loading state on this card
        withAnimation(.easeInOut(duration: 0.2)) {
            installingSkillIDs.insert(skill.id)
        }
        
        Task {
            do {
                try await SkillCLIService.shared.addSkill(package: skill.name, isGlobal: isGlobal)
                installedSkills = try await SkillCLIService.shared.listInstalledSkills()
                
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    installingSkillIDs.remove(skill.id)
                    recentlyInstalledIDs.insert(skill.id)
                }
                
                // Clear "just installed" badge after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation(.easeOut(duration: 0.3)) {
                    recentlyInstalledIDs.remove(skill.id)
                }
                
            } catch {
                withAnimation {
                    installingSkillIDs.remove(skill.id)
                }
                errorMessage = "Failed to install \(skill.name.titleCased): \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - SkillStoreCard

struct SkillStoreCard: View {
    let skill: SkillCLIService.SkillInfo
    let isInstalled: Bool
    let isInstalling: Bool
    let justInstalled: Bool
    let onInstall: (Bool) -> Void
    let onShowDetails: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(alignment: .top) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.accentColor)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(skill.name.titleCased)
                        .font(.headline)
                        .lineLimit(1)
                    
                    statusBadge
                }
                
                Spacer()
                
                installButton
            }
            
            // Description
            Text(skill.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(3)
                .frame(height: 50, alignment: .topLeading)
            
            Divider()
            
            // Footer
            HStack {
                Text("skills.sh")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let urlString = skill.url, let _ = URL(string: urlString) {
                    Button {
                        onShowDetails()
                    } label: {
                        HStack(spacing: 4) {
                            Text("Details")
                            Image(systemName: "arrow.up.right.square")
                        }
                        .font(.caption2.bold())
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(cardBorder, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovering = hovering
            }
        }
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var statusBadge: some View {
        if justInstalled {
            Label("Just Installed!", systemImage: "checkmark.circle.fill")
                .font(.caption2.bold())
                .foregroundColor(.green)
                .transition(.scale.combined(with: .opacity))
        } else if isInstalled {
            Label("Installed", systemImage: "checkmark.circle.fill")
                .font(.caption2.bold())
                .foregroundColor(.green)
        } else if isInstalling {
            HStack(spacing: 4) {
                ProgressView()
                    .controlSize(.mini)
                Text("Installing...")
                    .font(.caption2.bold())
                    .foregroundColor(.orange)
            }
        } else {
            Text("Available")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Install Button
    
    @ViewBuilder
    private var installButton: some View {
        if isInstalling {
            // Spinner replaces button during install
            ProgressView()
                .controlSize(.small)
                .frame(width: 52, height: 26)
        } else if justInstalled {
            // Checkmark animation post-install
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
                .transition(.scale.combined(with: .opacity))
        } else if !isInstalled {
            // Install menu
            Menu {
                Button {
                    onInstall(false)
                } label: {
                    Label("Install to Project", systemImage: "folder")
                }
                Button {
                    onInstall(true)
                } label: {
                    Label("Install Globally", systemImage: "globe")
                }
            } label: {
                Text("Get")
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        // If installed but not "just installed", show nothing (badge handles it)
    }
    
    // MARK: - Card Appearance
    
    private var cardBackground: Color {
        if justInstalled {
            return Color.green.opacity(0.05)
        } else if isInstalling {
            return Color.orange.opacity(0.03)
        } else if isHovering {
            return Color.accentColor.opacity(0.05)
        } else {
            return Color(NSColor.controlBackgroundColor)
        }
    }
    
    private var cardBorder: Color {
        if justInstalled {
            return Color.green.opacity(0.3)
        } else if isInstalling {
            return Color.orange.opacity(0.3)
        } else if isHovering {
            return Color.accentColor.opacity(0.3)
        } else {
            return Color(NSColor.separatorColor)
        }
    }
}
