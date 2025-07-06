//
//  LatestVersionView.swift
//  prompthub
//
//  Created by leetao on 2025/3/16.
//

import AlertToast
import SwiftData
import SwiftUI

struct LatestVersionView: View {
    let latestHistory: PromptHistory
    let prompt: Prompt
    @Binding var editablePrompt: String
    @Binding var isGenerating: Bool
    @Binding var isPreviewingOldVersion: Bool
    @EnvironmentObject var settings: AppSettings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) var openURL
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastType: AlertToast.AlertType = .regular
    @State private var isCreateShareLink = false
    @State private var isTogglingPublic = false
    @State private var existingSharedCreation: SharedCreation?

    let copyPromptToClipboard: (_ prompt: String) -> Bool
    let copySharedLinkToClipboard: (_ url: URL) -> Bool
    let modifyPromptWithOpenAIStream: () async -> Void
    private let borderColor = Color(NSColor.separatorColor)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading) {
                    Text(prompt.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if prompt.desc != nil {
                        Text(prompt.desc!)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .help(prompt.desc!)
                    }
                }
                Spacer()

                HStack(alignment: .bottom) {
                    Spacer()

                    if let imageData = prompt.externalSource?.first {
                        HoverImageButton(imageData: imageData)
                    }

                    if let urlValue = prompt.link {
                        Button {
                            if let url = URL(string: urlValue) {
                                openURL(url) { accepted in
                                    if !accepted {
                                        Task { @MainActor in
                                            showToastMsg(msg: "Can't open: \(urlValue)")
                                        }
                                    }
                                }
                            } else {
                                Task { @MainActor in
                                    showToastMsg(msg: "Invalid URL: \(urlValue)")
                                }
                            }
                        } label: {
                            Image(systemName: "safari")
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .help("Origin")
                        .buttonStyle(PlainButtonStyle())
                    }
                    Button {
                        Task {
                            await shareCreation()
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .opacity(isCreateShareLink ? 0 : 1)
                            .overlay {
                                if isCreateShareLink {
                                    ProgressView()
                                        .scaleEffect(0.5)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .help("Share")
                    .buttonStyle(PlainButtonStyle())
                    .disabled(isCreateShareLink)

                    // Public toggle button - only show if prompt has been shared
                    if existingSharedCreation != nil {
                        Button {
                            Task {
                                await togglePublicStatus()
                            }
                        } label: {
                            Image(systemName: (existingSharedCreation?.isPublic  ?? true) ? "shared.with.you" : "shared.with.you.slash")
                                .opacity(isTogglingPublic ? 0 : 1)
                                .overlay {
                                    if isTogglingPublic {
                                        ProgressView()
                                            .scaleEffect(0.5)
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.1)
                                )
                                .cornerRadius(8)
                        }
                        .help(existingSharedCreation?.isPublic == true ? "Make Private" : "Make Public")
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isTogglingPublic)
                    }

                    Button {
                        let success = copyPromptToClipboard(latestHistory.promptText)
                        if success {
                            showToastMsg(msg: "Copy Prompt Succeed", alertType: .complete(Color.green))
                        } else {
                            showToastMsg(msg: "Copy Prompt Failed", alertType: .error(Color.red))
                        }
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                            .help("Copy")
                    }
                    .buttonStyle(PlainButtonStyle())
                }
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
                            latestHistory.promptText = newValue
                            latestHistory.updatedAt = Date()
                            try? modelContext.save()
                        }
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
            .toast(isPresenting: $showToast) {
                AlertToast(type: toastType, title: toastTitle)
            }
            .onAppear {
                checkForExistingSharedCreation()
            }
            .onChange(of: prompt) {
                    checkForExistingSharedCreation()
        }
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
                        editablePrompt = latestHistory.promptText
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

    @MainActor
    private func showToastMsg(msg: String, alertType: AlertToast.AlertType = .error(Color.red)) {
        print(msg)
        showToast.toggle()
        toastTitle = msg
        toastType = alertType
    }

    @MainActor
    private func shareCreation() async {
        isCreateShareLink = true

        // Check if a shared creation already exists for this prompt
        if let existingSharedItem = findExistingSharedCreation() {
            existingSharedCreation = existingSharedItem
            let urlScheme = "sharedprompt"
            guard let shareURL = URL(string: "\(urlScheme)://creation/\(existingSharedItem.id.uuidString)") else {
                showToastMsg(msg: "Could not create share URL")
                isCreateShareLink = false
                return
            }

            let success = copySharedLinkToClipboard(shareURL)
            if success {
                showToastMsg(msg: "Existing Share Link Copied", alertType: .complete(Color.green))
            } else {
                showToastMsg(msg: "Copy Share Link Failed", alertType: .error(Color.red))
            }
            isCreateShareLink = false
            return
        }

        // Create new shared creation if none exists
        let dataSources = prompt.externalSource?.map { DataSource(data: $0) } ?? []
        let sharedItem = SharedCreation(name: prompt.name, prompt: latestHistory.promptText, desc: prompt.desc, dataSources: dataSources)
        modelContext.insert(sharedItem)

        do {
            try modelContext.save()
            let publicCloudKitSyncManager = PublicCloudKitSyncManager(containerIdentifier: "iCloud.com.duck.leetao.promptbox", modelContext: modelContext)
            try await publicCloudKitSyncManager.pushItemToPublicCloud(sharedItem)
            existingSharedCreation = sharedItem
        } catch {
            showToastMsg(msg: "Error saving shared item: \(error)")
            isCreateShareLink = false
            return
        }

        let urlScheme = "sharedprompt"
        guard let shareURL = URL(string: "\(urlScheme)://creation/\(sharedItem.id.uuidString)") else {
            showToastMsg(msg: "Could not create share URL")
            isCreateShareLink = false
            return
        }

        let success = copySharedLinkToClipboard(shareURL)
        if success {
            showToastMsg(msg: "Share Link With Your Friends Now", alertType: .complete(Color.green))
        } else {
            showToastMsg(msg: "Create Share Link Failed", alertType: .error(Color.red))
        }
        isCreateShareLink = false
    }

    @MainActor
    private func togglePublicStatus() async {
        guard let sharedCreation = existingSharedCreation else { return }
        
        isTogglingPublic = true
        
        // Toggle the public status
        sharedCreation.isPublic.toggle()
        sharedCreation.lastModified = Date()
        
        do {
            try modelContext.save()
            let publicCloudKitSyncManager = PublicCloudKitSyncManager(containerIdentifier: "iCloud.com.duck.leetao.promptbox", modelContext: modelContext)
            try await publicCloudKitSyncManager.pushItemToPublicCloud(sharedCreation)
            
            let statusMessage = sharedCreation.isPublic ? "Prompt Made Public" : "Prompt Made Private"
            showToastMsg(msg: statusMessage, alertType: .complete(Color.green))
        } catch {
            // Revert the change if saving failed
            sharedCreation.isPublic.toggle()
            showToastMsg(msg: "Error updating prompt status: \(error)")
        }
        
        isTogglingPublic = false
    }
    
    private func checkForExistingSharedCreation() {
        existingSharedCreation = findExistingSharedCreation()
    }

    private func findExistingSharedCreation() -> SharedCreation? {
        // Capture the values as constants for the predicate
        let promptName = prompt.name
        let promptText = latestHistory.promptText
        let promptDesc = prompt.desc

        let descriptor = FetchDescriptor<SharedCreation>(
            predicate: #Predicate<SharedCreation> { sharedCreation in
                sharedCreation.name == promptName &&
                    sharedCreation.prompt == promptText &&
                    sharedCreation.desc == promptDesc
            }
        )

        do {
            let results = try modelContext.fetch(descriptor)
            // Return the most recently modified shared creation if multiple exist
            return results.max(by: { ($0.lastModified ?? Date.distantPast) < ($1.lastModified ?? Date.distantPast) })
        } catch {
            print("Error fetching existing shared creations: \(error)")
            return nil
        }
    }
}

#Preview {
    @Previewable @State var editablePrompt = "Sample editable prompt content"
    @Previewable @State var isGenerating = false
    @Previewable @State var isPreviewingOldVersion = false

    LatestVersionView(
        latestHistory: PreviewData.samplePromptHistory.first!,
        prompt: PreviewData.samplePrompt,
        editablePrompt: $editablePrompt,
        isGenerating: $isGenerating,
        isPreviewingOldVersion: $isPreviewingOldVersion,
        copyPromptToClipboard: { prompt in
            print("Copied: \(prompt)")
            return true
        },
        copySharedLinkToClipboard: { url in
            print("Copied link: \(url)")
            return true
        },
        modifyPromptWithOpenAIStream: {
            print("OpenAI modify requested")
        }
    )
    .modelContainer(PreviewData.previewContainer)
    .environmentObject(AppSettings())
    .padding()
}
