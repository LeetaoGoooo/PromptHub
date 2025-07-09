//
//  PromptPreviewView.swift
//  prompthub
//
//  Created by leetao on 2025/6/2.
//

import SwiftUI

struct PromptPreviewView: View {
    let promptName: String
    let promptContent: String
    let copyPromptToClipboard: (_ prompt: String) -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Text(promptName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .imageScale(.large)
                }
                .buttonStyle(PlainButtonStyle())
                .keyboardShortcut(.escape, modifiers: [])
            }


            ScrollView {
                Text(promptContent)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .textSelection(.enabled)
            }
            .frame(idealHeight: 300, maxHeight: .infinity)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )


            // 操作按钮
            HStack {
                Spacer()
                Button {
                    copyPromptToClipboard(promptContent)
                } label: {
                    Label("Copy Prompt", systemImage: "doc.on.doc")
                }

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(minWidth: 400, idealWidth: 500, maxWidth: 700,
               minHeight: 300, idealHeight: 450, maxHeight: 600)
    }
}

#Preview("Prompt Preview Sheet") {
    PromptPreviewView(
        promptName: "Sample Prompt Preview",
        promptContent: "This is the detailed content of the prompt. \nIt can span multiple lines and should be scrollable if it exceeds the available space. \nUsers should be able to select and copy this text easily. \n\nLorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
        copyPromptToClipboard: { text in print("Copied from preview: \(text)")}
    )
}
