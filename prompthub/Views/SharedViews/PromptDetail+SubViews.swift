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

            Divider().frame(height: 16).padding(.horizontal, 4)

            Button { Task { await shareCreation() } } label: {
                Image(systemName: "square.and.arrow.up").padding(4)
            }
            .buttonStyle(.plain).help("Share")
        }
    }

    func versionDetailSheet(_ version: PromptHistory) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Version \(version.version) Details").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Dismiss") { selectedHistoryVersion = nil }.buttonStyle(PlainButtonStyle())
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
                Button { copyPromptToClipboard(version.promptText) } label: {
                    Label("Copy Content", systemImage: "doc.on.doc").padding(8)
                }.buttonStyle(PlainButtonStyle())
                Button {
                    isPreviewingOldVersion = true
                    editablePrompt = version.promptText
                    selectedHistoryVersion = nil
                } label: {
                    Label("Preview in Editor", systemImage: "eye").padding(8)
                }.buttonStyle(PlainButtonStyle())
                Spacer()
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}
