//
//  SinglePromptTestView.swift
//  prompthub
//
import AlertToast
import GenKit
import SwiftUI

struct SinglePromptTestView: View {
    let prompt: String

    @Environment(ServicesManager.self) private var servicesManager
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: SinglePromptTestViewModel

    init(prompt: String) {
        self.prompt = prompt
        self._viewModel = State(initialValue: SinglePromptTestViewModel(servicesManager: ServicesManager()))
    }

    var body: some View {
        NavigationSplitView {
            ModelSelectionSidebar(viewModel: viewModel)
        } detail: {
            MainContentView(viewModel: viewModel, prompt: prompt) { dismiss() }
        }
        .frame(minWidth: 900, minHeight: 700)
        .toast(isPresenting: $viewModel.showToast) {
            AlertToast(type: viewModel.toastType, title: viewModel.toastTitle)
        }
        .sheet(isPresented: $viewModel.showGlobalComparisonView) {
            GlobalComparisonView(prompt: viewModel.userInput, viewModel: viewModel)
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
                Text("Single Prompt Test").font(.title2).fontWeight(.semibold).foregroundColor(.primary)
                Text("Test your prompt across multiple models").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle()).help("Close")
        }
        .padding(.horizontal, 20).padding(.top, 16)
    }
}

#Preview {
    SinglePromptTestView(prompt: "You are a helpful AI assistant. Please respond to the user's question clearly and concisely.")
        .environment(ServicesManager())
}
