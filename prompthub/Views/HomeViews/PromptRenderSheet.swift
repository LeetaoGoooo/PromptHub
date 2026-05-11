import SwiftData
import SwiftUI

/// A sheet that lets the user pick a saved prompt, fill in `{{variable}}` placeholders,
/// and view the rendered result — inspired by the "prompt get/render" CLI command concept.
struct PromptRenderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Prompt.name) private var prompts: [Prompt]

    let initialPromptID: UUID?
    let onDismiss: () -> Void

    @State private var selectedPromptID: UUID?
    @State private var variables: [String: String] = [:]
    @State private var searchText = ""
    @State private var isCopied = false

    init(initialPromptID: UUID? = nil, onDismiss: @escaping () -> Void) {
        self.initialPromptID = initialPromptID
        self.onDismiss = onDismiss
    }

    private var selectedPrompt: Prompt? {
        guard let id = selectedPromptID else { return nil }
        return prompts.first(where: { $0.id == id })
    }

    private var rawText: String {
        guard let prompt = selectedPrompt else { return "" }
        // Use the latest history entry as the prompt text.
        return prompt.history?
            .sorted(by: { $0.version > $1.version })
            .first?.promptText ?? ""
    }

    private var detectedVariables: [String] {
        let pattern = "\\{\\{([^}]+)\\}\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: rawText, range: NSRange(rawText.startIndex..., in: rawText))
        var seen = Set<String>()
        var result: [String] = []
        for match in matches {
            if let range = Range(match.range(at: 1), in: rawText) {
                let varName = String(rawText[range]).trimmingCharacters(in: .whitespaces)
                if seen.insert(varName).inserted {
                    result.append(varName)
                }
            }
        }
        return result
    }

    private var renderedText: String {
        var result = rawText
        for varName in detectedVariables {
            let value = variables[varName] ?? ""
            result = result.replacingOccurrences(of: "{{\(varName)}}", with: value)
        }
        return result
    }

    private var filteredPrompts: [Prompt] {
        if searchText.isEmpty { return prompts }
        return prompts.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Standard sheet header bar
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Render Prompt")
                        .font(.headline)
                    Text("Fill in variables and copy the rendered output")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Close", action: onDismiss)
                    .keyboardShortcut(.escape)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            HSplitView {
                // Left: prompt picker
                VStack(spacing: 0) {
                    TextField("Search prompts…", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .padding(10)

                    Divider()

                    List(filteredPrompts, id: \.id, selection: $selectedPromptID) { prompt in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.name)
                                .font(.callout.weight(.medium))
                                .lineLimit(1)
                            if let desc = prompt.desc, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .tag(prompt.id)
                    }
                    .listStyle(.sidebar)
                }
                .frame(minWidth: 200, maxWidth: 240)

                // Right: render panel
                VStack(spacing: 0) {
                    if selectedPrompt == nil {
                        VStack(spacing: 8) {
                            Image(systemName: "text.cursor")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("Select a prompt to render")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        renderPanel
                    }
                }
            }
        }
        .frame(minWidth: 680, minHeight: 480)
        .onAppear {
            guard selectedPromptID == nil else { return }
            if let initialPromptID, prompts.contains(where: { $0.id == initialPromptID }) {
                selectedPromptID = initialPromptID
            }
        }
        .onChange(of: selectedPromptID) { _, _ in
            variables = [:]
            isCopied = false
        }
    }

    // MARK: - Render Panel

    private var renderPanel: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Text(selectedPrompt?.name ?? "")
                    .font(.headline)
                Spacer()
                if isCopied {
                    Label("Copied!", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(renderedText, forType: .string)
                    isCopied = true
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        isCopied = false
                    }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(renderedText.isEmpty)
            }
            .padding(12)

            Divider()

            HSplitView {
                // Variable inputs (if any)
                if !detectedVariables.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Variables")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 6)

                        Divider()

                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(detectedVariables, id: \.self) { varName in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(varName)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(.secondary)
                                        TextField("Enter value…", text: Binding(
                                            get: { variables[varName] ?? "" },
                                            set: { variables[varName] = $0 }
                                        ))
                                        .textFieldStyle(.roundedBorder)
                                        .font(.callout)
                                    }
                                }
                            }
                            .padding(12)
                        }
                    }
                    .frame(minWidth: 180, maxWidth: 220)
                }

                // Rendered output
                ScrollView {
                    Text(renderedText.isEmpty ? rawText : renderedText)
                        .font(.body)
                        .foregroundStyle(renderedText.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(14)
                        .textSelection(.enabled)
                }
                .background(Color(NSColor.textBackgroundColor))
            }
        }
    }
}
