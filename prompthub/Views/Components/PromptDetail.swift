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
    @State private var editablePrompt: String = ""
    @State private var isCopySuccess: Bool = false
    @State private var showOlderVersions: Bool = false
    @State private var selectedHistoryVersion: PromptHistory?
    @State private var isPreviewingOldVersion: Bool = false
    
    // Colors based on Apple design
    private let cardBackground = Color(NSColor.controlBackgroundColor)
    private let borderColor = Color(NSColor.separatorColor)
    
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
        
        // Auto-dismiss the success indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                isCopySuccess = false
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let latestHistory = history.first {
                    // Latest version card
                    latestVersionCard(latestHistory)
                    
                    // History section
                    if history.dropFirst().count > 0 {
                        historySection
                    } else {
                        noHistoryView
                    }
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if let latest = history.first {
                editablePrompt = latest.prompt
            }
        }
        .onChange(of: history) { newHistory in
            if let latest = newHistory.first, !isPreviewingOldVersion {
                editablePrompt = latest.prompt
            }
        }
        .sheet(item: $selectedHistoryVersion) { version in
            versionDetailSheet(version)
        }
    }
    
    // MARK: - Component Views
    
    private func latestVersionCard(_ latestHistory: PromptHistory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Latest Version")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    copyPromptToClipboard(latestHistory.prompt)
                } label: {
                    HStack {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Editor
            ZStack(alignment: .topLeading) {
                TextEditor(text: $editablePrompt)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 160)
                    .padding(10)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 1)
                    )
                    .onChange(of: editablePrompt) { newValue in
                        if !isPreviewingOldVersion {
                            latestHistory.prompt = newValue
                            latestHistory.updatedAt = Date()
                            try? modelContext.save()
                        }
                    }
                
                if isCopySuccess {
                    copiedSuccessMessage
                }
            }
            
            // Metadata
            metadataView(for: latestHistory)
                .padding(.top, 8)
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var historySection: some View {
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
    }
    
    private var noHistoryView: some View {
        Text("No history available for this prompt except the latest version.")
            .font(.callout)
            .foregroundColor(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(cardBackground)
            .cornerRadius(12)
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
            }
        }
        .padding(12)
        .background(Color(NSColor.alternatingContentBackgroundColors[history.version % 2]))
        .cornerRadius(8)
    }
    
    private func metadataView(for itemHistory: PromptHistory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 16) {
                metadataItem(label: "Created", value: itemHistory.createdAt, formatter: dateFormatter)
                metadataItem(label: "Updated", value: itemHistory.updatedAt, formatter: dateFormatter)
                metadataItem(label: "Version", value: "\(itemHistory.version)")
            }
            
            if isPreviewingOldVersion {
                HStack {
                    Text("Previewing older version")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Button("Return to latest") {
                        isPreviewingOldVersion = false
                        if let latest = history.first {
                            editablePrompt = latest.prompt
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .font(.caption)
                }
                .padding(.top, 4)
            }
        }
    }
    
    private func metadataItem(label: String, value: Date, formatter: DateFormatter) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value, formatter: formatter)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
    
    private func metadataItem(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text("\(label):")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
    
    private var copiedSuccessMessage: some View {
        Label("Copied!", systemImage: "checkmark.circle.fill")
            .padding(8)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .shadow(radius: 2)
            .padding(8)
            .transition(.scale.combined(with: .opacity))
    }
    
    private func versionDetailSheet(_ version: PromptHistory) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Version \(version.version) Details")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Dismiss") {
                    selectedHistoryVersion = nil
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Created: \(version.createdAt, formatter: dateFormatter)")
                    .font(.subheadline)
                Text("Updated: \(version.updatedAt, formatter: dateFormatter)")
                    .font(.subheadline)
            }
            
            Text("Prompt Content")
                .font(.headline)
            
            ScrollView {
                Text(version.prompt)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
            }
            
            HStack {
                Spacer()
                
                Button {
                    copyPromptToClipboard(version.prompt)
                } label: {
                    Label("Copy Content", systemImage: "doc.on.doc")
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button {
                    isPreviewingOldVersion = true
                    editablePrompt = version.prompt
                    selectedHistoryVersion = nil
                } label: {
                    Label("Preview in Editor", systemImage: "eye")
                        .padding(8)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try? ModelContainer(for: PromptHistory.self, configurations: config) // Handle the error here

    return PromptDetail(promptId: UUID())
        .environment(\.modelContext, ModelContext(container!))
}
