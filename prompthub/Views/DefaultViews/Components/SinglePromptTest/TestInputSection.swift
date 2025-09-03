//
//  TestInputSection.swift
//  prompthub
//
//  Created by leetao on 2025/9/2.
//

import SwiftUI

struct TestInputSection: View {
    @Bindable var viewModel: SinglePromptTestViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Content")
                .font(.headline)
                .foregroundColor(.primary)
            
            StyledTextEditor(text: $viewModel.userInput)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Styled Text Editor with Clear Distinction
private struct StyledTextEditor: View {
    @Binding var text: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var editorBackgroundColor: Color {
        colorScheme == .dark 
            ? Color(NSColor.textBackgroundColor).opacity(0.8)
            : Color.white
    }
    
    private var editorBorderColor: Color {
        colorScheme == .dark 
            ? Color.gray.opacity(0.4)
            : Color.gray.opacity(0.3)
    }
    
    var body: some View {
        TextEditor(text: $text)
            .font(.system(.body, design: .default))
            .padding(12)
            .background(editorBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(editorBorderColor, lineWidth: 1)
            )
            .cornerRadius(8)
            .frame(minHeight: 120, maxHeight: 200)
            .overlay(
                // Placeholder text
                Group {
                    if text.isEmpty {
                        Text("Enter your test input here...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                },
                alignment: .topLeading
            )
    }
}
