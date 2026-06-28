import SwiftUI

struct SettingsScreenContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            PH.Color.windowBg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: 760, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }
}

struct SettingsHero: View {
    let eyebrow: String
    let title: String
    let description: String
    let actions: AnyView?

    init(
        eyebrow: String,
        title: String,
        description: String,
        actions: AnyView? = nil
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.description = description
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(eyebrow.uppercased())
                        .font(PH.Font.sectionHead)
                        .foregroundStyle(PH.Color.tertiary)
                    Text(title)
                        .font(PH.Font.heroTitle)
                        .foregroundStyle(PH.Color.primary)
                    Text(description)
                        .font(PH.Font.body)
                        .foregroundStyle(PH.Color.secondary)
                        .lineSpacing(PH.Font.bodyLineSpacing)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if let actions {
                    actions
                }
            }

            Divider()
        }
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String?
    let footer: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        icon: String? = nil,
        footer: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.footer = footer
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: PH.Layout.iconSizeSm, weight: .medium))
                        .foregroundStyle(PH.Color.secondary)
                }

                Text(title.uppercased())
                    .font(PH.Font.sectionHead)
                    .foregroundStyle(PH.Color.secondary)
            }

            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(16)
            .background(PH.Color.detailBg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(PH.Color.buttonBorder, lineWidth: 1)
            )

            if let footer, !footer.isEmpty {
                Text(footer)
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    let detail: String
    @ViewBuilder let control: () -> Control

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PH.Font.rowName)
                    .foregroundStyle(PH.Color.primary)
                Text(detail)
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            control()
        }
    }
}

struct SettingsFieldLabel: View {
    let title: String
    let caption: String?

    init(_ title: String, caption: String? = nil) {
        self.title = title
        self.caption = caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(PH.Font.rowName)
                .foregroundStyle(PH.Color.primary)

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsInfoBanner<Content: View>: View {
    let icon: String
    let tint: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 6) {
                content()
            }
        }
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

struct SettingsTag: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(PH.Font.chip)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .frame(minHeight: PH.Spacing.chipMinH)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

struct SettingsTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? PH.Color.accent : PH.Color.secondary)
                .padding(.horizontal, 12)
                .frame(height: PH.Spacing.btnHeight)
                .background(
                    RoundedRectangle(cornerRadius: PH.Spacing.btnCorner, style: .continuous)
                        .fill(isSelected ? PH.Color.accentTint : PH.Color.buttonBg)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: PH.Spacing.btnCorner, style: .continuous)
                        .stroke(isSelected ? PH.Color.accent.opacity(0.18) : PH.Color.buttonBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}
