import SwiftUI

/// A prominent diff review panel shown after AI Optimize runs.
struct AIOptimizeDiffPanel: View {
    let diffResults: [DiffResult]
    let originalText: String
    let modifiedText: String
    let onKeep: () -> Void
    let onDiscard: () -> Void

    private var addedLines: Int {
        diffResults.filter { if case .added = $0 { return true }; return false }.count
    }
    private var removedLines: Int {
        diffResults.filter { if case .removed = $0 { return true }; return false }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ──────────────────────────────────────────────────
            HStack(spacing: 10) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.purple)
                    .font(.system(size: 15))

                Text("Review AI Changes")
                    .font(.headline)

                Spacer()

                // Stats
                if addedLines > 0 || removedLines > 0 {
                    HStack(spacing: 8) {
                        if addedLines > 0 {
                            Text("+\(addedLines)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        if removedLines > 0 {
                            Text("-\(removedLines)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }

                // Action buttons
                Button {
                    onDiscard()
                } label: {
                    Label("Discard", systemImage: "xmark")
                        .font(.callout)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.regular)
                .keyboardShortcut(.escape, modifiers: [])

                Button {
                    onKeep()
                } label: {
                    Label("Keep & Save", systemImage: "checkmark")
                        .font(.callout)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut(.return, modifiers: [.command])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // ── Diff content ─────────────────────────────────────────────
            DiffRenderer(diffResults: diffResults)
                .padding(.vertical, 8)
        }
        .background(Color(NSColor.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}
