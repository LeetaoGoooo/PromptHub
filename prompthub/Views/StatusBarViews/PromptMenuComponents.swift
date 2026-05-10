import SwiftUI

// MARK: - Prompt Type

enum PromptType {
    case user, shared, gallery

    var icon: String {
        switch self {
        case .user:    return "person.crop.circle.fill"
        case .shared:  return "square.and.arrow.up.fill"
        case .gallery: return "globe"
        }
    }
    var color: Color {
        switch self {
        case .user:    return .blue
        case .shared:  return .orange
        case .gallery: return .gray
        }
    }
}

// MARK: - Prompt Row View

struct PromptRowView: View {
    let prompt: Prompt
    let promptType: PromptType
    let action: () -> Void
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        CopyableMenuRow(icon: promptType.icon, color: promptType.color, label: prompt.name, isHovering: $isHovering, didCopy: $didCopy, action: action)
    }
}

// MARK: - Shared Creation Row View

struct SharedCreationRowView: View {
    let sharedCreation: SharedCreation
    let action: () -> Void
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        CopyableMenuRow(icon: PromptType.shared.icon, color: PromptType.shared.color, label: sharedCreation.name, isHovering: $isHovering, didCopy: $didCopy, action: action)
    }
}

// MARK: - Gallery Prompt Row View

struct GalleryPromptRowView: View {
    let galleryPrompt: GalleryPrompt
    let action: () -> Void
    @State private var isHovering = false
    @State private var didCopy = false

    var body: some View {
        CopyableMenuRow(icon: PromptType.gallery.icon, color: PromptType.gallery.color, label: galleryPrompt.name, isHovering: $isHovering, didCopy: $didCopy, action: action)
    }
}

// MARK: - Shared Row Implementation

private struct CopyableMenuRow: View {
    let icon: String
    let color: Color
    let label: String
    @Binding var isHovering: Bool
    @Binding var didCopy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            guard !didCopy else { return }
            action()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { didCopy = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    didCopy = false
                    if isHovering { isHovering = false }
                }
            }
        }) {
            Group {
                if didCopy {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").font(.title3).foregroundColor(.green)
                        Text("Copied!").fontWeight(.semibold)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: icon).font(.caption).foregroundColor(color)
                        Text(label).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.vertical, 8).padding(.horizontal, 12)
            .frame(height: 38).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering && !didCopy ? color.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .onHover { hovering in
            if !didCopy { withAnimation(.easeOut(duration: 0.1)) { isHovering = hovering } }
        }
    }
}
