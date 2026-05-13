import AppKit
import PromptHubSkillKit
import SwiftUI

extension SkillDraftDetailView {

    var workspaceHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(skill.displayName)
                    .font(.title2.weight(.semibold))
                Text("Package-first authoring workspace for SKILL.md, scripts, assets, and support files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if hasUnsavedChanges {
                Text("Unsaved Changes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12), in: Capsule())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    var packageSidebar: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Package")
                        .font(.headline)
                    Text(packageRootPath ?? "Preparing package…")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Button(action: { loadPackageWorkspace(resetSelection: false) }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Reload package files")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            if isLoadingPackage && packageItems.isEmpty {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.large)
                    Text("Loading package…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if packageItems.isEmpty {
                SkillLibraryEmptyState(
                    title: "No Package Files",
                    systemImage: "folder",
                    description: "Create SKILL.md support files like scripts and assets from the package sidebar."
                ) {
                    Button("New Text File") {
                        newItemKind = .file
                        newItemName = ""
                        showingNewItemSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(packageItems) { item in
                            DraftPackageSidebarRow(
                                item: item,
                                selectedRelativePath: $selectedRelativePath,
                                expandedDirectories: $expandedDirectories,
                                onSelect: { selectedItem in
                                    selectPackageItem(selectedItem)
                                }
                            )
                        }
                    }
                    .padding(10)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    var editorPane: some View {
        VStack(spacing: 0) {
            editorHeader

            Divider()

            Group {
                if let selectedPackageItem {
                    if selectedPackageItem.isDirectory {
                        selectedFolderOverview(selectedPackageItem)
                    } else if selectedItemIsEditableText {
                        TextEditor(text: $editorText)
                            .font(.system(.body, design: .monospaced))
                            .padding(14)
                            .scrollContentBackground(.hidden)
                            .background(Color(NSColor.textBackgroundColor))
                            .onChange(of: editorText) { _, newValue in
                                if selectedRelativePath == "SKILL.md" {
                                    instructionsText = newValue
                                }
                                if newValue != persistedEditorText {
                                    toastTitle = ""
                                }
                            }
                    } else {
                        nonTextFileFallback(selectedPackageItem)
                    }
                } else {
                    SkillLibraryEmptyState(
                        title: "No File Selected",
                        systemImage: "doc.text",
                        description: "Choose a package file from the sidebar to inspect or edit it."
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var editorHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedPackageItem?.displayName ?? "No File Selected")
                    .font(.headline)
                if let selectedPackageItem {
                    Text(selectedPackageItem.relativePath.isEmpty ? "/" : selectedPackageItem.relativePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if let selectedPackageItem, !selectedPackageItem.isDirectory, !selectedItemIsEditableText {
                Text("Open externally")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            if hasUnsavedChanges {
                Button("Revert") {
                    editorText = persistedEditorText
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    saveSelectedFile()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    func selectedFolderOverview(_ item: SkillDraftPackageItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.displayName)
                .font(.title3.weight(.semibold))
            Text("This folder is part of the skill package. Add files here for scripts, assets, tests, or docs, then open them inline or in Finder.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SkillLibraryMetadataBlock(title: "Folder", rows: [
                ("Path", item.relativePath),
                ("Children", "\(item.children.count) items")
            ])

            HStack(spacing: 10) {
                Button("New Text File") {
                    newItemKind = .file
                    newItemName = ""
                    showingNewItemSheet = true
                }
                .buttonStyle(.borderedProminent)

                Button("New Folder") {
                    newItemKind = .folder
                    newItemName = ""
                    showingNewItemSheet = true
                }
                .buttonStyle(.bordered)

                Button("Reveal in Finder") {
                    revealSelectedItemInFinder()
                }
                .buttonStyle(.bordered)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    func nonTextFileFallback(_ item: SkillDraftPackageItem) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.displayName)
                .font(.title3.weight(.semibold))
            Text("This file is better handled by the default macOS app for its type. Use Quick Look, Finder, or your preferred editor for binary or specialized formats.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SkillLibraryMetadataBlock(title: "File", rows: [
                ("Path", item.relativePath),
                ("Kind", "External editor")
            ])

            HStack(spacing: 10) {
                Button("Open Externally") {
                    openSelectedItemExternally()
                }
                .buttonStyle(.borderedProminent)

                Button("Reveal in Finder") {
                    revealSelectedItemInFinder()
                }
                .buttonStyle(.bordered)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
    }

    var inspectorPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SkillLibraryInspectorCard {
                    PHSectionHead(systemImage: "slider.horizontal.3", label: "Inspector")
                    SkillLibraryMetadataBlock(title: "Draft", rows: [
                        ("Name", skill.displayName),
                        ("Category", skill.category),
                        ("Identifier", skill.identifier.isEmpty ? "Not set" : skill.identifier),
                        ("Tags", skill.tags.isEmpty ? "None" : skill.tags.joined(separator: ", "))
                    ])
                }

                SkillLibraryInspectorCard {
                    PHSectionHead(systemImage: "shippingbox", label: "Package")
                    SkillLibraryMetadataBlock(title: "Workspace", rows: [
                        ("Root", packageRootPath ?? "Unavailable"),
                        ("Selection", selectedRelativePath.isEmpty ? "/" : selectedRelativePath),
                        ("Files", "\(flatPackageItems.count) items")
                    ])
                }

                SkillLibraryInspectorCard {
                    PHSectionHead(systemImage: "sparkles", label: "Actions")
                    VStack(alignment: .leading, spacing: 10) {
                        Button(action: installDraft) {
                            if isInstalling {
                                ProgressView().controlSize(.small)
                            } else {
                                Label("Install Package", systemImage: "arrow.down.circle")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isInstalling)

                        Button(action: createVersionSnapshot) {
                            Label("Save Version Snapshot", systemImage: "square.stack.3d.up.fill")
                        }
                        .buttonStyle(.bordered)

                        Button(action: copySkillMarkdown) {
                            Label("Copy SKILL.md", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.bordered)

                        if selectedPackageItem != nil {
                            Button(action: revealSelectedItemInFinder) {
                                Label("Reveal in Finder", systemImage: "finder")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                SkillLibraryInspectorCard {
                    PHSectionHead(systemImage: "arrow.down.circle", label: "Install")
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Scope", selection: $installScope) {
                            Text("Project").tag(SkillInstallScope.project)
                            Text("Global").tag(SkillInstallScope.global)
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Target Agents")
                                .font(.subheadline.weight(.medium))
                            ForEach(AgentWorkflow.allCases, id: \.rawValue) { agent in
                                Toggle(agent.displayName, isOn: Binding(
                                    get: { selectedAgents.contains(agent) },
                                    set: { enabled in
                                        if enabled {
                                            selectedAgents.insert(agent)
                                        } else {
                                            selectedAgents.remove(agent)
                                        }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                            }
                        }
                    }
                }

                SkillLibraryInspectorCard {
                    PHSectionHead(systemImage: "clock.arrow.circlepath", label: "Versions")
                    if skill.sortedVersions.isEmpty {
                        Text("No saved versions yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(skill.sortedVersions) { version in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Text(version.version)
                                            .font(.subheadline.monospaced().weight(.semibold))
                                        Spacer(minLength: 0)
                                        Button("Duplicate") {
                                            duplicateVersion(version)
                                        }
                                        .buttonStyle(.borderless)
                                    }

                                    Text(version.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    Text(version.instructions)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(3)
                                }
                                if version.id != skill.sortedVersions.last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.55))
    }

    var newItemSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("New \(newItemKind.title)")
                .font(.headline)

            Picker("Kind", selection: $newItemKind) {
                ForEach(SkillDraftPackageStore.NewItemKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.subheadline.weight(.medium))
                TextField(newItemKind == .file ? "example.sh" : "scripts", text: $newItemName)
                    .textFieldStyle(.roundedBorder)
            }

            if !selectionParentPath.isEmpty {
                SkillLibraryMetadataBlock(title: "Location", rows: [
                    ("Parent", selectionParentPath)
                ])
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    showingNewItemSheet = false
                }
                Button("Create") {
                    createPackageItem()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newItemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    var selectedPackageItem: SkillDraftPackageItem? {
        findItem(relativePath: selectedRelativePath, in: packageItems)
    }

    var hasUnsavedChanges: Bool {
        selectedItemIsEditableText && editorText != persistedEditorText
    }

    var selectionParentPath: String {
        guard let selectedPackageItem else { return "" }
        if selectedPackageItem.isDirectory {
            return selectedPackageItem.relativePath
        }
        let parentURL = selectedPackageItem.url.deletingLastPathComponent()
        return parentURL.lastPathComponent == skill.id.uuidString ? "" : parentURL.lastPathComponent
    }

    var packageRootPath: String? {
        try? draftService.ensurePackage(for: skill).path
    }

    var flatPackageItems: [SkillDraftPackageItem] {
        flatten(items: packageItems)
    }

    func loadPackageWorkspace(resetSelection: Bool) {
        do {
            isLoadingPackage = true
            let latestVersion = try draftService.ensureLatestVersion(for: skill, in: modelContext)
            syncEditorState(from: latestVersion)
            _ = try draftService.ensurePackage(for: skill)
            try? draftService.synchronizeDraftFromPackage(for: skill, in: modelContext)
            packageItems = try draftService.packageItems(for: skill)
            if resetSelection || findItem(relativePath: selectedRelativePath, in: packageItems) == nil {
                selectedRelativePath = preferredSelectionPath(from: packageItems) ?? "SKILL.md"
            }
            expandHierarchy(for: selectedRelativePath)
            loadSelectedItemContents()
            isLoadingPackage = false
        } catch {
            isLoadingPackage = false
            showToastMsg("Failed to load draft package: \(error.localizedDescription)")
        }
    }

    func selectPackageItem(_ item: SkillDraftPackageItem) {
        selectedRelativePath = item.relativePath
        expandHierarchy(for: item.relativePath)
        loadSelectedItemContents()
    }

    func loadSelectedItemContents() {
        guard let selectedPackageItem else {
            editorText = ""
            persistedEditorText = ""
            selectedItemIsEditableText = false
            return
        }

        if selectedPackageItem.isDirectory {
            editorText = ""
            persistedEditorText = ""
            selectedItemIsEditableText = false
            return
        }

        do {
            let isEditable = try draftService.isEditableTextFile(relativePath: selectedPackageItem.relativePath, for: skill)
            selectedItemIsEditableText = isEditable
            if isEditable {
                let contents = try draftService.readTextFile(relativePath: selectedPackageItem.relativePath, for: skill)
                editorText = contents
                persistedEditorText = contents
                if selectedPackageItem.relativePath == "SKILL.md" {
                    instructionsText = contents
                }
            } else {
                editorText = ""
                persistedEditorText = ""
            }
        } catch {
            selectedItemIsEditableText = false
            editorText = ""
            persistedEditorText = ""
            showToastMsg("Failed to load file: \(error.localizedDescription)")
        }
    }

    func saveSelectedFile() {
        guard let selectedPackageItem, !selectedPackageItem.isDirectory, selectedItemIsEditableText else {
            return
        }

        do {
            try draftService.saveEditedFile(
                relativePath: selectedPackageItem.relativePath,
                content: editorText,
                for: skill,
                in: modelContext
            )
            persistedEditorText = editorText
            if selectedPackageItem.relativePath == "SKILL.md" {
                instructionsText = skill.latestVersion?.instructions ?? editorText
            }
            loadPackageWorkspace(resetSelection: false)
            showToastMsg("Saved \(selectedPackageItem.displayName)", alertType: .complete(.green))
        } catch {
            showToastMsg("Failed to save file: \(error.localizedDescription)")
        }
    }

    func createPackageItem() {
        do {
            let createdPath = try draftService.createPackageItem(
                named: newItemName,
                kind: newItemKind,
                parentRelativePath: selectionParentPath.isEmpty ? nil : selectionParentPath,
                for: skill
            )
            showingNewItemSheet = false
            newItemName = ""
            loadPackageWorkspace(resetSelection: false)
            selectedRelativePath = createdPath
            loadSelectedItemContents()
            showToastMsg("Created \(newItemKind.title.lowercased())", alertType: .complete(.green))
        } catch {
            showToastMsg("Failed to create item: \(error.localizedDescription)")
        }
    }

    func revealSelectedItemInFinder() {
        do {
            try draftService.revealPackageItem(relativePath: selectedRelativePath, for: skill)
        } catch {
            showToastMsg("Failed to reveal item: \(error.localizedDescription)")
        }
    }

    func openSelectedItemExternally() {
        guard let selectedPackageItem else { return }
        do {
            try draftService.openPackageItemExternally(relativePath: selectedPackageItem.relativePath, for: skill)
        } catch {
            showToastMsg("Failed to open item: \(error.localizedDescription)")
        }
    }

    func preferredSelectionPath(from items: [SkillDraftPackageItem]) -> String? {
        if flatten(items: items).contains(where: { $0.relativePath == "SKILL.md" }) {
            return "SKILL.md"
        }
        return flatten(items: items).first(where: { !$0.isDirectory })?.relativePath
    }

    func flatten(items: [SkillDraftPackageItem]) -> [SkillDraftPackageItem] {
        items.flatMap { item in
            [item] + flatten(items: item.children)
        }
    }

    func findItem(relativePath: String, in items: [SkillDraftPackageItem]) -> SkillDraftPackageItem? {
        for item in items {
            if item.relativePath == relativePath {
                return item
            }
            if let child = findItem(relativePath: relativePath, in: item.children) {
                return child
            }
        }
        return nil
    }

    func expandHierarchy(for relativePath: String) {
        let components = relativePath.split(separator: "/").map(String.init)
        guard components.count > 1 else { return }
        var currentPath = ""
        for component in components.dropLast() {
            currentPath = currentPath.isEmpty ? component : currentPath + "/" + component
            expandedDirectories.insert(currentPath)
        }
    }
}

private struct DraftPackageSidebarRow: View {
    let item: SkillDraftPackageItem
    @Binding var selectedRelativePath: String
    @Binding var expandedDirectories: Set<String>
    let onSelect: (SkillDraftPackageItem) -> Void

    private var isSelected: Bool {
        selectedRelativePath == item.relativePath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if item.isDirectory {
                DisclosureGroup(isExpanded: isExpandedBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(item.children) { child in
                            DraftPackageSidebarRow(
                                item: child,
                                selectedRelativePath: $selectedRelativePath,
                                expandedDirectories: $expandedDirectories,
                                onSelect: onSelect
                            )
                            .padding(.leading, 14)
                        }
                    }
                    .padding(.top, 4)
                } label: {
                    rowLabel
                }
                .onTapGesture {
                    onSelect(item)
                }
            } else {
                Button {
                    onSelect(item)
                } label: {
                    rowLabel
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: item.isDirectory ? "folder" : symbolName(for: item))
                .foregroundStyle(item.isDirectory ? Color.accentColor : .secondary)
                .frame(width: 16)
            Text(item.displayName)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .modifier(SkillLibraryRowCardStyle(isSelected: isSelected, isHovered: false))
    }

    private var isExpandedBinding: Binding<Bool> {
        Binding(
            get: { expandedDirectories.contains(item.relativePath) },
            set: { expanded in
                if expanded {
                    expandedDirectories.insert(item.relativePath)
                } else {
                    expandedDirectories.remove(item.relativePath)
                }
            }
        )
    }

    private func symbolName(for item: SkillDraftPackageItem) -> String {
        switch item.url.pathExtension.lowercased() {
        case "md", "markdown":
            return "doc.text"
        case "sh", "command", "zsh", "bash":
            return "terminal"
        case "json", "yml", "yaml", "toml":
            return "curlybraces"
        case "png", "jpg", "jpeg", "gif", "webp", "svg":
            return "photo"
        default:
            return "doc"
        }
    }
}