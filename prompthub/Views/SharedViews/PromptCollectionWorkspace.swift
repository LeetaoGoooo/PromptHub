import AppKit
import MarkdownUI
import SwiftUI

struct PromptCollectionMetric: Hashable, Identifiable {
    let title: String
    let value: String
    let systemImage: String

    var id: Self { self }
}

struct PromptBrowserSection: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let items: [PromptBrowserItem]
}

struct PromptBrowserMetadataRow: Identifiable {
    let label: String
    let value: String

    var id: String { "\(label)-\(value)" }
}

struct PromptBrowserHistoryEntry: Identifiable {
    let id: String
    let versionLabel: String
    let timestamp: String
    let summary: String
    let isCurrent: Bool
    let onRestore: (() -> Void)?
}

enum PromptBrowserQuickActionEmphasis {
    case prominent
    case standard
}

struct PromptBrowserQuickAction: Identifiable {
    let id: String
    let title: String
    let systemImage: String
    let emphasis: PromptBrowserQuickActionEmphasis
    let isDisabled: Bool
    let onSelect: () -> Void
}

struct PromptBrowserItem: Identifiable {
    let id: String
    let title: String
    let summary: String
    let promptText: String
    let systemImage: String
    let iconTint: Color
    let badges: [PromptCollectionFooterBadge]
    let trailingDetail: String?
    let metadata: [PromptBrowserMetadataRow]
    let historyEntries: [PromptBrowserHistoryEntry]
    let primaryActionTitle: String?
    let primaryActionSystemImage: String?
    let isPrimaryActionDisabled: Bool
    let onPrimaryAction: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryActionSystemImage: String?
    let onSecondaryAction: (() -> Void)?
    let quickActions: [PromptBrowserQuickAction]
    let isEditable: Bool
    let onSaveEdits: ((String, String?, String) -> Void)?
    let onDelete: (() -> Void)?
    let deletionTitle: String?
    /// Whether the prompt has external sources attached. Used for the Sources filter.
    var hasExternalSources: Bool = false
    /// Whether the prompt is shared publicly or with others. Used for the Shared filter.
    var isShared: Bool = false

    init(
        id: String,
        title: String,
        summary: String,
        promptText: String,
        systemImage: String,
        iconTint: Color,
        badges: [PromptCollectionFooterBadge],
        trailingDetail: String?,
        metadata: [PromptBrowserMetadataRow],
        historyEntries: [PromptBrowserHistoryEntry] = [],
        primaryActionTitle: String?,
        primaryActionSystemImage: String?,
        isPrimaryActionDisabled: Bool,
        onPrimaryAction: (() -> Void)?,
        secondaryActionTitle: String?,
        secondaryActionSystemImage: String?,
        onSecondaryAction: (() -> Void)?,
        quickActions: [PromptBrowserQuickAction] = [],
        isEditable: Bool = false,
        onSaveEdits: ((String, String?, String) -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        deletionTitle: String? = nil,
        hasExternalSources: Bool = false,
        isShared: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.promptText = promptText
        self.systemImage = systemImage
        self.iconTint = iconTint
        self.badges = badges
        self.trailingDetail = trailingDetail
        self.metadata = metadata
        self.historyEntries = historyEntries
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionSystemImage = primaryActionSystemImage
        self.isPrimaryActionDisabled = isPrimaryActionDisabled
        self.onPrimaryAction = onPrimaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryActionSystemImage = secondaryActionSystemImage
        self.onSecondaryAction = onSecondaryAction
        self.quickActions = quickActions
        self.isEditable = isEditable
        self.onSaveEdits = onSaveEdits
        self.onDelete = onDelete
        self.deletionTitle = deletionTitle
        self.hasExternalSources = hasExternalSources
        self.isShared = isShared
    }
}

struct PromptBrowserScreen<EmptyState: View, ExtraToolbarContent: ToolbarContent>: View {
    let sections: [PromptBrowserSection]
    @Binding var selectedItemID: String?
    let emptyState: () -> EmptyState
    let toolbarContent: () -> ExtraToolbarContent

    init(
        sections: [PromptBrowserSection],
        selectedItemID: Binding<String?>,
        @ViewBuilder emptyState: @escaping () -> EmptyState,
        @ToolbarContentBuilder toolbarContent: @escaping () -> ExtraToolbarContent
    ) {
        self.sections = sections
        self._selectedItemID = selectedItemID
        self.emptyState = emptyState
        self.toolbarContent = toolbarContent
    }

    var body: some View {
        PromptBrowserWorkspace(
            sections: sections,
            selectedItemID: $selectedItemID,
            emptyState: emptyState,
            toolbarContent: toolbarContent
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

enum PromptBrowserListFilter: String, CaseIterable {
    case all     = "All"
    case ready   = "Ready"
    case shared  = "Shared"
    case sources = "Sources"
}

struct PromptBrowserWorkspace<EmptyState: View, ExtraToolbarContent: ToolbarContent>: View {
    let sections: [PromptBrowserSection]
    @Binding var selectedItemID: String?
    let emptyState: () -> EmptyState
    let toolbarContent: () -> ExtraToolbarContent

    init(
        sections: [PromptBrowserSection],
        selectedItemID: Binding<String?>,
        @ViewBuilder emptyState: @escaping () -> EmptyState,
        @ToolbarContentBuilder toolbarContent: @escaping () -> ExtraToolbarContent
    ) {
        self.sections = sections
        self._selectedItemID = selectedItemID
        self.emptyState = emptyState
        self.toolbarContent = toolbarContent
    }

    @State private var listFilter: PromptBrowserListFilter = .all
    @State private var editRequestNonce = 0
    @State private var editRequestTargetID: String?

    private var allItems: [PromptBrowserItem] {
        sections.flatMap(\.items)
    }

    private var filteredItems: [PromptBrowserItem] {
        switch listFilter {
        case .all:     return allItems
        case .ready:   return allItems.filter { !$0.promptText.isEmpty }
        case .shared:  return allItems.filter { $0.isShared }
        case .sources: return allItems.filter { $0.hasExternalSources }
        }
    }

    private var selectedItem: PromptBrowserItem? {
        let items = filteredItems
        if let selectedItemID,
           let selectedItem = items.first(where: { $0.id == selectedItemID }) {
            return selectedItem
        }
        return items.first
    }

    var body: some View {
        Group {
            if allItems.isEmpty {
                emptyState()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
            } else {
                WorkspaceSplitShell(
                    sidebarMinWidth: 240,
                    sidebarIdealWidth: 300,
                    sidebarMaxWidth: 380,
                    detailMinWidth: 280,
                    sidebar: {
                        listPane
                    },
                    detail: {
                        detailPane
                    }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear(perform: syncSelection)
        .onChange(of: allItems.map(\.id)) { _, _ in
            syncSelection()
        }
        .onChange(of: listFilter) { _, _ in
            syncSelection()
        }
        .toolbar { promptToolbarContent }
    }

    /// Empty state shown inside the list pane when the current filter yields no results.
    private var filteredEmptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(PH.Color.secondary)
            Text("No results for \"\(listFilter.rawValue)\"")
                .font(PH.Font.rowName)
                .foregroundStyle(PH.Color.primary)
            Text("Try a different filter or clear the current one.")
                .font(PH.Font.rowSub)
                .foregroundStyle(PH.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var listPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                if filteredItems.isEmpty {
                    filteredEmptyStateView
                } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(sections) { section in
                        let sectionItems = section.items.filter { item in
                            filteredItems.contains(where: { $0.id == item.id })
                        }
                        if !sectionItems.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                PromptCollectionSectionLabel(
                                    title: section.title,
                                    count: sectionItems.count,
                                    systemImage: section.systemImage
                                )
                                .padding(.top, 12)

                                VStack(spacing: 2) {
                                    ForEach(sectionItems) { item in
                                        PromptBrowserRow(
                                            item: item,
                                            isSelected: item.id == selectedItem?.id,
                                            onSelect: {
                                                selectedItemID = item.id
                                            },
                                            onEdit: {
                                                selectedItemID = item.id
                                                editRequestTargetID = item.id
                                                editRequestNonce += 1
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, PH.Spacing.rowV)
                .padding(.bottom, PH.Spacing.detailB)
                }
            }
            .frame(minHeight: 0, idealHeight: 0, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ToolbarContentBuilder
    private var promptToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                ForEach(PromptBrowserListFilter.allCases, id: \.rawValue) { filter in
                    Button(action: { listFilter = filter }) {
                        HStack {
                            Text(filter.rawValue)
                            if listFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }                
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 18, height: 18)
            }
            .help("Filter: \(listFilter.rawValue)")
        }

        toolbarContent()
    }

    private var detailPane: some View {
        Group {
            if let selectedItem {
                PromptBrowserDetail(
                    item: selectedItem,
                    editRequestTargetID: editRequestTargetID,
                    editRequestNonce: editRequestNonce
                )
                    .padding(PH.Spacing.detailH)
            }
        }
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
        .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
        .background(PH.Color.detailBg)
    }

    private func syncSelection() {
        let itemIDs = Set(filteredItems.map(\.id))
        guard !itemIDs.isEmpty else {
            selectedItemID = nil
            return
        }

        if let selectedItemID, itemIDs.contains(selectedItemID) {
            return
        }

        selectedItemID = filteredItems.first?.id
    }
}

private struct PromptBrowserRow: View {
    let item: PromptBrowserItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void

    var body: some View {
        SkillLibraryCompactRow(
            title: item.title,
            metaText: item.summary,
            dotColor: item.isShared ? PH.Color.statusOK : item.iconTint,
            isSelected: isSelected,
            onSelect: onSelect
        ) {
            if let firstBadge = item.badges.first {
                Text(firstBadge.title)
                    .font(PH.Font.chip)
                    .foregroundStyle(firstBadge.tint)
                    .padding(.horizontal, PH.Spacing.chipH)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: PH.Spacing.chipCorner)
                            .fill(firstBadge.tint.opacity(0.10))
                    )
            }
        }
        .contextMenu {
            if item.isEditable {
                Button {
                    onEdit()
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            if let primaryActionTitle = item.primaryActionTitle,
               let primaryActionSystemImage = item.primaryActionSystemImage,
               let onPrimaryAction = item.onPrimaryAction {
                Button {
                    onPrimaryAction()
                } label: {
                    Label(primaryActionTitle, systemImage: primaryActionSystemImage)
                }
                .disabled(item.isPrimaryActionDisabled)
            }

            if let secondaryActionTitle = item.secondaryActionTitle,
               let secondaryActionSystemImage = item.secondaryActionSystemImage,
               let onSecondaryAction = item.onSecondaryAction {
                Button {
                    onSecondaryAction()
                } label: {
                    Label(secondaryActionTitle, systemImage: secondaryActionSystemImage)
                }
            }

            ForEach(item.quickActions) { action in
                Button {
                    action.onSelect()
                } label: {
                    Label(action.title, systemImage: action.systemImage)
                }
                .disabled(action.isDisabled)
            }

            if let onDelete = item.onDelete {
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label(item.deletionTitle ?? "Delete", systemImage: "trash")
                }
            }
        }
        .accessibilityLabel(item.title)
        .accessibilityValue(item.summary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct PromptBrowserDetail: View {
    let item: PromptBrowserItem
    let startsEditing: Bool
    let editRequestTargetID: String?
    let editRequestNonce: Int
    @State private var isShowingHistoryDrawer = false
    @State private var isEditing = false
    @State private var draftTitle = ""
    @State private var draftSummary = ""
    @State private var draftPromptText = ""
    @FocusState private var focusedField: PromptWorkspaceEditableField?

    init(item: PromptBrowserItem, startsEditing: Bool = false, editRequestTargetID: String? = nil, editRequestNonce: Int = 0) {
        self.item = item
        self.startsEditing = startsEditing
        self.editRequestTargetID = editRequestTargetID
        self.editRequestNonce = editRequestNonce
    }

    private var variables: [String] {
        let pattern = #"\{\{\s*([^{}]+?)\s*\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(item.promptText.startIndex..<item.promptText.endIndex, in: item.promptText)
        let matches = regex.matches(in: item.promptText, range: nsRange)

        var seen: Set<String> = []
        var ordered: [String] = []

        for match in matches {
            guard let range = Range(match.range(at: 1), in: item.promptText) else { continue }
            let variable = String(item.promptText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard seen.insert(variable).inserted else { continue }
            ordered.append(variable)
        }

        return ordered
    }

    private var detailActions: [PromptBrowserQuickAction] {
        var actions: [PromptBrowserQuickAction] = []

        if let primaryActionTitle = item.primaryActionTitle,
           let primaryActionSystemImage = item.primaryActionSystemImage,
           let onPrimaryAction = item.onPrimaryAction {
            actions.append(
                PromptBrowserQuickAction(
                    id: "primary-\(item.id)",
                    title: primaryActionTitle,
                    systemImage: primaryActionSystemImage,
                    emphasis: .prominent,
                    isDisabled: item.isPrimaryActionDisabled,
                    onSelect: onPrimaryAction
                )
            )
        }

        if let secondaryActionTitle = item.secondaryActionTitle,
           let secondaryActionSystemImage = item.secondaryActionSystemImage,
           let onSecondaryAction = item.onSecondaryAction {
            actions.append(
                PromptBrowserQuickAction(
                    id: "secondary-\(item.id)",
                    title: secondaryActionTitle,
                    systemImage: secondaryActionSystemImage,
                    emphasis: .standard,
                    isDisabled: false,
                    onSelect: onSecondaryAction
                )
            )
        }

        actions.append(contentsOf: item.quickActions)
        return actions
    }

    private var hasHistoryContent: Bool {
        !item.metadata.isEmpty || !item.historyEntries.isEmpty
    }

    private var displaySummary: String {
        isEditing ? draftSummary : item.summary
    }

    private var displayTitle: String {
        isEditing ? draftTitle : item.title
    }

    private func syncDrafts() {
        draftTitle = item.title
        draftSummary = item.summary == "No description" ? "" : item.summary
        draftPromptText = item.promptText
        isEditing = false
    }

    private func toggleEditing() {
        guard item.isEditable else { return }
        if isEditing {
            item.onSaveEdits?(
                draftTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                draftSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : draftSummary.trimmingCharacters(in: .whitespacesAndNewlines),
                draftPromptText
            )
        } else {
            syncDrafts()
        }
        isEditing.toggle()
    }

    private func beginEditing() {
        guard item.isEditable else { return }
        syncDrafts()
        isEditing = true
        DispatchQueue.main.async {
            focusedField = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || draftTitle == "Untitled Prompt"
                ? .title
                : .content
        }
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            VStack(alignment: .leading, spacing: PH.Spacing.promptInset) {
                HStack(alignment: .top, spacing: PH.Spacing.promptDrawerGap) {
                    VStack(alignment: .leading, spacing: PH.Spacing.promptHeaderGap) {
                        Group {
                            if isEditing {
                                TextField("Prompt Name", text: $draftTitle)
                                    .textFieldStyle(.plain)
                                    .focused($focusedField, equals: .title)
                                    .padding(.horizontal, -4)
                            } else {
                                Text(displayTitle)
                            }
                        }
                        .font(PH.Font.paneTitle)
                        .foregroundStyle(PH.Color.primary)

                        if !item.badges.isEmpty {
                            HStack(spacing: PH.Spacing.toolbarGap) {
                                ForEach(item.badges) { badge in
                                    Text(badge.title)
                                        .font(PH.Font.chip)
                                        .foregroundStyle(badge.tint)
                                        .padding(.horizontal, PH.Spacing.chipH)
                                        .padding(.vertical, 2)
                                        .background(badge.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: PH.Spacing.chipCorner))
                                }
                            }
                        }
                    }

                    Spacer()

                    HStack(spacing: PH.Spacing.promptDrawerItemGap) {
                        if item.isEditable {
                            Button {
                                toggleEditing()
                            } label: {
                                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(PH.Color.primary)
                            .help(isEditing ? "Done editing" : "Edit prompt")
                        }

                        if hasHistoryContent {
                            Button {
                                isShowingHistoryDrawer.toggle()
                            } label: {
                                Image(systemName: "clock.arrow.circlepath")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(PH.Color.primary)
                            .help(isShowingHistoryDrawer ? "Hide history" : "Show history")
                        }

                        if !detailActions.isEmpty {
                            HStack(spacing: PH.Spacing.promptDrawerItemGap) {
                                ForEach(detailActions) { action in
                                    Button(action: action.onSelect) {
                                        Image(systemName: action.systemImage)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(action.isDisabled)
                                    .foregroundStyle(action.isDisabled ? PH.Color.tertiary : PH.Color.primary)
                                    .help(action.title)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, PH.Spacing.promptToolbarCapsuleH)
                    .padding(.vertical, PH.Spacing.promptToolbarCapsuleV)
                    .background(PH.Color.hoverFill, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(PH.Color.stroke, lineWidth: 1)
                    )
                }
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: PH.Spacing.promptDrawerItemGap) {
                    if isEditing {
                        TextField("Add a description...", text: $draftSummary, axis: .vertical)
                            .textFieldStyle(.plain)
                            .font(PH.Font.rowSub)
                            .foregroundStyle(PH.Color.secondary)
                            .focused($focusedField, equals: .summary)
                            .padding(.horizontal, -4)
                    } else if !displaySummary.isEmpty && displaySummary != "No description" {
                        Text(displaySummary)
                            .font(PH.Font.rowSub)
                            .foregroundStyle(PH.Color.secondary)
                    }

                    Group {
                        if isEditing {
                            NoScrollBarTextEditor(
                                text: $draftPromptText,
                                font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular),
                                becomeFirstResponder: focusedField == .content,
                                autoScroll: false
                            )
                            .padding(PH.Spacing.detailH)
                        } else {
                            ScrollView {
                                if draftPromptText.isEmpty {
                                    Text("No prompt content.")
                                        .font(.body)
                                        .foregroundStyle(PH.Color.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(PH.Spacing.detailH)
                                } else {
                                    Markdown(draftPromptText)
                                        .markdownSoftBreakMode(.lineBreak)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                        .padding(PH.Spacing.detailH)
                                }
                            }
                        }
                    }
                    .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
                    .background(PH.Color.sidebarBg, in: RoundedRectangle(cornerRadius: PH.Spacing.promptPanelCorner))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .layoutPriority(1)

                if !variables.isEmpty {
                    VStack(alignment: .leading, spacing: PH.Spacing.sectionHeadMB) {
                        PHSectionHead(systemImage: "curlybraces", label: "Variables")
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 110), spacing: PH.Spacing.toolbarGap, alignment: .leading)],
                            alignment: .leading,
                            spacing: PH.Spacing.toolbarGap
                        ) {
                            ForEach(variables, id: \.self) { variable in
                                Text("{{\(variable)}}")
                                    .font(PH.Font.mono)
                                    .foregroundStyle(PH.Color.accent)
                                    .padding(.horizontal, PH.Spacing.chipH + 2)
                                    .padding(.vertical, 3)
                                    .background(PH.Color.accentTint, in: Capsule())
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, PH.Spacing.promptInset)
            .padding(.top, PH.Spacing.promptInset)

            if isShowingHistoryDrawer, hasHistoryContent {
                historyDrawer
                    .transition(.move(edge: .trailing))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .animation(.easeInOut(duration: 0.18), value: isShowingHistoryDrawer)
        .onAppear {
            syncDrafts()
            if startsEditing && item.isEditable {
                beginEditing()
            }
        }
        .onChange(of: item.id) { _, _ in
            syncDrafts()
            isShowingHistoryDrawer = false
        }
        .onChange(of: item.promptText) { _, _ in
            if !isEditing { syncDrafts() }
        }
        .onChange(of: item.title) { _, _ in
            if !isEditing { syncDrafts() }
        }
        .onChange(of: item.summary) { _, _ in
            if !isEditing { syncDrafts() }
        }
        .onChange(of: editRequestNonce) { _, _ in
            guard editRequestTargetID == item.id else { return }
            beginEditing()
        }
    }

    private var historyDrawer: some View {
        VStack(alignment: .leading, spacing: PH.Spacing.promptDrawerGap) {
            HStack(alignment: .top, spacing: PH.Spacing.promptDrawerItemGap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(PH.Font.drawerTitle)
                    Text("Version context and restore live here, not in the main reading area.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isShowingHistoryDrawer = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
            }

            if !item.metadata.isEmpty {
                SkillLibraryInspectorCard(title: "Context") {
                    SkillLibraryMetadataBlock(
                        title: "",
                        rows: item.metadata.map { ($0.label, $0.value) }
                    )
                }
            }

            SkillLibraryInspectorCard(title: "Versions") {
                if item.historyEntries.isEmpty {
                    Text("No history yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: PH.Spacing.promptDrawerCardGap) {
                            ForEach(item.historyEntries) { entry in
                                VStack(alignment: .leading, spacing: PH.Spacing.promptDrawerCardGap) {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(entry.versionLabel)
                                            .font(.headline)

                                        if entry.isCurrent {
                                            Text("Current")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Text(entry.timestamp)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(entry.summary)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)

                                    if let onRestore = entry.onRestore {
                                        Button("Restore") {
                                            onRestore()
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(PH.Spacing.promptDrawerItemGap)
                                .background(PH.Color.buttonBg, in: RoundedRectangle(cornerRadius: PH.Spacing.promptPanelCorner))
                                .overlay(
                                    RoundedRectangle(cornerRadius: PH.Spacing.promptPanelCorner)
                                        .stroke(PH.Color.buttonBorder, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(width: PH.Layout.promptBrowserHistoryDrawerWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding(PH.Spacing.promptDrawerGap)
        .background(PH.Color.detailBg)
        .overlay(alignment: .leading) {
            Divider()
        }
        .shadow(color: .black.opacity(0.12), radius: 18, x: -4, y: 0)
    }
}

enum PromptWorkspaceEditableField: Hashable {
    case title
    case summary
    case content
}

struct PromptCollectionSectionLabel: View {
    let title: String
    let count: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(PH.Color.secondary)
            Text(title)
                .font(PH.Font.sectionHead)
                .foregroundStyle(PH.Color.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Text("\(count)")
                .font(PH.Font.badge.monospacedDigit())
                .foregroundStyle(PH.Color.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(PH.Color.badgeBg)
                .clipShape(Capsule())
        }
    }
}

struct PromptCollectionInspectorPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            content()
        }
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PromptQuickActionWrap: View {
    let actions: [PromptBrowserQuickAction]

    private var rows: [[PromptBrowserQuickAction]] {
        stride(from: 0, to: actions.count, by: 3).map { startIndex in
            Array(actions[startIndex..<min(startIndex + 3, actions.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .center, spacing: 8) {
                    ForEach(row) { action in
                        PromptQuickActionButton(action: action)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PromptQuickActionButton: View {
    let action: PromptBrowserQuickAction

    var body: some View {
        Button(action: action.onSelect) {
            Label(action.title, systemImage: action.systemImage)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foregroundColor)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(borderColor, lineWidth: 0.8)
        )
        .opacity(action.isDisabled ? 0.45 : 1)
        .disabled(action.isDisabled)
    }

    private var foregroundColor: Color {
        switch action.emphasis {
        case .prominent:
            return PH.Color.accent
        case .standard:
            return PH.Color.primary
        }
    }

    private var backgroundColor: Color {
        switch action.emphasis {
        case .prominent:
            return PH.Color.accentTint
        case .standard:
            return PH.Color.buttonBg
        }
    }

    private var borderColor: Color {
        switch action.emphasis {
        case .prominent:
            return PH.Color.accent.opacity(0.18)
        case .standard:
            return PH.Color.buttonBorder
        }
    }
}

struct PromptCollectionKVList: View {
    let items: [(String, String)]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: 12) {
                    Text(item.0)
                        .font(PH.Font.kvKey)
                        .foregroundStyle(PH.Color.secondary)
                        .frame(width: PH.Spacing.kvColWidth, alignment: .leading)
                    Spacer()
                    Text(item.1)
                        .font(PH.Font.kvValue)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, PH.Spacing.kvRowV)

                if index < items.count - 1 {
                    Divider().padding(.leading, PH.Spacing.kvColWidth + 18)
                }
            }
        }
    }
}

struct PromptCollectionCard<Footer: View>: View {
    let title: String
    let description: String?
    let systemImage: String
    let iconTint: Color
    let onTap: () -> Void
    @ViewBuilder let footer: () -> Footer

    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBlock

            footer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovering ? Color.accentColor.opacity(0.05) : Color(NSColor.controlBackgroundColor).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
            .stroke(isHovering ? Color.accentColor.opacity(0.18) : Color.clear, lineWidth: 0.8)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var headerBlock: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(iconTint)
                .font(.headline)
                .frame(width: 26, height: 26)
                .background(iconTint.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if let description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .accessibilityAddTraits(.isButton)
    }
}

struct PromptCollectionCardFooter: View {
    let leadingBadges: [PromptCollectionFooterBadge]
    let trailingText: String?

    var body: some View {
        HStack(spacing: 6) {
            ForEach(leadingBadges) { badge in
                Text(badge.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(badge.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(badge.tint.opacity(0.12))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 0)

            if let trailingText, !trailingText.isEmpty {
                Text(trailingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct PromptCollectionFooterButton: View {
    let title: String
    let tint: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(tint.opacity(isDisabled ? 0.08 : 0.12))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct PromptCollectionFooterBadge: Hashable, Identifiable {
    let title: String
    let tint: Color

    var id: Self { self }
}
