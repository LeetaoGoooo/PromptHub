import AlertToast
import SwiftUI

/// Shared hover-card chrome applied to all prompt grid cards.
/// Both `PromptItemView` and `UserPromptItemView` use this modifier so that
/// the card background, border, hover tint, and copy-button overlay are
/// defined in one place.
struct PromptCardModifier: ViewModifier {
    @Binding var isHovering: Bool
    let onCopy: () -> Void

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(isHovering ? Color.accentColor.opacity(0.1) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isHovering ? Color.accentColor.opacity(0.3) : Color(NSColor.separatorColor),
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .bottomTrailing) {
                if isHovering {
                    Button {
                        onCopy()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(6)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
    }
}

extension View {
    func promptCardStyle(isHovering: Binding<Bool>, onCopy: @escaping () -> Void) -> some View {
        modifier(PromptCardModifier(isHovering: isHovering, onCopy: onCopy))
    }
}
