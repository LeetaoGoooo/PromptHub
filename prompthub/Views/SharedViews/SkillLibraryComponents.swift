import AppKit
import SwiftUI

// MARK: - Row Card Style Modifier

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
            .shadow(color: .clear, radius: 0, x: 0, y: 0)
            .contentShape(RoundedRectangle(cornerRadius: 12))
    }

    private var backgroundColor: Color {
        if isSelected { return Color(nsColor: NSColor.controlAccentColor).opacity(0.12) }
        if isHovered  { return Color.primary.opacity(0.035) }
        return Color(NSColor.textBackgroundColor)
    }

    private var borderColor: Color {
        if isSelected { return Color(nsColor: NSColor.controlAccentColor).opacity(0.32) }
        if isHovered  { return Color.primary.opacity(0.08) }
        return Color(NSColor.separatorColor).opacity(0.45)
    }
}

// MARK: - Metadata Block

struct SkillLibraryMetadataBlock: View {
    let title: String
    let rows: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 12) {
                    Text(row.0).font(.subheadline.weight(.medium)).foregroundStyle(.secondary).frame(width: 88, alignment: .leading)
                    Text(row.1).font(.subheadline).textSelection(.enabled)
                    Spacer()
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

    init(title: String, systemImage: String, description: String, @ViewBuilder actions: @escaping () -> Actions = { EmptyView() }) {
        self.title = title; self.systemImage = systemImage; self.description = description; self.actions = actions
    }

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            actions()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
    }
}

// MARK: - Inspector Card

struct SkillLibraryInspectorCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: () -> Content

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title, !title.isEmpty { Text(title).font(.headline) }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(28)
        .background(Color(NSColor.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color(NSColor.separatorColor), lineWidth: 1) }
    }
}
