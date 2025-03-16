import AppKit
import SwiftUI

struct HistorySectionView: View {
    let history: [PromptHistory]
    @Binding var showOlderVersions: Bool
    @Binding var selectedHistoryVersion: PromptHistory?
    @Binding var isPreviewingOldVersion: Bool
    @Binding var editablePrompt: String
    let copyPromptToClipboard: (_ prompt: String) -> Void
    let deleteHistoryItem: (_ historyItem: PromptHistory) -> Void
    private let cardBackground = Color(NSColor.controlBackgroundColor)
    @State private var showDeleteConfirmation: Bool = false
    @State private var itemToDelete: PromptHistory?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("History Versions")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Button {
                    withAnimation {
                        showOlderVersions.toggle()
                    }
                } label: {
                    HStack {
                        Text(showOlderVersions ? "Hide" : "Show")
                        Image(systemName: showOlderVersions ? "chevron.up" : "chevron.down")
                    }
                    .font(.subheadline)
                }
                .buttonStyle(PlainButtonStyle())
            }

            if showOlderVersions {
                LazyVStack(spacing: 10) {
                    ForEach(history.dropFirst()) { oldHistory in
                        historyItemView(for: oldHistory)
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .frame(maxWidth: .infinity)
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Confirm Delete"),
                message: itemToDelete.map { Text("Are you sure you want to delete version \($0.version)?") },
                primaryButton: .destructive(Text("Delete")) {
                    if let itemToDelete = itemToDelete {
                        deleteHistoryItem(itemToDelete)
                    }
                    self.itemToDelete = nil
                },
                secondaryButton: .cancel {
                    self.itemToDelete = nil
                }
            )
        }
    }

    private func historyItemView(for history: PromptHistory) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Version \(history.version)")
                    .font(.headline)
                    .foregroundColor(.primary)

                Text(history.updatedAt, formatter: dateFormatter)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(history.prompt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    isPreviewingOldVersion = true
                    editablePrompt = history.prompt
                } label: {
                    Image(systemName: "eye")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    selectedHistoryVersion = history
                } label: {
                    Image(systemName: "info.circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    copyPromptToClipboard(history.prompt)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())

                Button {
                    itemToDelete = history
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
        .background(Color(NSColor.systemGray.withAlphaComponent(0.1)))
        .cornerRadius(8)
    }
}
