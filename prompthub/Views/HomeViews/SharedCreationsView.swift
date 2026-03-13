//
//  SharedCreationsView.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import AlertToast
import CloudKit
import SwiftData
import SwiftUI

struct SharedCreationsView: View {
    @Environment(\.modelContext) private var modelContext
    
    let searchText: String
    let showToastMsg: (String, AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (String) -> Void
    
    @State private var publicSharedCreations: [SharedCreation] = []
    @State private var isLoading = false
    @State private var loadError: String?
    
    private func columns(for width: CGFloat) -> [GridItem] {
        return PromptViewHelpers.columns(for: width)
    }
    
    // Combine and categorize shared creations based on whether they exist locally
    // Items with publicRecordName that exist locally are user's creations
    private var categorizedSharedCreations: (userCreations: [SharedCreation], otherCreations: [SharedCreation]) {
        // Filter by search text first
        let filteredCreations: [SharedCreation]
        if searchText.isEmpty {
            filteredCreations = publicSharedCreations
        } else {
            filteredCreations = publicSharedCreations.filter { creation in
                creation.name.localizedCaseInsensitiveContains(searchText) ||
                    (creation.desc?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Categorize into user's and others' based on local existence
        let userCreations = filteredCreations.filter { creation in
            // If this SharedCreation exists locally (has been pushed from this device), it's user's creation
            SharedCreation.isCreatedByCurrentUser(id: creation.id, modelContext: modelContext)
        }
        
        let otherCreations = filteredCreations.filter { creation in
            // If this SharedCreation doesn't exist locally, it's from other users
            !SharedCreation.isCreatedByCurrentUser(id: creation.id, modelContext: modelContext)
        }
        
        return (
            userCreations: userCreations.sorted { $0.lastModified ?? Date.distantPast > $1.lastModified ?? Date.distantPast },
            otherCreations: otherCreations.sorted { $0.lastModified ?? Date.distantPast > $1.lastModified ?? Date.distantPast }
        )
    }
    
    private var filteredSharedCreations: [SharedCreation] {
        let categorized = categorizedSharedCreations
        return categorized.userCreations + categorized.otherCreations
    }
    
    @MainActor
    private func loadPublicSharedCreations() async {
        isLoading = true
        loadError = nil
        
        do {
            let syncManager = try PublicCloudKitSyncManager(
                containerIdentifier: CloudKitAccess.publicContainerIdentifier,
                modelContext: modelContext
            )
            let publicCreations = try await syncManager.fetchAllPublicSharedCreations(limit: 100)
            publicSharedCreations = publicCreations
            isLoading = false
        } catch {
            loadError = "Failed to load public shared creations: \(error.localizedDescription)"
            isLoading = false
            showToastMsg("Failed to load public creations", .error(.red))
        }
    }
    
    var body: some View {
        VStack {
            let categorized = categorizedSharedCreations
            
            if categorized.userCreations.isEmpty && categorized.otherCreations.isEmpty && !searchText.isEmpty {
                PromptViewHelpers.emptyStateView(
                    iconName: "magnifyingglass",
                    title: "No matching shared creations found",
                    subtitle: "Try using different keywords"
                )
            } else if categorized.userCreations.isEmpty && categorized.otherCreations.isEmpty {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Loading public shared creations...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        PromptViewHelpers.emptyStateView(
                            iconName: "square.and.arrow.up",
                            title: "No shared creations yet",
                            subtitle: "Share your prompts or explore public creations"
                        )
                    }
                }
            } else {
                GeometryReader { geometry in
                    ScrollView {
                        LazyVStack(spacing: 32) {
                            // User's own shared creations section
                            if !categorized.userCreations.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundColor(.blue)
                                        Text("My Shared Prompts")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                        
                                        Spacer()
                                        
                                        Text("\(categorized.userCreations.count)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    
                                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 20) {
                                        ForEach(categorized.userCreations, id: \.id) { creation in
                                            SharedCreationItemView(
                                                sharedCreation: creation,
                                                showToastMsg: showToastMsg,
                                                copyPromptToClipboard: copyPromptToClipboard,
                                                onDeleted: {
                                                    Task {
                                                        await loadPublicSharedCreations()
                                                    }
                                                }
                                            )
                                        }
                                    }
                                }
                            }
                            
                            // Public shared creations from others section
                            if !categorized.otherCreations.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Image(systemName: "person.3.fill")
                                            .foregroundColor(.green)
                                        Text("Community Gallery")
                                            .font(.title3)
                                            .fontWeight(.bold)
                                        
                                        Spacer()
                                        
                                        Text("\(categorized.otherCreations.count)")
                                            .font(.caption.monospacedDigit())
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.secondary.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    
                                    LazyVGrid(columns: columns(for: geometry.size.width), spacing: 20) {
                                        ForEach(categorized.otherCreations, id: \.id) { creation in
                                            SharedCreationItemView(
                                                sharedCreation: creation,
                                                showToastMsg: showToastMsg,
                                                copyPromptToClipboard: copyPromptToClipboard,
                                                onDeleted:nil
                                            )
                                        }
                                    }
                                }
                            }
                            
                            // Loading indicator for public creations
                            if isLoading {
                                HStack {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Updating gallery...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                            }
                        }
                        .padding(24)
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .refreshable {
                        await loadPublicSharedCreations()
                    }
                }
            }
        }
        .task {
            await loadPublicSharedCreations()
        }
    }
}

#Preview {
    SharedCreationsView(
        searchText: "",
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in }
    )
    .modelContainer(for: [Prompt.self, PromptHistory.self, SharedCreation.self, DataSource.self])
}
