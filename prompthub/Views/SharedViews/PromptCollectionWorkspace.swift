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
    let primaryActionTitle: String?
    let primaryActionSystemImage: String?
    let isPrimaryActionDisabled: Bool
    let onPrimaryAction: (() -> Void)?
    let secondaryActionTitle: String?
    let secondaryActionSystemImage: String?
    let onSecondaryAction: (() -> Void)?
    let quickActions: [PromptBrowserQuickAction]

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
        primaryActionTitle: String?,
        primaryActionSystemImage: String?,
        isPrimaryActionDisabled: Bool,
        onPrimaryAction: (() -> Void)?,
        secondaryActionTitle: String?,
        secondaryActionSystemImage: String?,
        onSecondaryAction: (() -> Void)?,
        quickActions: [PromptBrowserQuickAction] = []
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
        self.primaryActionTitle = primaryActionTitle
        self.primaryActionSystemImage = primaryActionSystemImage
        self.isPrimaryActionDisabled = isPrimaryActionDisabled
        self.onPrimaryAction = onPrimaryAction
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryActionSystemImage = secondaryActionSystemImage
        self.onSecondaryAction = onSecondaryAction
        self.quickActions = quickActions
    }
}

struct PromptBrowserScreen<Actions: View, EmptyState: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let metrics: [PromptCollectionMetric]
    let sections: [PromptBrowserSection]
    @Binding var selectedItemID: String?
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let emptyState: () -> EmptyState

    var body: some View {
        VStack(spacing: 0) {
            PromptCollectionHeader(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                metrics: metrics,
                actions: actions
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            PromptBrowserWorkspace(
                sections: sections,
                selectedItemID: $selectedItemID,
                emptyState: emptyState
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

private struct PromptBrowserWorkspace<EmptyState: View>: View {
    let sections: [PromptBrowserSection]
    @Binding var selectedItemID: String?
    @ViewBuilder let emptyState: () -> EmptyState

    private var allItems: [PromptBrowserItem] {
        sections.flatMap(\.items)
    }

    private var selectedItem: PromptBrowserItem? {
        let items = allItems
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
                HSplitView {
                    listPane
                    detailPane
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: syncSelection)
        .onChange(of: allItems.map(\.id)) { _, _ in
            syncSelection()
        }
    }

    private var listPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        PromptCollectionSectionLabel(
                            title: section.title,
                            count: section.items.count,
                            systemImage: section.systemImage
                        )

                        VStack(spacing: 6) {
                            ForEach(section.items) { item in
                                PromptBrowserRow(
                                    item: item,
                                    isSelected: item.id == selectedItem?.id,
                                    onSelect: {
                                        selectedItemID = item.id
                                    }
                                )
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var detailPane: some View {
        ScrollView {
            if let selectedItem {
                PromptBrowserDetail(item: selectedItem)
                    .padding(24)
            }
        }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func syncSelection() {
        let itemIDs = Set(allItems.map(\.id))
        guard !itemIDs.isEmpty else {
            selectedItemID = nil
            return
        }

        if let selectedItemID, itemIDs.contains(selectedItemID) {
            return
        }

        selectedItemID = allItems.first?.id
    }
}

private struct PromptBrowserRow: View {
    let item: PromptBrowserItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: PH.Spacing.rowGap) {
                // Line 1: name + first badge (model chip) right-aligned
                HStack(spacing: 0) {
                    Text(item.title)
                        .font(PH.Font.rowName)
                        .foregroundStyle(PH.Color.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

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

                // Line 2: sub info from summary (truncated 1 line)
                Text(item.summary)
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.tertiary)
                    .lineLimit(1)
            }
            .padding(.vertical, PH.Spacing.rowH)
            .padding(.horizontal, PH.Spacing.rowV)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? PH.Color.accentTint : .clear)
            .clipShape(RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.summary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct PromptBrowserDetail: View {
    let item: PromptBrowserItem

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

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.systemImage)
                        .foregroundStyle(item.iconTint)
                        .font(.headline)
                        .frame(width: 32, height: 32)
                        .background(item.iconTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.title)
                            .font(.title2.weight(.semibold))
                        Text(item.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }

                if !item.badges.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(item.badges) { badge in
                            Text(badge.title)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(badge.tint)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badge.tint.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }

            if !item.metadata.isEmpty || !variables.isEmpty {
                PromptCollectionInspectorPanel(title: "Properties") {
                    VStack(alignment: .leading, spacing: 14) {
                        if !item.metadata.isEmpty {
                            PromptCollectionKVList(items: item.metadata.map { ($0.label, $0.value) })
                        }

                        if !variables.isEmpty {
                            Divider()

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Variables")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8, alignment: .leading)], alignment: .leading, spacing: 8) {
                                    ForEach(variables, id: \.self) { variable in
                                        Text("{{\(variable)}}")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .background(Color.accentColor.opacity(0.10), in: Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if !detailActions.isEmpty {
                PromptCollectionInspectorPanel(title: "Quick Actions") {
                    PromptQuickActionWrap(actions: detailActions)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Content")
                    .font(.headline)

                ScrollView {
                    Text(item.promptText)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                }
                .frame(minHeight: 220, idealHeight: 280, maxHeight: 280)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private struct PromptCollectionHeader<Actions: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let metrics: [PromptCollectionMetric]
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .foregroundStyle(.secondary)
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !metrics.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(metrics) { metric in
                            Label {
                                Text("\(metric.value) \(metric.title)")
                            } icon: {
                                Image(systemName: metric.systemImage)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer(minLength: 16)

            HStack(spacing: 8) {
                actions()
            }
        }
    }
}

struct PromptCollectionSectionLabel: View {
    let title: String
    let count: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text("\(count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(NSColor.controlBackgroundColor))
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
                .font(.callout)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
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
            return Color(NSColor.controlAccentColor)
        case .standard:
            return .primary
        }
    }

    private var backgroundColor: Color {
        switch action.emphasis {
        case .prominent:
            return Color(NSColor.controlAccentColor).opacity(0.10)
        case .standard:
            return Color(NSColor.controlBackgroundColor).opacity(0.82)
        }
    }

    private var borderColor: Color {
        switch action.emphasis {
        case .prominent:
            return Color(NSColor.controlAccentColor).opacity(0.18)
        case .standard:
            return Color(NSColor.separatorColor).opacity(0.32)
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
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(width: 96, alignment: .leading)
                    Spacer()
                    Text(item.1)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.trailing)
                }
                .font(.callout)
                .padding(.vertical, 8)

                if index < items.count - 1 {
                    Divider().padding(.leading, 108)
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