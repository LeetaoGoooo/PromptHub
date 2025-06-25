//
//  PublicSharedCreationItemView.swift
//  prompthub
//
//  Created by leetao on 2025/6/25.
//

import SwiftUI
import AlertToast

struct PublicSharedCreationItemView: View {
    let sharedCreation: SharedCreation
    let showToastMsg: (_ msg: String, _ alertType: AlertToast.AlertType) -> Void
    let copyPromptToClipboard: (_ prompt: String) -> Void
    let onImport: (SharedCreation) -> Void
    
    @State private var isHovering = false
    @State private var showingPreviewSheet = false
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.purple)
                            .font(.caption)
                        Text(sharedCreation.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                    
                    if let desc = sharedCreation.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let lastModified = sharedCreation.lastModified {
                        Text("Shared: \(lastModified.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button {
                        showingPreviewSheet = true
                    } label: {
                        Image(systemName: "eye")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 24, height: 24)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                    
                    Button {
                        copyPromptToClipboard(sharedCreation.prompt)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption)
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 24, height: 24)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
                    
                    Button {
                        isImporting = true
                        onImport(sharedCreation)
                        
                        // Reset importing state after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            isImporting = false
                        }
                    } label: {
                        Group {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 24, height: 24)
                    .background(Color.purple)
                    .cornerRadius(4)
                    .disabled(isImporting)
                }
                .opacity(isHovering ? 1.0 : 0.6)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
            }
            
            // Preview prompt text (first few lines)
            if !sharedCreation.prompt.isEmpty {
                Text(sharedCreation.prompt)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.top, 4)
            }
        }
        .padding()
        .onHover { hovering in
            isHovering = hovering
        }
        .sheet(isPresented: $showingPreviewSheet) {
            PublicSharedCreationPreviewSheet(sharedCreation: sharedCreation)
        }
    }
}

struct PublicSharedCreationPreviewSheet: View {
    let sharedCreation: SharedCreation
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.purple)
                        Text(sharedCreation.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    if let desc = sharedCreation.desc, !desc.isEmpty {
                        Text(desc)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastModified = sharedCreation.lastModified {
                        Text("Shared on \(lastModified.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            
            Divider()
            
            // Prompt Content
            VStack(alignment: .leading, spacing: 8) {
                Text("Prompt Content:")
                    .font(.headline)
                
                ScrollView {
                    Text(sharedCreation.prompt)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 300)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }
            
            // External Sources
            if let dataSources = sharedCreation.dataSources, !dataSources.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Attachments:")
                        .font(.headline)
                    
                    ScrollView(.horizontal) {
                        HStack {
                            ForEach(Array(dataSources.enumerated()), id: \.offset) { index, dataSource in
                                VStack {
                                    if let image = NSImage(data: dataSource.data) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 60)
                                            .cornerRadius(4)
                                    } else {
                                        Image(systemName: "doc")
                                            .font(.title)
                                            .foregroundColor(.secondary)
                                            .frame(width: 60, height: 60)
                                            .background(Color.gray.opacity(0.2))
                                            .cornerRadius(4)
                                    }
                                    
                                    Text("Attachment \(index + 1)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 600)
    }
}

#Preview {
    PublicSharedCreationItemView(
        sharedCreation: SharedCreation(
            name: "Sample Public Prompt",
            prompt: "This is a sample prompt from the public cloud that demonstrates how public shared creations appear.",
            desc: "A demonstration prompt"
        ),
        showToastMsg: { _, _ in },
        copyPromptToClipboard: { _ in },
        onImport: { _ in }
    )
    .frame(width: 300, height: 150)
}
