import SwiftUI

struct PromptCollectionMetric: Hashable, Identifiable {
    let title: String
    let value: String
    let systemImage: String

    var id: Self { self }
}

struct PromptCollectionWorkspace<Actions: View, Content: View, Inspector: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let metrics: [PromptCollectionMetric]
    let showsInspector: Bool
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let content: () -> Content
    @ViewBuilder let inspector: () -> Inspector

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        metrics: [PromptCollectionMetric],
        showsInspector: Bool = true,
        @ViewBuilder actions: @escaping () -> Actions,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder inspector: @escaping () -> Inspector
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.metrics = metrics
        self.showsInspector = showsInspector
        self.actions = actions
        self.content = content
        self.inspector = inspector
    }

    var body: some View {
        Group {
            if showsInspector {
                HSplitView {
                    mainColumn
                    inspectorColumn
                }
            } else {
                mainColumn
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var mainColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PromptCollectionHeader(
                    title: title,
                    subtitle: subtitle,
                    systemImage: systemImage,
                    metrics: metrics,
                    actions: actions
                )
                content()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var inspectorColumn: some View {
        ScrollView {
            inspector()
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 280, idealWidth: 300, maxWidth: 320, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
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
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
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
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
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

struct PromptCollectionFooterBadge: Hashable, Identifiable {
    let title: String
    let tint: Color

    var id: Self { self }
}