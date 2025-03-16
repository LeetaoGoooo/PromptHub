//
//  LatestVersionView.swift
//  prompthub
//
//  Created by leetao on 2025/3/16.
//

import SwiftUI

struct LatestVersionView: View {
    let latestHistory: PromptHistory
    @Binding var editablePrompt: String
    @Binding var isCopySuccess: Bool
    @Binding var isGenerating: Bool
    @Binding var isPreviewingOldVersion: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    let copyPromptToClipboard: (_ prompt: String) -> Void
    let modifyPromptWithOpenAIStream: () async -> Void
    private let borderColor = Color(NSColor.separatorColor)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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

            ZStack(alignment: .bottomTrailing) {
                NoScrollBarTextEditor(text: $editablePrompt, font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular), autoScroll: isGenerating)
                    .frame(minHeight: 300)
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

                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(8)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                        .cornerRadius(8)
                        .padding([.bottom, .trailing], 40)
                }

                Button {
                    Task { await modifyPromptWithOpenAIStream() }
                } label: {
                    Image(systemName: "wand.and.stars")
                }
                .padding(8)
                .disabled(!settings.isTestPassed)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(12)
            .padding(16)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)

            metadataView(for: latestHistory)
                .padding(.top, 8)
        }.frame(maxWidth: .infinity)
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
                        editablePrompt = latestHistory.prompt
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
}
