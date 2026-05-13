import SwiftUI
import AlertToast

// MARK: - Sub Views

extension PromptDetail {

    @ViewBuilder
    var promptHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                TextField("Prompt Name", text: $prompt.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .bold))
                    .focused($focusedField, equals: .name)
                    .padding(.horizontal, -4)
                Spacer()
                headerActions
            }
            TextField("Add a description...", text: Binding(
                get: { prompt.desc ?? "" },
                set: { prompt.desc = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.plain)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .padding(.horizontal, -4)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    var headerActions: some View {
        HStack(spacing: 8) {
            Button { isShowingSingleTestView.toggle() } label: { Label("Test", systemImage: "play.fill") }
                .buttonStyle(.bordered).controlSize(.small).help("Test this prompt")

            Button { isShowingDiff.toggle() } label: { Label("Diff", systemImage: "clock.arrow.circlepath") }
                .buttonStyle(.bordered).controlSize(.small).help("Toggle Diff View")

            Button(role: .destructive) {
                showingDeletePromptConfirmation = true
            } label: {
                Label(isEphemeralDraft ? "Discard" : "Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help(isEphemeralDraft ? "Discard this empty prompt draft" : "Delete this prompt")

            Divider().frame(height: 16).padding(.horizontal, 4)

            Button { Task { await shareCreation() } } label: {
                Image(systemName: "square.and.arrow.up").padding(4)
            }
            .buttonStyle(.plain).help("Share")
        }
    }

    func versionDetailSheet(_ version: PromptHistory) -> some View {
        let isCurrentVersion = history.first?.id == version.id

        return VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Version \(version.version)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(isCurrentVersion ? "Current editor version" : "Read-only history preview")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Dismiss") { selectedHistoryVersion = nil }
                    .buttonStyle(.bordered)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Created: \(version.createdAt, formatter: dateFormatter)").font(.subheadline)
                Text("Updated: \(version.updatedAt, formatter: dateFormatter)").font(.subheadline)
            }
            Text("Prompt Content").font(.headline)
            ScrollView {
                Text(version.promptText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }
            HStack {
                Spacer()
                Button {
                    let copied = copyPromptToClipboard(version.promptText)
                    showToastMsg(
                        msg: copied ? "Copied version \(version.version)" : "Failed to copy version \(version.version)",
                        alertType: copied ? .complete(Color.green) : .error(Color.red)
                    )
                } label: {
                    Label("Copy Content", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                Button {
                    applyHistoryVersionToEditor(version)
                } label: {
                    Label(isCurrentVersion ? "Already Current" : "Apply to Editor", systemImage: isCurrentVersion ? "checkmark.circle" : "arrow.down.doc")
                }
                .disabled(isCurrentVersion)
                .modifier(HistoryApplyButtonStyle(isCurrentVersion: isCurrentVersion))
                .help(isCurrentVersion ? "This version is already current" : "Create a new current version from this history entry")
                Spacer()
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}

private struct HistoryApplyButtonStyle: ViewModifier {
    let isCurrentVersion: Bool

    func body(content: Content) -> some View {
        if isCurrentVersion {
            content.buttonStyle(.bordered)
        } else {
            content.buttonStyle(.borderedProminent)
        }
    }
}
