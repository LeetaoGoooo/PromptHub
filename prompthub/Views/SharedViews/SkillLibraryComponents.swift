import MarkdownUI
import PromptHubSkillKit
import SwiftUI

struct SkillLibraryRowCardStyle: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: PH.Spacing.rowCorner, style: .continuous))
            .overlay {
                if isSelected || isHovered {
                    RoundedRectangle(cornerRadius: PH.Spacing.rowCorner, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: PH.Spacing.rowCorner, style: .continuous))
    }

    private var backgroundColor: Color {
        if isSelected { return PH.Color.accentTint }
        if isHovered  { return PH.Color.hoverFill }
        return .clear
    }

    private var borderColor: Color {
        if isSelected { return PH.Color.accent.opacity(0.22) }
        if isHovered  { return PH.Color.stroke }
        return .clear
    }
}

struct SkillLibraryCompactRow<Trailing: View>: View {
    let title: String
    let metaText: String
    let dotColor: Color
    let isSelected: Bool
    let onSelect: () -> Void
    @ViewBuilder let trailing: () -> Trailing

    @State private var isHovering = false

    init(
        title: String,
        metaText: String,
        dotColor: Color,
        isSelected: Bool,
        onSelect: @escaping () -> Void = {},
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.metaText = metaText
        self.dotColor = dotColor
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.trailing = trailing
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: PH.Spacing.rowGap) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(PH.Font.rowName)
                        .foregroundStyle(PH.Color.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    trailing()
                }

                HStack(spacing: PH.Spacing.sectionHeadGap) {
                    Circle()
                        .fill(dotColor)
                        .frame(width: PH.Layout.statusDotSize, height: PH.Layout.statusDotSize)
                    Text(metaText)
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.tertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, PH.Spacing.rowH)
            .padding(.horizontal, PH.Spacing.rowV)
            .contentShape(RoundedRectangle(cornerRadius: PH.Spacing.rowCorner))
        }
        .buttonStyle(.plain)
        .modifier(SkillLibraryRowCardStyle(isSelected: isSelected, isHovered: isHovering))
        .animation(PH.Motion.hover, value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityLabel(title)
        .accessibilityValue(metaText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct SkillPreviewMarkdownView: View {
    let markdown: String
    let fallbackText: String

    private var previewText: String {
        let normalized = unwrapSkillMarkdown(markdown)
        return normalized.isEmpty ? fallbackText : normalized
    }

    private func unwrapSkillMarkdown(_ source: String) -> String {
        var current = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.isEmpty else { return "" }

        for _ in 0..<4 {
            guard let parsed = SkillParser.parse(markdown: current) else { break }
            let next = parsed.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !next.isEmpty, next != current else { break }
            current = next
        }

        return current
    }

    var body: some View {
        Markdown(previewText)
            .markdownSoftBreakMode(.lineBreak)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InlineSearchField: View {
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(PH.Color.tertiary)

            TextField(prompt, text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PH.Color.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 30)
        .background(PH.Color.hoverFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Metadata Block

// MARK: - PH Section Head

struct PHSectionHead: View {
    let systemImage: String
    let label: String

    var body: some View {
        HStack(spacing: PH.Spacing.sectionHeadGap) {
            Image(systemName: systemImage)
                .font(.system(size: PH.Layout.iconSizeSm, weight: .regular))
                .foregroundStyle(PH.Color.secondary)
                .frame(width: PH.Layout.iconSizeSm, height: PH.Layout.iconSizeSm)
            Text(label)
                .font(PH.Font.sectionHead)
                .foregroundStyle(PH.Color.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .padding(.bottom, PH.Spacing.sectionHeadMB)
    }
}

// MARK: - PH Filter Chip

struct PHFilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(PH.Font.chip)
                .foregroundStyle(isActive ? PH.Color.accent : PH.Color.secondary)
                .padding(.horizontal, PH.Spacing.chipH)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: PH.Spacing.chipCorner)
                        .fill(isActive ? PH.Color.accentTint : PH.Color.chipBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PH.Spacing.chipCorner)
                        .stroke(isActive ? PH.Color.accent.opacity(0.18) : Color.clear, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: PH.Spacing.chipCorner))
        }
        .buttonStyle(.plain)
    }
}

/// Aligned key-value metadata grid used in detail and inspector panels.
struct SkillLibraryMetadataBlock: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !title.isEmpty {
                Text(title)
                    .font(PH.Font.sectionHead)
                    .foregroundStyle(PH.Color.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: PH.Spacing.kvRowGap) {
                        Text(row.0)
                            .font(PH.Font.kvKey)
                            .foregroundStyle(PH.Color.secondary)
                            .frame(width: PH.Spacing.kvColWidth, alignment: .leading)
                        Text(row.1)
                            .font(PH.Font.kvValue)
                            .foregroundStyle(PH.Color.primary)
                            .textSelection(.enabled)
                        Spacer()
                    }
                    .padding(.vertical, PH.Spacing.kvRowV)
                    .padding(.horizontal, 2)
                    if index < rows.count - 1 {
                        Divider().padding(.leading, PH.Spacing.kvColWidth + PH.Spacing.kvRowGap + 8)
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

struct SkillLibraryEmptyState<Actions: View>: View {
    let title: String
    let systemImage: String
    let description: String
    @ViewBuilder let actions: () -> Actions

    init(title: String, systemImage: String, description: String,
         @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(PH.Color.secondary)
                .frame(width: 48, height: 48)
                .background(PH.Color.chipBg, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(spacing: 6) {
                Text(title)
                    .font(PH.Font.paneTitle)
                    .foregroundStyle(PH.Color.primary)
                Text(description)
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }
}

// MARK: - Inspector Card

struct SkillLibraryInspectorCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(PH.Font.sectionHead)
                    .foregroundStyle(PH.Color.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

struct SkillDetailHeader<Actions: View>: View {
    let timestamp: String
    let title: String
    let summary: String?
    let metrics: [SkillLibraryMetric]
    let controlSize: ControlSize
    @ViewBuilder let actions: () -> Actions

    @State private var isShowingSummaryPopover = false

    init(
        timestamp: String,
        title: String,
        summary: String? = nil,
        metrics: [SkillLibraryMetric] = [],
        controlSize: ControlSize = .regular,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.timestamp = timestamp
        self.title = title
        self.summary = summary
        self.metrics = metrics
        self.controlSize = controlSize
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(timestamp)
                .font(PH.Font.sectionHead)
                .foregroundStyle(PH.Color.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(PH.Font.heroTitle)
                    .foregroundStyle(PH.Color.primary)
                    .frame(maxWidth: 520, alignment: .leading)

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    if let summary, !summary.isEmpty {
                        Button {
                            isShowingSummaryPopover = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(controlSize)
                        .help("Show description")
                        .popover(isPresented: $isShowingSummaryPopover, arrowEdge: .bottom) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(title)
                                    .font(.headline)
                                Text(summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .frame(width: 320, alignment: .leading)
                        }
                    }

                    actions()
                }
            }

            if !metrics.isEmpty {
                HStack(spacing: 10) {
                    ForEach(metrics) { metric in
                        HStack(spacing: 4) {
                            Image(systemName: metric.systemImage)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PH.Color.tertiary)
                            Text(metric.value)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(PH.Color.secondary)
                                .lineLimit(1)
                            Text(metric.title)
                                .font(.system(size: 11))
                                .foregroundStyle(PH.Color.tertiary)
                        }
                    }
                }
            }

            Divider().opacity(0.55)
        }
    }
}

enum PHChromeButtonEmphasis {
    case standard
    case accent
}

struct PHChromeButtonStyle: ButtonStyle {
    let emphasis: PHChromeButtonEmphasis

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 12)
            .frame(height: PH.Spacing.btnHeight)
            .background(backgroundColor(configuration.isPressed), in: RoundedRectangle(cornerRadius: PH.Spacing.btnCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PH.Spacing.btnCorner, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var foregroundColor: Color {
        switch emphasis {
        case .standard:
            return PH.Color.primary
        case .accent:
            return PH.Color.accent
        }
    }

    private func backgroundColor(_ isPressed: Bool) -> Color {
        switch emphasis {
        case .standard:
            return isPressed ? PH.Color.hoverFill : PH.Color.buttonBg
        case .accent:
            return isPressed ? PH.Color.accentTint.opacity(0.8) : PH.Color.accentTint
        }
    }

    private var borderColor: Color {
        switch emphasis {
        case .standard:
            return PH.Color.buttonBorder
        case .accent:
            return PH.Color.accent.opacity(0.18)
        }
    }
}
