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
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: item.systemImage)
                    .foregroundStyle(isSelected ? .white : item.iconTint)
                    .frame(width: 18, height: 18)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(isSelected ? Color.white.opacity(0.18) : item.iconTint.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        if let trailingDetail = item.trailingDetail, !trailingDetail.isEmpty {
                            Text(trailingDetail)
                                .font(.caption)
                                .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
                        }
                    }

                    Text(item.summary)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.84) : .secondary)
                        .lineLimit(2)

                    if !item.badges.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(item.badges) { badge in
                                Text(badge.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(isSelected ? .white : badge.tint)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(
                                        RoundedRectangle(cornerRadius: 999)
                                            .fill(isSelected ? Color.white.opacity(0.16) : badge.tint.opacity(0.12))
                                    )
                            }
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor : Color(NSColor.windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

            if item.onPrimaryAction != nil || item.onSecondaryAction != nil {
                HStack(spacing: 10) {
                    if let primaryActionTitle = item.primaryActionTitle,
                       let primaryActionSystemImage = item.primaryActionSystemImage,
                       let onPrimaryAction = item.onPrimaryAction {
                        Button(action: onPrimaryAction) {
                            Label(primaryActionTitle, systemImage: primaryActionSystemImage)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(item.isPrimaryActionDisabled)
                    }

                    if let secondaryActionTitle = item.secondaryActionTitle,
                       let secondaryActionSystemImage = item.secondaryActionSystemImage,
                       let onSecondaryAction = item.onSecondaryAction {
                        Button(action: onSecondaryAction) {
                            Label(secondaryActionTitle, systemImage: secondaryActionSystemImage)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            if !item.metadata.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Details")
                        .font(.headline)

                    PromptCollectionInspectorPanel(title: "Metadata") {
                        PromptCollectionKVList(items: item.metadata.map { ($0.label, $0.value) })
                    }
                }
            }

            if !variables.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Variables")
                        .font(.headline)

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

            VStack(alignment: .leading, spacing: 10) {
                Text("Prompt")
                    .font(.headline)

                Text(item.promptText)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                    )
                    .textSelection(.enabled)
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
                .font(.headline)
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PromptCollectionKVList: View {
    let items: [(String, String)]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack {
                    Text(item.0)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(item.1)
                        .fontWeight(.medium)
                }
                .font(.callout)
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
        .background(isHovering ? Color.accentColor.opacity(0.06) : Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHovering ? Color.accentColor.opacity(0.25) : Color(NSColor.separatorColor).opacity(0.7), lineWidth: 1)
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