//
//  PromptDetail.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct PromptDetail: View {
    @State var promptId: UUID
    @Environment(\.modelContext) private var modelContext
    @Query var history: [PromptHistory]
    @State private var editablePrompt: String = "" // State for editable prompt text
    @State private var isCopySuccess: Bool = false // Copy success or not

    init(promptId: UUID) {
        self._promptId = State(initialValue: promptId)
        _history = Query(filter: #Predicate<PromptHistory> { history in
            history.promptId == promptId
        }, sort: [SortDescriptor(\.version, order: .reverse)])
    }

    private func copyPromptToClipboard(_ prompt: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        withAnimation {
            isCopySuccess = true
        }
    }


    var body: some View {
        VStack(alignment: .leading) {
            if let latestHistory = history.first {
                HStack {
                    Text("Latest Version")
                    Spacer()
                    Button {
                        copyPromptToClipboard(latestHistory.prompt)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                }
                VStack(alignment: .leading) {
                    TextEditor(text: $editablePrompt)
                        .frame(minHeight: 100)
                        .padding(.bottom, 2)
                        .onChange(of: editablePrompt) { newValue in
                            latestHistory.prompt = newValue
                            latestHistory.updatedAt = Date()
                            try? modelContext.save()
                        }
                    Text("Created At: \(latestHistory.createdAt, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Updated At: \(latestHistory.updatedAt, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Version: \(latestHistory.version)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .overlay(alignment: .topTrailing) {
                    if isCopySuccess {
                        Label("Copied!", systemImage: "checkmark.circle.fill")
                            .padding(10)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                            .offset(x: -10, y: 10)
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation {
                                        isCopySuccess = false
                                    }
                                }
                            }
                    }
                }
                .padding()
            }

            if history.dropFirst().count > 0 {
                Section("History Versions") {
                    DisclosureGroup("Show Older Versions") {
                        ForEach(history.dropFirst()) { oldHistory in
                            VStack(alignment: .leading) {
                                Text("Version \(oldHistory.version)")
                                    .font(.headline)
                                Text("Updated At: \(oldHistory.updatedAt, formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("Prompt: \(oldHistory.prompt)")
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                            Divider()
                        }
                    }
                }
            } else {
                Text("No history available for this prompt except the latest version.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top)
            }
            Spacer()
        }
        .padding()
        .onAppear {
            if let latest = history.first {
                editablePrompt = latest.prompt
            }
        }
        .onChange(of: history) { newHistory in
            if let latest = newHistory.first {
                editablePrompt = latest.prompt
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try? ModelContainer(for: PromptHistory.self, configurations: config) // Handle the error here

    return PromptDetail(promptId: UUID())
        .environment(\.modelContext, ModelContext(container!))
}
