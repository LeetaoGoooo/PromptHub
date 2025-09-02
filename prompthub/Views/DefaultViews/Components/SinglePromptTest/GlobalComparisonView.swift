//
//  GlobalComparisonView.swift
//  prompthub
//
//  Created by leetao on 2025/9/2.
//

import SwiftUI
import GenKit

// MARK: - Global Comparison View
struct GlobalComparisonView: View {
    let prompt: String
    @Bindable var viewModel: SinglePromptTestViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Compare All Results")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close comparison view")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color(NSColor.separatorColor)),
                alignment: .bottom
            )
            
            GlobalComparisonScrollView(viewModel: viewModel)
        }
        .frame(idealWidth: 1400, idealHeight: 900)
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct GlobalComparisonScrollView: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 20) {
                ForEach(Array(viewModel.selectedServiceModels).sorted(by: { $0.displayName < $1.displayName }), id: \.id) { serviceModel in
                    GlobalComparisonColumn(
                    serviceModel: serviceModel,
                    viewModel: viewModel
                )
                }
            }
            .padding(20)
        }
    }
}

struct GlobalComparisonColumn: View {
    let serviceModel: ServiceModel
    @Bindable var viewModel: SinglePromptTestViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GlobalComparisonHeader(serviceModel: serviceModel, viewModel: viewModel)
            GlobalComparisonContent(serviceModel: serviceModel, viewModel: viewModel)
        }
    }
}

struct GlobalComparisonHeader: View {
    let serviceModel: ServiceModel
    @Bindable var viewModel: SinglePromptTestViewModel
    
    private var result: TestResult? {
        viewModel.testResults[serviceModel]
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(serviceModel.service.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(serviceModel.model.name ?? "Unknown Model")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                // Copy button - only show if there's content to copy
                if let result = result, !result.content.isEmpty, !result.isLoading {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(result.content, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.subheadline)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .help("Copy result to clipboard")
                }
                
                // Status indicator
                if let result = result {
                    Image(systemName: result.isLoading ? "clock.fill" : (result.hasError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"))
                        .foregroundColor(result.isLoading ? .orange : (result.hasError ? .red : .green))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct GlobalComparisonContent: View {
    let serviceModel: ServiceModel
    @Bindable var viewModel: SinglePromptTestViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    private var result: TestResult? {
        viewModel.testResults[serviceModel]
    }
    
    private var contentBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(NSColor.textBackgroundColor)
            : Color.white
    }
    
    var body: some View {
        ScrollView {
            Group {
                if let result = result {
                    if let error = result.error {
                        GlobalComparisonErrorView(error: error)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            GlobalComparisonResultText(content: result.content)
                            
                            if result.isLoading {
                                HStack {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                                        .scaleEffect(0.6)
                                    Text("Streaming...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                } else {
                    GlobalComparisonEmptyView()
                }
            }
        }
        .frame(width: 350)
        .frame(minHeight: 400)
        .background(contentBackgroundColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    }
}

struct GlobalComparisonLoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            Text("Generating...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

struct GlobalComparisonResultText: View {
    let content: String
    
    var body: some View {
        Text(content.isEmpty ? "No result yet..." : content)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(content.isEmpty ? .secondary : .primary)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
    }
}

struct GlobalComparisonEmptyView: View {
    var body: some View {
        Text("No result")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 200)
    }
}

struct GlobalComparisonErrorView: View {
    let error: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("Error occurred")
                .font(.headline)
            Text(error)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }
}
