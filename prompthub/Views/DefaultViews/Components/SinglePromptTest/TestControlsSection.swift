//
//  TestControlsSection.swift
//  prompthub
//
//  Created by leetao on 2025/9/2.
//

import SwiftUI

struct TestControlsSection: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    let prompt: String
    
    var body: some View {
        HStack {
            StatusText(viewModel: viewModel)
            
            Spacer()
            
            ActionButtons(viewModel: viewModel, prompt: prompt)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Status Text
private struct StatusText: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    
    var body: some View {
        if viewModel.configuredServiceModels.isEmpty {
            Text("No configured services available")
                .foregroundColor(.orange)
                .font(.caption)
        } else {
            Text("\(viewModel.selectedServiceModels.count) of \(viewModel.configuredServiceModels.count) models selected")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

// MARK: - Action Buttons
private struct ActionButtons: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    let prompt: String
    
    var body: some View {
        HStack {
            RunTestsButton(viewModel: viewModel, prompt: prompt)
            CompareAllButton(viewModel: viewModel)
        }
    }
}

private struct RunTestsButton: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    let prompt: String
    
    var body: some View {
        Button {
            Task {
                await viewModel.runTests(with: prompt)
            }
        } label: {
            Label("Run Tests", systemImage: "play.fill")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .cornerRadius(8)
        }
        .disabled(!viewModel.canRunTests)
        .buttonStyle(PlainButtonStyle())
    }
}

private struct CompareAllButton: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    
    var body: some View {
        Button {
            viewModel.showGlobalComparisonView = true
        } label: {
            Label("Compare All", systemImage: "rectangle.split.3x1")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(8)
        }
        .disabled(!viewModel.canCompareAll)
        .buttonStyle(PlainButtonStyle())
    }
}
