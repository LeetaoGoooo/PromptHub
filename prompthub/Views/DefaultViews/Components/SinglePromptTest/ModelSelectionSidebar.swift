//
//  ModelSelectionSidebar.swift
//  prompthub
//
//  Created by leetao on 2025/9/2.
//

import SwiftUI
import GenKit

struct ModelSelectionSidebar: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SidebarHeader()
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ConfiguredModelsSection(viewModel: viewModel)
                    
                    if !viewModel.unconfiguredServices.isEmpty {
                        UnconfiguredServicesSection(
                            services: viewModel.unconfiguredServices,
                            onConfigure: { service in
                                viewModel.showToastMessage("Please configure \(service.name) in Settings", type: .regular)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
            
            Spacer()
            
            if !viewModel.configuredServiceModels.isEmpty {
                SelectionControls(viewModel: viewModel)
            }
        }
        .padding(16)
        .frame(minWidth: 250)
    }
}

// MARK: - Header
private struct SidebarHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Models")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Choose one or more models to test")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Configured Models
private struct ConfiguredModelsSection: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    
    var body: some View {
        ForEach(viewModel.configuredServiceModels, id: \.id) { serviceModel in
            ModelSelectionRow(
                serviceModel: serviceModel,
                isSelected: viewModel.selectedServiceModels.contains(serviceModel),
                onToggle: { viewModel.toggleSelection(for: serviceModel) }
            )
        }
    }
}

// MARK: - Model Selection Row
private struct ModelSelectionRow: View {
    let serviceModel: ServiceModel
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 16))
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(serviceModel.service.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(serviceModel.model.id)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Unconfigured Services
private struct UnconfiguredServicesSection: View {
    let services: [Service]
    let onConfigure: (Service) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 8)
            
            Text("Unconfigured Services")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.orange)
            
            Text("These services need API tokens to be used:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(services, id: \.id) { service in
                UnconfiguredServiceRow(service: service, onConfigure: onConfigure)
            }
        }
    }
}

private struct UnconfiguredServiceRow: View {
    let service: Service
    let onConfigure: (Service) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 14))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(service.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("API token required")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Configure") {
                onConfigure(service)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Selection Controls
private struct SelectionControls: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            Button("Select All") {
                viewModel.selectAllModels()
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedServiceModels.count == viewModel.configuredServiceModels.count)
            
            Button("Clear All") {
                viewModel.clearAllSelection()
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.selectedServiceModels.isEmpty)
        }
    }
}
