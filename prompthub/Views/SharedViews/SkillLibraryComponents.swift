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
