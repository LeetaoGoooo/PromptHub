import SwiftUI

struct SkillLibraryMetric: Identifiable {
    let value: String
    let title: String
    let systemImage: String

    var id: String { title }
}

struct SkillLibraryHeaderCard<Accessory: View>: View {
    let title: String
    let subtitle: String
    let metrics: [SkillLibraryMetric]
    @ViewBuilder let accessory: () -> Accessory

    init(
        title: String,
        subtitle: String,
        metrics: [SkillLibraryMetric],
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.subtitle = subtitle
        self.metrics = metrics
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Title + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 8)

            // Metrics inline
            if !metrics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(metrics) { metric in
                        HStack(spacing: 4) {
                            Image(systemName: metric.systemImage)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(metric.value)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(metric.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
                    }
                }
            }

            // Accessory actions
            accessory()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))

        Divider()
    }
}

struct SkillLibraryScreen<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String
    let metrics: [SkillLibraryMetric]
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String,
        metrics: [SkillLibraryMetric],
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.metrics = metrics
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            SkillLibraryHeaderCard(
                title: title,
                subtitle: subtitle,
                metrics: metrics,
                accessory: accessory
            )

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SkillLibraryBrowser<Sidebar: View, Detail: View>: View {
    let sidebarMinWidth: CGFloat
    let sidebarIdealWidth: CGFloat
    let sidebarMaxWidth: CGFloat
    let detailMinWidth: CGFloat
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    init(
        sidebarMinWidth: CGFloat = 280,
        sidebarIdealWidth: CGFloat = 310,
        sidebarMaxWidth: CGFloat = 460,
        detailMinWidth: CGFloat = 520,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.sidebarMinWidth = sidebarMinWidth
        self.sidebarIdealWidth = sidebarIdealWidth
        self.sidebarMaxWidth = sidebarMaxWidth
        self.detailMinWidth = detailMinWidth
        self.sidebar = sidebar
        self.detail = detail
    }

    var body: some View {
        HSplitView {
            sidebar()
                .frame(
                    minWidth: sidebarMinWidth,
                    idealWidth: sidebarIdealWidth,
                    maxWidth: sidebarMaxWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .background(Color(NSColor.controlBackgroundColor))

            detail()
                .frame(minWidth: detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SkillLibraryInspectorCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title, !title.isEmpty {
                Text(title)
                    .font(.headline)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        }
    }
}

struct SkillLibraryEmptyState<Actions: View>: View {
    let title: String
    let systemImage: String
    let description: String
    @ViewBuilder let actions: () -> Actions

    init(
        title: String,
        systemImage: String,
        description: String,
        @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actions = actions
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct SkillLibraryMetadataBlock: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.0)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 88, alignment: .leading)

                    Text(row.1)
                        .font(.subheadline)
                        .textSelection(.enabled)

                    Spacer()
                }
            }
        }
    }
}

struct SkillLibraryRowCardStyle: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
            }
            .shadow(
                color: shadowColor,
                radius: shadowRadius,
                x: 0,
                y: shadowYOffset
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private var backgroundColor: Color {
        if isSelected {
            return Color(nsColor: NSColor.controlAccentColor).opacity(0.12)
        }
        if isHovered {
            return Color.primary.opacity(0.035)
        }
        return Color(NSColor.textBackgroundColor)
    }

    private var borderColor: Color {
        if isSelected {
            return Color(nsColor: NSColor.controlAccentColor).opacity(0.32)
        }
        if isHovered {
            return Color.primary.opacity(0.08)
        }
        return Color(NSColor.separatorColor).opacity(0.45)
    }

    private var shadowColor: Color {
        .clear
    }

    private var shadowRadius: CGFloat {
        0
    }

    private var shadowYOffset: CGFloat {
        0
    }
}

private struct SkillMetricPill: View {
    let metric: SkillLibraryMetric

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: metric.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(metric.value)
                    .font(.headline.monospacedDigit())
                Text(metric.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(Capsule())
    }
}
