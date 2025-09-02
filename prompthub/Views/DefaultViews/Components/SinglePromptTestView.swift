//
//  SinglePromptTestView.swift
//  prompthub
//
//  Created by leetao on 2025/9/2.
//

import AlertToast
import GenKit
import SwiftUI

// MARK: - Supporting Models
struct ServiceModel: Hashable, Identifiable {
    let service: Service
    let model: Model
    
    var id: String {
        "\(service.id)-\(model.id)"
    }
    
    var displayName: String {
        "\(service.name) - \(model.id)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(service.id)
        hasher.combine(model.id)
    }
    
    static func == (lhs: ServiceModel, rhs: ServiceModel) -> Bool {
        lhs.service.id == rhs.service.id && lhs.model.id == rhs.model.id
    }
}

@Observable
class TestResult {
    var content: String = ""
    var isLoading: Bool = false
    var error: String? = nil
    
    var hasError: Bool {
        error != nil
    }
    
    init(content: String = "", isLoading: Bool = false, error: String? = nil) {
        self.content = content
        self.isLoading = isLoading
        self.error = error
    }
}

// MARK: - Main View - Clean and Simple
struct SinglePromptTestView: View {
    let prompt: String
    
    @Environment(ServicesManager.self) private var servicesManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var viewModel: SinglePromptTestViewModel
    
    init(prompt: String) {
        self.prompt = prompt
        // Initialize with a placeholder, will be set in onAppear
        self._viewModel = State(initialValue: SinglePromptTestViewModel(servicesManager: ServicesManager()))
    }
    
    var body: some View {
        NavigationSplitView {
            ModelSelectionSidebar(viewModel: viewModel)
        } detail: {
            MainContentView(viewModel: viewModel, prompt: prompt) {
                dismiss()
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .toast(isPresenting: $viewModel.showToast) {
            AlertToast(type: viewModel.toastType, title: viewModel.toastTitle)
        }
        .sheet(isPresented: $viewModel.showGlobalComparisonView) {
            GlobalComparisonView(
                prompt: viewModel.userInput,
                viewModel: viewModel
            )
        }
        .onAppear {
            viewModel = SinglePromptTestViewModel(servicesManager: servicesManager)
        }
    }
}

// MARK: - Main Content View
private struct MainContentView: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    let prompt: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HeaderSection(onDismiss: onDismiss)
            TestInputSection(viewModel: viewModel)
            TestControlsSection(viewModel: viewModel, prompt: prompt)
            TestResultsSection(viewModel: viewModel)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Header Section
private struct HeaderSection: View {
    let onDismiss: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Single Prompt Test")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text("Test your prompt across multiple models")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .background(Color.clear)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Close")
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}

// MARK: - Extracted Components

struct TestResultCard: View {
    let serviceModel: ServiceModel
    let result: TestResult
    
    @State private var isExpanded = true
    @State private var showingFullScreen = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TestResultHeader(
                serviceModel: serviceModel,
                result: result,
                isExpanded: $isExpanded,
                onFullScreen: { showingFullScreen = true }
            )
            
            if isExpanded {
                TestResultContent(result: result)
                    .transition(.slide.combined(with: .opacity))
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .sheet(isPresented: $showingFullScreen) {
            TestResultFullScreenView(serviceModel: serviceModel, result: result)
        }
    }
}

struct TestResultHeader: View {
    let serviceModel: ServiceModel
    let result: TestResult
    @Binding var isExpanded: Bool
    let onFullScreen: () -> Void
    
    var body: some View {
        HStack {
            // Collapse/Expand button
            Button {
                isExpanded.toggle()
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Model info
            VStack(alignment: .leading, spacing: 2) {
                Text(serviceModel.service.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(serviceModel.model.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                if !result.content.isEmpty && result.error == nil {
                    Button {
                        onFullScreen()
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.caption)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("View in full screen")
                }
                
                // Status indicator
                Group {
                    if result.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else if result.error != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                    } else if !result.content.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(16)
        .contentShape(Rectangle())
        .onTapGesture {
            isExpanded.toggle()
        }
    }
}

struct TestResultContent: View {
    let result: TestResult
    @Environment(\.colorScheme) private var colorScheme
    
    // Better background color that's clearly distinguishable
    private var contentBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(NSColor.textBackgroundColor)
            : Color.white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            
            if let error = result.error {
                // Error display
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .padding(16)
                .background(Color.red.opacity(0.05))
            } else {
                // Content display with clear background
                ScrollView {
                    Text(result.content.isEmpty ? "No result yet..." : result.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(result.content.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .background(contentBackgroundColor)
                .overlay(
                    Rectangle()
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
                .frame(maxHeight: 200)
            }
        }
    }
}

struct TestResultFullScreenView: View {
    let serviceModel: ServiceModel
    let result: TestResult
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    private var fullScreenBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(NSColor.textBackgroundColor)
            : Color.white
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(serviceModel.service.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(serviceModel.model.id)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            // Full content with clear background
            if let error = result.error {
                VStack {
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(result.content.isEmpty ? "No result yet..." : result.content)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(result.content.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(fullScreenBackgroundColor)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
}

#Preview {
    SinglePromptTestView(prompt: "You are a helpful AI assistant. Please respond to the user's question clearly and concisely.")
        .environment(ServicesManager())
}
