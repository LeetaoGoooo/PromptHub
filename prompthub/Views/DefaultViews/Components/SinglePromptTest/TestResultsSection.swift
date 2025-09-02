//
//  TestResultsSection.swift
//  prompthub
//
//  Created by leetao on 2025/9/2.
//

import SwiftUI

struct TestResultsSection: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    
    var body: some View {
        if !viewModel.testResults.isEmpty {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(Array(viewModel.selectedServiceModels).sorted(by: { $0.displayName < $1.displayName }), id: \.id) { serviceModel in
                        TestResultCard(
                            serviceModel: serviceModel,
                            result: viewModel.testResults[serviceModel] ?? TestResult()
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}
