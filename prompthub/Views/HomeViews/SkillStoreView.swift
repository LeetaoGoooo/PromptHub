import SwiftUI
import Observation
import AppKit
import UniformTypeIdentifiers
import PromptHubSkillKit
import SwiftData
import AlertToast

struct SkillStoreView: View {
    private let workspaceService = SkillWorkspaceService.shared
    @Query(sort: \Skill.updatedAt, order: .reverse) private var skillDrafts: [Skill]

    private struct PendingCatalogInstall: Identifiable {
        let id = UUID()
        let skill: CatalogSkill
        let installationState: CatalogSkillInstallationState
        let preferredScope: SkillInstallScope
    }

    let searchText: String
    @State private var isLoading = false
    @State private var workspaceSnapshot = SkillStoreWorkspaceSnapshot.empty
    @State private var errorMessage: String?
    @State private var selectedSkillID: String?
    @State private var isInstallingLocalSkill = false
    @ObservedObject private var cliAccessManager = CLIDirectoryAccessManager.shared
    @State private var showingCLIAccessManager = false
    @State private var showingPrivateSourceInstall = false
    
    // Per-card install state
    @State private var installingSkillIDs: Set<String> = []
    @State private var recentlyInstalledIDs: Set<String> = []
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastType: AlertToast.AlertType = .regular
    @State private var pendingInstall: PendingCatalogInstall?
    
    // Search debounce
    @State private var searchTask: Task<Void, Never>?
    
    private var availableSkills: [CatalogSkill] {
        workspaceSnapshot.catalogSkills
    }

    private var installedSkills: [InstalledSkillSnapshot] {
        workspaceSnapshot.installedSkills
    }

    private var installationRegistry: [String: CatalogSkillInstallationState] {
        workspaceSnapshot.installationRegistry
    }

    private var selectedSkill: CatalogSkill? {
        if let selectedSkillID,
           let matched = availableSkills.first(where: { $0.id == selectedSkillID }) {
            return matched
        }
        return availableSkills.first
    }

    private var headerMetrics: [SkillLibraryMetric] {
        [
            SkillLibraryMetric(
                value: "\(workspaceSnapshot.summary.catalogCount)",
                title: "Discover",
                systemImage: "sparkles"
            ),
            SkillLibraryMetric(
                value: "\(workspaceSnapshot.summary.installedCount)",
                title: "Installed",
                systemImage: "square.stack.3d.up"
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
            title: "Skill Store",
            subtitle: "Discover reusable skills, inspect installation coverage, and bring local SKILL.md packages into your workspace without leaving PromptHub.",
            metrics: headerMetrics
        ) {
            HStack(spacing: 10) {
                if isInstallingLocalSkill {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    fetchSkills(query: searchText)
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

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

                Menu {
                    Section("Install Local Skill") {
                        Button {
                            installLocalSkill(isGlobal: false)
                        } label: {
                            Label("Project Scope", systemImage: "folder.badge.plus")
                        }

                        Button {
                            installLocalSkill(isGlobal: true)
                        } label: {
                            Label("Global Scope", systemImage: "globe")
                        }
                    }

                    Section("Private Sources") {
                        Button {
                            showingPrivateSourceInstall = true
                        } label: {
                            Label("Install from Private Source…", systemImage: "lock.shield")
                        }
                    }
                } label: {
                    Label("Import", systemImage: "plus.circle")
                }
                .menuStyle(.borderedButton)

                Button(action: { showingCLIAccessManager = true }) {
                    Label("CLI Access", systemImage: "lock.shield")
                }
                .buttonStyle(.bordered)
            }
        } content: {
            if isLoading && availableSkills.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Loading skills catalog...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, availableSkills.isEmpty {
                SkillLibraryEmptyState(
                    title: "Connection Error",
                    systemImage: "exclamationmark.triangle.fill",
                    description: error
                ) {
                    Button("Retry") {
                        fetchSkills(query: searchText)
                    }
                    .buttonStyle(.borderedProminent)
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
                    Button("Configure Access\u{2026}") {
                        showingCLIAccessManager = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                skillBrowser
            }
        }
        .onChange(of: searchText) { _, newValue in
            debouncedSearch(query: newValue)
        }
        .sheet(isPresented: $showingCLIAccessManager, onDismiss: {
            fetchSkills(query: searchText)
        }) {
            CLIAccessManagerView()
        }
        .sheet(isPresented: $showingPrivateSourceInstall, onDismiss: {
            fetchSkills(query: searchText)
        }) {
            PrivateSourceInstallSheet()
        }
        .onAppear {
            fetchSkills()
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillInstallationsDidChange)) { _ in
            fetchSkills(query: searchText)
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillProjectSelectionDidChange)) { _ in
            fetchSkills(query: searchText)
        }
        .alert("Skill Store", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastMessage)
        }
        .sheet(item: $pendingInstall) { pending in
            CatalogSkillInstallSheet(
                skill: pending.skill,
                installationState: pending.installationState,
                initialScope: pending.preferredScope,
                initialProjectRootURL: workspaceService.selectedProjectRootURL
            ) { scope, agents, projectRootURL in
                if scope == .project {
                    workspaceService.setSelectedProjectRootURL(projectRootURL)
                }
                pendingInstall = nil
                installSkill(pending.skill, scope: scope, targetAgents: agents)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Helpers

    private var skillBrowser: some View {
        SkillLibraryBrowser {
            skillListPane
        } detail: {
            skillDetailPane
        }
    }

    private var skillListPane: some View {
        VStack(spacing: 0) {
            if isLoading && !availableSkills.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Refreshing catalog…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
            }

            List {
                ForEach(availableSkills) { skill in
                    let installationInfo = workspaceService.installationState(
                        for: skill,
                        registry: installationRegistry
                    )

                    Button {
                        selectedSkillID = skill.id
                    } label: {
                        SkillStoreListRow(
                            skill: skill,
                            installationState: installationInfo,
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
    private var skillDetailPane: some View {
        if let selectedSkill {
            let installationInfo = workspaceService.installationState(
                for: selectedSkill,
                registry: installationRegistry
            )

            ScrollView {
                SkillStoreDetailPane(
                    skill: selectedSkill,
                    installationState: installationInfo,
                    isInstalling: installingSkillIDs.contains(selectedSkill.id),
                    justInstalled: recentlyInstalledIDs.contains(selectedSkill.id),
                    onConfigureInstall: { preferredScope in
                        pendingInstall = PendingCatalogInstall(
                            skill: selectedSkill,
                            installationState: installationInfo,
                            preferredScope: preferredScope
                        )
                    },
                    onRemove: { scope in
                        removeInstalledSkill(selectedSkill, scope: scope)
                    },
                    onOpenSourcePage: {
                        openSourcePage(for: selectedSkill)
                    }
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
        guard cliAccessManager.anyAccessGranted else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                workspaceSnapshot = try await workspaceService.loadSkillStore(
                    query: query,
                    authoredDraftCount: skillDrafts.count
                )
                if !availableSkills.contains(where: { $0.id == selectedSkillID }) {
                    selectedSkillID = availableSkills.first?.id
                }
            } catch {
                errorMessage = workspaceService.userFacingErrorMessage(for: error)
            }

            isLoading = false
        }
    }

    private func installSkill(
        _ skill: CatalogSkill,
        scope: SkillInstallScope,
        targetAgents: [AgentWorkflow]
    ) {
        let wasInstalled = installationRegistry[skill.package.normalizedKey]?.isInstalled == true

        _ = withAnimation(.easeInOut(duration: 0.2)) {
            installingSkillIDs.insert(skill.id)
        }

        Task {
            do {
                let snapshot = try await workspaceService.installCatalogSkill(
                    skill,
                    query: searchText,
                    scope: scope,
                    targetAgents: targetAgents,
                    authoredDraftCount: skillDrafts.count,
                    existingSnapshot: workspaceSnapshot
                )
                workspaceSnapshot = snapshot

                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    installingSkillIDs.remove(skill.id)
                    recentlyInstalledIDs.insert(skill.id)
                }

                showToastMessage(
                    "\(wasInstalled ? "Updated" : "Installed") \(skill.displayName) in \(scope.displayName.lowercased())",
                    .complete(.green)
                )
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    _ = withAnimation(.easeOut(duration: 0.3)) {
                        recentlyInstalledIDs.remove(skill.id)
                    }
                }

            } catch {
                _ = withAnimation {
                    installingSkillIDs.remove(skill.id)
                }
                errorMessage = "Failed to install \(skill.displayName): \(workspaceService.userFacingErrorMessage(for: error))"
            }
        }
    }

    private func removeInstalledSkill(
        _ skill: CatalogSkill,
        scope: SkillInstallScope
    ) {
        Task {
            do {
                let snapshot = try await workspaceService.removeCatalogSkill(
                    skill,
                    query: searchText,
                    scope: scope,
                    installedSkills: installedSkills,
                    authoredDraftCount: skillDrafts.count,
                    existingSnapshot: workspaceSnapshot
                )
                workspaceSnapshot = snapshot
                showToastMessage(
                    "Removed \(skill.displayName) from \(scope.displayName.lowercased())",
                    .complete(.green)
                )
            } catch {
                errorMessage = "Failed to remove \(skill.displayName): \(workspaceService.userFacingErrorMessage(for: error))"
            }
        }
    }

    private func openSourcePage(for skill: CatalogSkill) {
        guard let urlString = skill.url,
              let url = URL(string: urlString) else {
            errorMessage = "Failed to open source page for \(skill.displayName)."
            return
        }

        NSWorkspace.shared.open(url)
    }

    private func installLocalSkill(isGlobal: Bool) {
        guard !isInstallingLocalSkill else { return }

        if !isGlobal && workspaceService.selectedProjectRootURL == nil {
            chooseProjectRoot()
            guard workspaceService.selectedProjectRootURL != nil else {
                return
            }
        }

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText]
        panel.message = "Select a local SKILL.md file or a skill directory"

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        isInstallingLocalSkill = true
        Task {
            defer { isInstallingLocalSkill = false }
            do {
                let snapshot = try await workspaceService.installLocalSkill(
                    at: selectedURL,
                    query: searchText,
                    scope: isGlobal ? .global : .project,
                    targetAgents: AgentWorkflow.defaultTargets,
                    authoredDraftCount: skillDrafts.count,
                    existingSnapshot: workspaceSnapshot
                )
                workspaceSnapshot = snapshot
                showToastMessage(
                    "Imported local skill into \((isGlobal ? SkillInstallScope.global : .project).displayName.lowercased())",
                    .complete(.green)
                )
            } catch {
                errorMessage = "Failed to install local skill: \(workspaceService.userFacingErrorMessage(for: error))"
            }
        }
    }

    @MainActor
    private func showToastMessage(_ message: String, _ type: AlertToast.AlertType) {
        toastMessage = message
        toastType = type
        showToast = true
    }

    private func chooseProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the project folder whose CLI skill roots should be used for project-scope installs."

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        workspaceService.setSelectedProjectRootURL(selectedURL)
    }
}

private struct SkillStoreListRow: View {
    let skill: CatalogSkill
    let installationState: CatalogSkillInstallationState
    let isInstalling: Bool
    let justInstalled: Bool
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(skill.displayName)
                    .font(.headline)
                    .lineLimit(1)

                if isInstalling {
                    ProgressView()
                        .controlSize(.small)
                } else if justInstalled || installationState.isInstalled {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                Spacer()
            }

            if let source = skill.displaySource {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(skill.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            SkillInstallationBadges(
                installationState: installationState,
                isInstalling: isInstalling,
                justInstalled: justInstalled
            )
        }
        .padding(12)
        .modifier(SkillLibraryRowCardStyle(isSelected: isSelected, isHovered: isHovered))
        .animation(.easeInOut(duration: 0.14), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

private struct SkillStoreDetailPane: View {
    let skill: CatalogSkill
    let installationState: CatalogSkillInstallationState
    let isInstalling: Bool
    let justInstalled: Bool
    let onConfigureInstall: (SkillInstallScope) -> Void
    let onRemove: (SkillInstallScope) -> Void
    let onOpenSourcePage: () -> Void

    private let iconSymbols = [
        "hammer.fill",
        "paintpalette.fill",
        "terminal.fill",
        "wand.and.stars",
        "cpu.fill",
        "shippingbox.fill",
        "doc.text.magnifyingglass"
    ]

    private let iconColors: [Color] = [
        .blue,
        .orange,
        .green,
        .pink,
        .mint,
        .indigo,
        .teal
    ]

    private let orderedScopes: [SkillInstallScope] = [.project, .global]

    private var canInstallMore: Bool {
        orderedScopes.contains { !missingAgents(for: $0).isEmpty }
    }

    private var preferredInstallScope: SkillInstallScope {
        if !missingAgents(for: .project).isEmpty {
            return .project
        }
        return .global
    }

    var body: some View {
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

                    SkillInstallationBadges(
                        installationState: installationState,
                        isInstalling: isInstalling,
                        justInstalled: justInstalled
                    )
                }

                Spacer()
            }

            Text(skill.summary)
                .font(.body)
                .foregroundStyle(.secondary)

            SkillLibraryMetadataBlock(
                title: "Availability",
                rows: [
                    ("Scopes", installationState.scopes.isEmpty ? "Not installed yet" : installationState.scopes.map(\.displayName).joined(separator: ", ")),
                    ("Project CLIs", cliDescription(for: .project)),
                    ("Global CLIs", cliDescription(for: .global))
                ]
            )

            SkillLibraryMetadataBlock(
                title: "Package",
                rows: [
                    ("Identifier", skill.package.rawValue),
                    ("Managed", skill.isManagedByPromptHub ? "PromptHub managed" : "External")
                ]
            )

            HStack(spacing: 10) {
                installActions

                if skill.url != nil {
                    Button("Open Source Page", action: onOpenSourcePage)
                        .buttonStyle(.bordered)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SkillStoreInspectorChrome())
    }

    @ViewBuilder
    private var installActions: some View {
        if isInstalling {
            Label("Installing…", systemImage: "hourglass")
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 10) {
                if canInstallMore {
                    Button {
                        onConfigureInstall(preferredInstallScope)
                    } label: {
                        Label(installationState.isInstalled ? "Configure Install…" : "Install…", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if !installationState.removableScopes.isEmpty {
                    Menu {
                        ForEach(installationState.removableScopes, id: \.rawValue) { scope in
                            Button(role: .destructive) {
                                onRemove(scope)
                            } label: {
                                Label("Remove \(scope.displayName)", systemImage: "trash")
                            }
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .menuStyle(.borderedButton)
                }
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

    private func cliDescription(for scope: SkillInstallScope) -> String {
        let agents = installationState.agentsByScope[scope] ?? []
        return agents.isEmpty ? "Not installed" : agents.map(\.displayName).joined(separator: ", ")
    }

    private func missingAgents(for scope: SkillInstallScope) -> [AgentWorkflow] {
        let installedAgents = Set(installationState.agentsByScope[scope] ?? [])
        return AgentWorkflow.defaultTargets.filter { !installedAgents.contains($0) }
    }
}

private struct CatalogSkillInstallSheet: View {
    let skill: CatalogSkill
    let installationState: CatalogSkillInstallationState
    let initialScope: SkillInstallScope
    let initialProjectRootURL: URL?
    let onConfirm: (SkillInstallScope, [AgentWorkflow], URL?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedScope: SkillInstallScope
    @State private var selectedAgents: Set<AgentWorkflow>
    @State private var selectedProjectRootURL: URL?

    init(
        skill: CatalogSkill,
        installationState: CatalogSkillInstallationState,
        initialScope: SkillInstallScope,
        initialProjectRootURL: URL?,
        onConfirm: @escaping (SkillInstallScope, [AgentWorkflow], URL?) -> Void
    ) {
        self.skill = skill
        self.installationState = installationState
        self.initialScope = initialScope
        self.initialProjectRootURL = initialProjectRootURL
        self.onConfirm = onConfirm

        let initialAgents = Self.missingAgents(
            for: initialScope,
            installationState: installationState
        )
        _selectedScope = State(initialValue: initialScope)
        _selectedAgents = State(initialValue: Set(initialAgents))
        _selectedProjectRootURL = State(initialValue: initialProjectRootURL)
    }

    private var availableAgents: [AgentWorkflow] {
        Self.missingAgents(for: selectedScope, installationState: installationState)
    }

    private var installedAgents: [AgentWorkflow] {
        installationState.agentsByScope[selectedScope] ?? []
    }

    private var confirmTitle: String {
        installationState.scopes.contains(selectedScope) ? "Add CLIs" : "Install Skill"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(confirmTitle)
                            .font(.title3.weight(.semibold))
                        Text(skill.displayName)
                            .font(.headline)
                        Text("Choose where this skill should live first, then select the CLI environments that should receive it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Scope")
                            .font(.headline)

                        Picker("Scope", selection: $selectedScope) {
                            Text("Project").tag(SkillInstallScope.project)
                            Text("Global").tag(SkillInstallScope.global)
                        }
                        .pickerStyle(.segmented)

                        Text("Project scope installs into the selected project's CLI skill roots.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                        if selectedScope == .project {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Project")
                                    .font(.headline)

                            HStack(spacing: 10) {
                                Text(selectedProjectRootURL?.path ?? "No project selected")
                                    .font(.subheadline)
                                    .foregroundStyle(selectedProjectRootURL == nil ? .secondary : .primary)
                                    .lineLimit(2)
                                    .textSelection(.enabled)

                                Spacer()

                                Button("Choose…") {
                                    chooseProjectRoot()
                                }
                                .buttonStyle(.bordered)
                            }

                            if selectedProjectRootURL == nil {
                                Label("Choose a writable project folder before installing in project scope.", systemImage: "exclamationmark.triangle")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("CLI Targets")
                            .font(.headline)

                        if !installedAgents.isEmpty {
                            Text("Already installed in \(selectedScope.displayName.lowercased()): \(installedAgents.map(\.displayName).joined(separator: ", ")).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if availableAgents.isEmpty {
                            ContentUnavailableView(
                                "Nothing to Add",
                                systemImage: "checkmark.circle",
                                description: Text("All supported CLIs already have this skill in \(selectedScope.displayName.lowercased()) scope.")
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                if availableAgents.count > 1 {
                                    HStack {
                                        Button("Select All") {
                                            selectedAgents = Set(availableAgents)
                                        }
                                        .buttonStyle(.link)

                                        Button("Clear") {
                                            selectedAgents = []
                                        }
                                        .buttonStyle(.link)

                                        Spacer()
                                    }
                                }

                                ForEach(availableAgents, id: \.rawValue) { agent in
                                    Toggle(isOn: binding(for: agent)) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(agent.displayName)
                                            Text(agent.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                }
                            }
                            .padding(14)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button(confirmTitle) {
                    onConfirm(
                        selectedScope,
                        availableAgents.filter { selectedAgents.contains($0) },
                        selectedProjectRootURL
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedAgents.isEmpty || (selectedScope == .project && selectedProjectRootURL == nil))
            }
        }
        .padding(24)
        .frame(width: 480, height: 520)
        .onChange(of: selectedScope) { _, newScope in
            selectedAgents = Set(Self.missingAgents(for: newScope, installationState: installationState))
        }
    }

    private func binding(for agent: AgentWorkflow) -> Binding<Bool> {
        Binding(
            get: { selectedAgents.contains(agent) },
            set: { isEnabled in
                if isEnabled {
                    selectedAgents.insert(agent)
                } else {
                    selectedAgents.remove(agent)
                }
            }
        )
    }

    private func chooseProjectRoot() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose the project folder for this project-scope skill install."

        guard panel.runModal() == .OK, let selectedURL = panel.url else {
            return
        }

        selectedProjectRootURL = selectedURL
    }

    private static func missingAgents(
        for scope: SkillInstallScope,
        installationState: CatalogSkillInstallationState
    ) -> [AgentWorkflow] {
        let installedAgents = Set(installationState.agentsByScope[scope] ?? [])
        return AgentWorkflow.defaultTargets.filter { !installedAgents.contains($0) }
    }
}

private struct SkillStoreInspectorChrome: ViewModifier {
    func body(content: Content) -> some View {
        SkillLibraryInspectorCard {
            content
        }
    }
}

private struct SkillInstallationBadges: View {
    let installationState: CatalogSkillInstallationState
    let isInstalling: Bool
    let justInstalled: Bool

    var body: some View {
        if isInstalling {
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Installing…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(spacing: 6) {
                if justInstalled || installationState.isInstalled {
                    skillBadge(
                        title: "Installed",
                        icon: "checkmark.circle.fill",
                        foreground: .green,
                        background: .green.opacity(0.14)
                    )
                } else {
                    skillBadge(
                        title: "Available",
                        icon: "sparkles",
                        foreground: .secondary,
                        background: Color.secondary.opacity(0.12)
                    )
                }

                ForEach(sortedScopes, id: \.rawValue) { scope in
                    skillBadge(
                        title: scope.displayName,
                        icon: scope == .global ? "globe" : "folder",
                        foreground: scope == .global ? .blue : .mint,
                        background: (scope == .global ? Color.blue : Color.mint).opacity(0.14)
                    )
                }
            }
        }
    }

    private var sortedScopes: [SkillInstallScope] {
        installationState.scopes.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case (.project, .global):
                return true
            case (.global, .project):
                return false
            default:
                return lhs.rawValue < rhs.rawValue
            }
        }
    }

    private func skillBadge(
        title: String,
        icon: String,
        foreground: Color,
        background: Color
    ) -> some View {
        Label(title, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(Capsule())
    }
}
