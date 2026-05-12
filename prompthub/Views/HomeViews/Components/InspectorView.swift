import SwiftUI
import SwiftData
import AlertToast

struct InspectorView: View {
    @Bindable var prompt: Prompt
    @Binding var selectedHistoryVersion: PromptHistory?
    
    // Toast Binding (Passed from parent)
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    
    @Query private var sharedCreations: [SharedCreation]
    
    private var existingSharedCreation: SharedCreation? {
        let name = prompt.name
        let content = prompt.getLatestPromptContent()
        return sharedCreations.first(where: { $0.name == name && $0.prompt == content })
    }
    
    // Actions
    let copyPromptToClipboard: (String) -> Bool
    let deleteHistoryItem: (PromptHistory) -> Void
    // New Actions for Sharing
    let onShare: () async -> Void
    let onTogglePublic: () async -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // Section 1: Metadata
            GroupBox(label: Label("Information", systemImage: "info.circle")) {
                VStack(alignment: .leading, spacing: 8) {
                    // Name (Editable)
                    Text("Name")
                        .font(.caption).bold()
                    TextField("Prompt Name", text: $prompt.name)
                        .textFieldStyle(.roundedBorder)
                    
                    // Description (Editable)
                    Text("Description")
                        .font(.caption).bold()
                    TextField("Description", text: Binding(
                        get: { prompt.desc ?? "" },
                        set: { prompt.desc = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                    
                    Divider()
                    
                    if let latest = prompt.history?.sorted(by: { $0.version > $1.version }).first {
                        LabeledContent("Version", value: "\(latest.version)")
                        LabeledContent("Created", value: latest.createdAt, format: .dateTime)
                        LabeledContent("Updated", value: latest.updatedAt, format: .dateTime)
                    } else {
                        Text("No data available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
                .padding(8)
            }
            
            // Section 2: Parameters (Placeholder for Phase 1)
            GroupBox(label: Label("Configuration", systemImage: "slider.horizontal.3")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Model: GPT-4o") // Placeholder
                        .font(.caption)
                    Text("Temperature: 0.7") // Placeholder
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
            
            // Section 3: Sharing & Community
            GroupBox(label: Label("Sharing", systemImage: "person.2.fill")) {
                VStack(alignment: .leading, spacing: 10) {
                    if let shared = existingSharedCreation {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Public Status")
                                    .font(.caption).bold()
                                Text(shared.isPublic ? "Visible to community" : "Private link only")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { shared.isPublic },
                                set: { _ in
                                    Task { await onTogglePublic() }
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                        }
                        
                        Divider()
                        
                        Button {
                            Task { await onShare() }
                        } label: {
                            Label("Update Share", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        
                    } else {
                        VStack(alignment: .center, spacing: 8) {
                            Text("Not shared yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button {
                                Task { await onShare() }
                            } label: {
                                Label("Share to Community", systemImage: "square.and.arrow.up")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                }
                .padding(8)
            }
            
            // Section 4: History
            GroupBox(label: Label("History", systemImage: "clock")) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if let history = prompt.history?.sorted(by: { $0.version > $1.version }), !history.isEmpty {
                            ForEach(history) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("v\(item.version)")
                                            .font(.caption).bold()
                                        Text(item.updatedAt, formatter: dateFormatter)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Actions for History Item
                                    HStack(spacing: 4) {
                                        Button {
                                            selectedHistoryVersion = item
                                        } label: {
                                            Image(systemName: "eye")
                                        }
                                        .buttonStyle(.plain)
                                        .help("View version")
                                        
                                        Button {
                                            _ = copyPromptToClipboard(item.promptText)
                                            showToastMsg("Copied v\(item.version)", .complete(.green))
                                        } label: {
                                            Image(systemName: "doc.on.doc")
                                        }
                                        .buttonStyle(.plain)
                                        .help("Copy")
                                    }
                                }
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(6)
                            }
                        } else {
                            Text("No history yet")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxHeight: 300) // limit height
            }
            
            Spacer()
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 300) // Fixed width for Inspector

    }
}
