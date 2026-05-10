import AppKit
import PromptHubSkillKit
import SwiftData
import SwiftUI

struct InstalledSkillsView: View {
    @Environment(\.modelContext) private var modelContext
    private let workspaceService = SkillWorkspaceService.shared
    private let draftService = SkillDraftService.shared
    @Query(sort: \Skill.updatedAt, order: .reverse) private var skillDrafts: [Skill]
    let searchText: String
    let onSelectSkillDraft: (Skill) -> Void

    private struct PendingRemoval: Identifiable {
        let id = UUID()
        let skill: InstalledSkillSnapshot
        let targetAgents: [AgentWorkflow]?
    }

    @State private var workspaceSnapshot = InstalledSkillsWorkspaceSnapshot.empty
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedSkillID: String?
    @State private var pendingRemoval: PendingRemoval?
    @State private var removingSkillIDs: Set<String> = []
    @State private var addingSkillIDs: Set<String> = []
    @State private var agentVisibility: [SkillAgentVisibility] = []
    @State private var isLoadingVisibility = false
    @State private var sourceIntegrity: SkillSourceIntegrity?
    @State private var isLoadingIntegrity = false
    @State private var fetchTask: Task<Void, Never>?
    @ObservedObject private var cliAccessManager = CLIDirectoryAccessManager.shared
    @State private var showingCLIAccessManager = false

    private var installedSkills: [InstalledSkillSnapshot] {
        workspaceSnapshot.installedSkills
    }

    private var filteredSkills: [InstalledSkillSnapshot] {
        if searchText.isEmpty {
            return installedSkills
        }

        return installedSkills.filter {
            $0.packageName.localizedCaseInsensitiveContains(searchText) ||
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var projectSkills: [InstalledSkillSnapshot] {
        filteredSkills.filter { !$0.isGlobal }
    }

    private var globalSkills: [InstalledSkillSnapshot] {
        filteredSkills.filter { $0.isGlobal }
    }

    private var selectedSkill: InstalledSkillSnapshot? {
        if let selectedSkillID,
           let matched = filteredSkills.first(where: { $0.id == selectedSkillID }) {
            return matched
        }
        return filteredSkills.first
    }

    private var headerMetrics: [SkillLibraryMetric] {
        [
            SkillLibraryMetric(
                value: "\(workspaceSnapshot.summary.installedCount)",
                title: "Installed",
                systemImage: "square.stack.3d.up"
            ),
            SkillLibraryMetric(
                value: "\(workspaceSnapshot.summary.projectInstalledCount)",
                title: "Project",
                systemImage: "folder"
            ),
            SkillLibraryMetric(
                value: "\(workspaceSnapshot.summary.globalInstalledCount)",
                title: "Global",
                systemImage: "globe"
            ),
            SkillLibraryMetric(
                value: "\(skillDrafts.count)",
                title: "Drafts",
                systemImage: "wand.and.stars"
            )
        ]
    }

    var body: some View {
        SkillLibraryScreen(
            title: "Installed Skills",
            subtitle: "Audit what is live in each CLI environment, remove it cleanly by scope, and keep project and global installations explicit.",
            metrics: headerMetrics
        ) {
            HStack(spacing: 10) {
                Menu {
                    Button {
                        chooseProjectRoot()
                    } label: {
                        Label("Choose Project…", systemImage: "folder")
                    }

                    if workspaceService.selectedProjectRootURL != nil {
                        Button(role: .destructive) {
                            workspaceService.setSelectedProjectRootURL(nil)
                        } label: {
                            Label("Clear Project", systemImage: "xmark.circle")
                        }
                    }
                } label: {
                    Label(workspaceService.selectedProjectDisplayName, systemImage: "folder")
                }
                .menuStyle(.borderedButton)

                Button(action: fetchInstalledSkills) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                
                Button(action: { showingCLIAccessManager = true }) {
                    Label("CLI Access", systemImage: "lock.shield")
                }
                .buttonStyle(.bordered)
            }
        } content: {
            VStack(spacing: 0) {
                mainContentView
                nonFatalErrorBanner
            }
        }
        .sheet(isPresented: $showingCLIAccessManager, onDismiss: {
            fetchInstalledSkills()
        }) {
            CLIAccessManagerView()
        }
        .onAppear {
            fetchInstalledSkills()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillInstallationsDidChange)) { _ in
            fetchInstalledSkills()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillProjectSelectionDidChange)) { _ in
            fetchInstalledSkills()
        }
        .onChange(of: searchText) { _, _ in
            syncSelection()
        }
        .task(id: selectedSkillID) {
            // task(id:) is automatically cancelled and restarted when selectedSkillID changes,
            // which prevents stale results from an older selection overwriting the current one.
            guard let skill = selectedSkill else {
                agentVisibility = []
                sourceIntegrity = nil
                return
            }
            // Kick off visibility scan (fast, filesystem only).
            isLoadingVisibility = true
            isLoadingIntegrity = true
            agentVisibility = []
            sourceIntegrity = nil

            async let visibilityTask = workspaceService.auditAgentVisibility(for: skill)
            async let integrityTask = workspaceService.auditSourceIntegrity(for: skill)

            let visResult = await visibilityTask
            guard !Task.isCancelled else { return }
            agentVisibility = visResult
            isLoadingVisibility = false

            let intResult = await integrityTask
            guard !Task.isCancelled else { return }
            sourceIntegrity = intResult
            isLoadingIntegrity = false
        }
        .alert("Remove Skill", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
            Button("Remove", role: .destructive) {
                if let pending = pendingRemoval {
                    removeSkill(pending.skill, targetAgents: pending.targetAgents)

                }
            }
        } message: {
            if let pending = pendingRemoval {
                Text(removalMessage(for: pending))
            }
        }
    }

    @ViewBuilder
    private var mainContentView: some View {
        if !cliAccessManager.anyAccessGranted {
            SkillLibraryEmptyState(
                title: "CLI Access Required",
                systemImage: "lock.shield",
                description: "PromptHub needs access to CLI agent folders (like ~/.claude, ~/.cursor) to manage their skills."
            ) {
                Button("Configure Access\u{2026}") {
                    showingCLIAccessManager = true
                }
                .buttonStyle(.borderedProminent)
            }
        } else if isLoading && installedSkills.isEmpty {
            ProgressView("Loading installed skills...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = errorMessage, installedSkills.isEmpty {
            SkillLibraryEmptyState(
                title: "Error Loading Skills",
                systemImage: "exclamationmark.triangle",
                description: error
            ) {
                Button("Retry") { fetchInstalledSkills() }
            }
        } else if filteredSkills.isEmpty {
            SkillLibraryEmptyState(
                title: searchText.isEmpty ? "No Skills Installed" : "No Matches",
                systemImage: searchText.isEmpty ? "square.stack.3d.up.slash" : "magnifyingglass",
                description: searchText.isEmpty
                    ? "Install skills from the Skill Store to extend your agents' capabilities."
                    : "Try a different search term."
            )
        } else {
            skillBrowser
        }
    }

    private var skillBrowser: some View {
        SkillLibraryBrowser {
            skillListPane
        } detail: {
            skillDetailPane
        }
    }

    private var skillListPane: some View {
        VStack(spacing: 0) {
            if isLoading && !installedSkills.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing installations…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
            }

            List {
                installedSection(title: "Project", skills: projectSkills)
                installedSection(title: "Global", skills: globalSkills)
            }
            .listStyle(.inset(alternatesRowBackgrounds: false))
            .scrollContentBackground(.hidden)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private func installedSection(title: String, skills: [InstalledSkillSnapshot]) -> some View {
        if !skills.isEmpty {
            Section(title) {
                ForEach(skills) { skill in
                    Button {
                        selectedSkillID = skill.id
                    } label: {
                        InstalledSkillListRow(
                            skill: skill,
                            isRemoving: removingSkillIDs.contains(skill.id),
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

    @ViewBuilder
    private var skillDetailPane: some View {
        if let selectedSkill {
            ScrollView {
                InstalledSkillDetailPane(
                    skill: selectedSkill,
                    linkedDraft: linkedDraft(for: selectedSkill),
                    agentVisibility: agentVisibility,
                    isLoadingVisibility: isLoadingVisibility,
                    sourceIntegrity: sourceIntegrity,
                    isLoadingIntegrity: isLoadingIntegrity,
                    isAdding: addingSkillIDs.contains(selectedSkill.id),
                    isRemoving: removingSkillIDs.contains(selectedSkill.id),
                    onEditDraft: {
                        openDraft(for: selectedSkill)
                    },
                    onAddAgents: { agents in
                        addSkillTargets(selectedSkill, agents: agents)
                    },
                    onRemoveAll: {
                        pendingRemoval = PendingRemoval(skill: selectedSkill, targetAgents: nil)
                    },
                    onRemoveAgent: { agent in
                        pendingRemoval = PendingRemoval(skill: selectedSkill, targetAgents: [agent])
                    },
                    onOpenSourcePage: {
                        guard let urlString = selectedSkill.url,
                              let url = URL(string: urlString) else {
                            return
                        }
                        NSWorkspace.shared.open(url)
                    }
                )
                .padding(24)
            }
        } else {
            SkillLibraryEmptyState(
                title: "No Skill Selected",
                systemImage: "square.stack.3d.up.slash",
                description: "Choose an installed skill to inspect where it is active and remove it safely."
            )
        }
    }

    @ViewBuilder
    private var nonFatalErrorBanner: some View {
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

    private func removalMessage(for pending: PendingRemoval) -> String {
        let targetText: String
        if let agents = pending.targetAgents, let first = agents.first {
            targetText = " from \(first.displayName)"
        } else {
            targetText = ""
        }
        return "Are you sure you want to remove \"\(pending.skill.displayName)\"\(targetText)? This will uninstall it from your \(pending.skill.isGlobal ? "global" : "project") configuration."
    }

    private func fetchInstalledSkills() {
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
                // Reload security audits after the list refreshes. This covers the case where the
                // same skill stays selected (selectedSkillID unchanged) and task(id:) would
                // not fire automatically.
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

    private func removeSkill(
        _ skill: InstalledSkillSnapshot,
        targetAgents: [AgentWorkflow]? = nil
    ) {
        withAnimation(.easeInOut(duration: 0.2)) {
            removingSkillIDs.insert(skill.id)
            errorMessage = nil
        }

        Task {
            do {
                workspaceSnapshot = try await workspaceService.removeInstalledSkill(
                    skill,
                    targetAgents: targetAgents,
                    authoredDraftCount: skillDrafts.count
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

    private func addSkillTargets(
        _ skill: InstalledSkillSnapshot,
        agents: [AgentWorkflow]
    ) {
        guard !agents.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            addingSkillIDs.insert(skill.id)
            errorMessage = nil
        }

        Task {
            do {
                workspaceSnapshot = try await workspaceService.addInstalledSkillTargets(
                    skill,
                    targetAgents: agents,
                    authoredDraftCount: skillDrafts.count
                )
                syncSelection()
                _ = withAnimation(.easeInOut(duration: 0.2)) {
                    addingSkillIDs.remove(skill.id)
                }
            } catch {
                withAnimation {
                    addingSkillIDs.remove(skill.id)
                    errorMessage = "Failed to update \(skill.displayName): \(workspaceService.userFacingErrorMessage(for: error))"
                }
            }
        }
    }

    private func linkedDraft(for skill: InstalledSkillSnapshot) -> Skill? {
        draftService.matchingDraft(for: skill, in: skillDrafts)
    }

    private func openDraft(for installedSkill: InstalledSkillSnapshot) {
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

    private func syncSelection() {
        if !filteredSkills.contains(where: { $0.id == selectedSkillID }) {
            selectedSkillID = filteredSkills.first?.id
        }
    }

    private func chooseProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the project folder whose CLI skill roots should be managed."

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        workspaceService.setSelectedProjectRootURL(selectedURL)
    }

    private func draftServiceErrorMessage(for error: Error, skill: InstalledSkillSnapshot) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription, !localized.isEmpty {
            return "Failed to open \(skill.displayName) as a draft: \(localized)"
        }
        return "Failed to open \(skill.displayName) as a draft."
    }
}

private struct InstalledSkillListRow: View {
    let skill: InstalledSkillSnapshot
    let isRemoving: Bool
    let isSelected: Bool
    @State private var isHovered = false

    private var scopeColor: Color {
        skill.isGlobal ? .blue : .mint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(skill.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if isRemoving {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer()
            }

            if let source = skill.displaySource {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(skill.summary.isEmpty ? "No summary available" : skill.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 6) {
                InstalledSkillBadge(
                    title: skill.isGlobal ? "Global" : "Project",
                    icon: skill.isGlobal ? "globe" : "folder",
                    foreground: scopeColor,
                    background: scopeColor.opacity(0.14)
                )

                if !skill.agents.isEmpty {
                    InstalledSkillBadge(
                        title: "\(skill.agents.count) CLI\(skill.agents.count == 1 ? "" : "s")",
                        icon: "terminal",
                        foreground: .secondary,
                        background: Color.secondary.opacity(0.12)
                    )
                }

                if !skill.isManagedByPromptHub {
                    InstalledSkillBadge(
                        title: "External",
                        icon: "arrow.triangle.branch",
                        foreground: .orange,
                        background: Color.orange.opacity(0.14)
                    )
                }
            }
        }
        .padding(12)
        .modifier(SkillLibraryRowCardStyle(isSelected: isSelected, isHovered: isHovered))
        .opacity(isRemoving ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct InstalledSkillDetailPane: View {
    let skill: InstalledSkillSnapshot
    let linkedDraft: Skill?
    let agentVisibility: [SkillAgentVisibility]
    let isLoadingVisibility: Bool
    let sourceIntegrity: SkillSourceIntegrity?
    let isLoadingIntegrity: Bool
    let isAdding: Bool
    let isRemoving: Bool
    let onEditDraft: () -> Void
    let onAddAgents: ([AgentWorkflow]) -> Void
    let onRemoveAll: () -> Void
    let onRemoveAgent: (AgentWorkflow) -> Void
    let onOpenSourcePage: () -> Void

    private let iconSymbols = [
        "shippingbox.fill",
        "terminal.fill",
        "server.rack",
        "folder.badge.gearshape",
        "square.stack.3d.up.fill",
        "globe.americas.fill"
    ]

    private let iconColors: [Color] = [
        .blue,
        .green,
        .orange,
        .teal,
        .indigo,
        .mint
    ]

    private var formattedAgents: String {
        if skill.agents.isEmpty {
            return skill.isManagedByPromptHub ? "No CLI targets recorded" : "External local skill"
        }
        return skill.agents.map(\.displayName).joined(separator: ", ")
    }

    @ViewBuilder
    private var agentVisibilitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Agent Visibility")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoadingVisibility {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if agentVisibility.isEmpty && !isLoadingVisibility {
                Text("Visibility scan not available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(agentVisibility, id: \.agent.rawValue) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: entry.status == .visible ? "checkmark.circle.fill" : (entry.status == .missing ? "xmark.circle.fill" : "questionmark.circle.fill"))
                                .foregroundStyle(entry.status == .visible ? Color.green : (entry.status == .missing ? Color.red : Color.secondary))
                                .font(.system(size: 13))
                            Text(entry.agent.displayName)
                                .font(.callout)
                            Spacer()
                            Text(entry.status == .visible ? "Visible" : (entry.status == .missing ? "Missing" : "Unknown path"))
                                .font(.caption)
                                .foregroundStyle(entry.status == .visible ? Color.green : (entry.status == .missing ? Color.red : Color.secondary))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        if entry.agent != agentVisibility.last?.agent {
                            Divider()
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
            }
        }
    }

    private var addableAgents: [AgentWorkflow] {
        AgentWorkflow.defaultTargets.filter { !skill.agents.contains($0) }
    }

    private var supportsAddTargets: Bool {
        !addableAgents.isEmpty
    }

    @ViewBuilder
    private var sourceIntegritySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Source Integrity")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoadingIntegrity {
                    ProgressView()
                        .controlSize(.mini)
                }
            }

            if isLoadingIntegrity && sourceIntegrity == nil {
                Text("Checking source…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let integrity = sourceIntegrity {
                VStack(spacing: 0) {
                    integrityStatusRow(integrity)
                    Divider()
                    if let hash = integrity.localHash {
                        integrityInfoRow(label: "Local SHA-256", value: String(hash.prefix(16)) + "…", fullValue: hash)
                    }
                    if let remoteHash = integrity.remoteHash {
                        Divider()
                        integrityInfoRow(label: "Remote SHA-256", value: String(remoteHash.prefix(16)) + "…", fullValue: remoteHash)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
            } else if !isLoadingIntegrity {
                Text("Integrity check not available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func integrityStatusRow(_ integrity: SkillSourceIntegrity) -> some View {
        let (icon, label, color): (String, String, Color) = {
            switch integrity.status {
            case .verified:
                return ("checkmark.shield.fill", "Verified — matches remote", .green)
            case .modified:
                return ("exclamationmark.shield.fill", "Modified — differs from remote", .orange)
            case .remoteUnavailable:
                return ("wifi.slash", "Remote unavailable (offline check)", .secondary)
            case .noRemoteSource:
                return ("internaldrive", "Local-only skill, no remote source", .secondary)
            case .notInstalled:
                return ("xmark.circle", "SKILL.md not found locally", .red)
            }
        }()
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 13))
            Text(label)
                .font(.callout)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    @ViewBuilder
    private func integrityInfoRow(label: String, value: String, fullValue: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.primary)
                .help(fullValue ?? value)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    var body: some View {
        SkillLibraryInspectorCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 18) {
                    Image(systemName: iconSymbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 56, height: 56)
                        .background(iconColor.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(skill.displayName)
                            .font(.title2.weight(.semibold))

                        if let source = skill.displaySource {
                            Text(source)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 6) {
                            InstalledSkillBadge(
                                title: skill.isGlobal ? "Global" : "Project",
                                icon: skill.isGlobal ? "globe" : "folder",
                                foreground: skill.isGlobal ? .blue : .mint,
                                background: (skill.isGlobal ? Color.blue : Color.mint).opacity(0.14)
                            )

                            InstalledSkillBadge(
                                title: skill.isManagedByPromptHub ? "PromptHub Managed" : "External",
                                icon: skill.isManagedByPromptHub ? "checkmark.circle" : "arrow.triangle.branch",
                                foreground: skill.isManagedByPromptHub ? .green : .orange,
                                background: (skill.isManagedByPromptHub ? Color.green : Color.orange).opacity(0.14)
                            )
                        }
                    }

                    Spacer()
                }

                Text(skill.summary.isEmpty ? "No summary was recorded for this installed skill." : skill.summary)
                    .font(.body)
                    .foregroundStyle(.secondary)

                SkillLibraryMetadataBlock(
                    title: "Availability",
                    rows: [
                        ("Scope", skill.scope.displayName),
                        ("CLIs", formattedAgents)
                    ]
                )

                agentVisibilitySection

                sourceIntegritySection

                SkillLibraryMetadataBlock(
                    title: "Package",
                    rows: [
                        ("Identifier", skill.package.rawValue),
                        ("Managed", skill.isManagedByPromptHub ? "PromptHub managed" : "External install")
                    ]
                )

                HStack(spacing: 10) {
                    Button(linkedDraft == nil ? "Duplicate to Draft" : "Open Draft", action: onEditDraft)
                        .buttonStyle(.borderedProminent)

                    if isAdding {
                        Label("Updating CLIs…", systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    } else if supportsAddTargets {
                        Menu {
                            if addableAgents.count > 1 {
                                Button {
                                    onAddAgents(addableAgents)
                                } label: {
                                    Label("Add All Missing CLIs", systemImage: "plus.circle")
                                }
                            }

                            ForEach(addableAgents, id: \.rawValue) { agent in
                                Button {
                                    onAddAgents([agent])
                                } label: {
                                    Label("Add \(agent.displayName)", systemImage: "plus")
                                }
                            }
                        } label: {
                            Label("Add CLI", systemImage: "plus")
                        }
                        .menuStyle(.borderedButton)
                    }

                    if isRemoving {
                        Label("Removing…", systemImage: "hourglass")
                            .foregroundStyle(.secondary)
                    } else {
                        Menu {
                            Button(role: .destructive) {
                                onRemoveAll()
                            } label: {
                                Label("Remove from All CLIs", systemImage: "trash")
                            }

                            if !skill.agents.isEmpty {
                                Section("Remove from CLI") {
                                    ForEach(skill.agents, id: \.rawValue) { agent in
                                        Button(role: .destructive) {
                                            onRemoveAgent(agent)
                                        } label: {
                                            Label(agent.displayName, systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Label("Manage CLIs", systemImage: "slider.horizontal.3")
                        }
                        .menuStyle(.borderedButton)
                    }

                    if skill.url != nil {
                        Button("Open Source Page", action: onOpenSourcePage)
                            .buttonStyle(.bordered)
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var iconSeed: Int {
        skill.displayName.unicodeScalars.reduce(0) { partial, scalar in
            partial + Int(scalar.value)
        }
    }

    private var iconSymbol: String {
        iconSymbols[iconSeed % iconSymbols.count]
    }

    private var iconColor: Color {
        iconColors[iconSeed % iconColors.count]
    }
}

private struct InstalledSkillBadge: View {
    let title: String
    let icon: String
    let foreground: Color
    let background: Color

    var body: some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}
