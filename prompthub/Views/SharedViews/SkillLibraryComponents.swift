import AppKit
import SwiftUI

// MARK: - Row Card Style Modifier

/// Glass-tinted selection style that reacts to hover and selection state.
/// Uses accent colour for selection (with glass-like low-opacity fill) and
/// a subtle material shift on hover — consistent with macOS Liquid Glass idiom.
struct SkillLibraryRowCardStyle: ViewModifier {
    let isSelected: Bool
    let isHovered: Bool

    func body(content: Content) -> some View {
        content
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                if isSelected || isHovered {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: isSelected ? 0.9 : 0.6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var backgroundColor: Color {
        if isSelected { return Color(nsColor: NSColor.controlAccentColor).opacity(0.08) }
        if isHovered  { return Color.primary.opacity(0.03) }
        return .clear
    }

    private var borderColor: Color {
        if isSelected { return Color(nsColor: NSColor.controlAccentColor).opacity(0.20) }
        if isHovered  { return Color.primary.opacity(0.08) }
        return .clear
    }
}

// MARK: - Metadata Block

// MARK: - PH Filter Chip

/// Flat pill-shaped filter chip used in list-pane headers.
struct PHFilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(PH.Font.chip)
                .foregroundStyle(isActive ? PH.Color.accent : PH.Color.secondary)
                .padding(.horizontal, PH.Spacing.chipH + 2)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: PH.Spacing.chipCorner)
                        .fill(isActive ? PH.Color.accentTint : PH.Color.chipBg)
                )
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .top, spacing: 12) {
                        Text(row.0)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 96, alignment: .leading)
                        Text(row.1)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 2)
                    if index < rows.count - 1 {
                        Divider().padding(.leading, 110)
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

/// Full-panel empty / zero-data state with a glassy icon well and optional actions.
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
        VStack(spacing: 20) {
            // Icon well — flat tinted circle (content layer: no backdrop filter per Liquid Glass spec)
            ZStack {
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 68, height: 68)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Inspector Card

/// Opaque content card for inspector / detail sections.
/// Uses flat NSColor surface per Liquid Glass content-layer spec (no backdrop-filter).
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
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

