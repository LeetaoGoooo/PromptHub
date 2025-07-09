//
//  PromptSideBar.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import SwiftUI

struct PromptSideBar: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Prompt.name) var prompts: [Prompt]

    @Binding var isEditingPromptSheetPresented: Bool
    @State private var promptToDelete: Prompt?
    
    @Binding var promptSelection: PromptSelection
    @Binding var isPresentingNewPromptDialog: Bool
    
    @Environment(\.openWindow) var openWindow
    
    
    var body: some View {
        VStack(spacing: 0) {
            List(selection: $promptSelection) {
                // All Prompts section
                Section {
                    Label {
                        Text("All Prompts")
                    } icon: {
                        Image(systemName: "square.grid.2x2")
                    }
                    .tag(PromptSelection.allPrompts)
                }
                
                // User prompts section
                Section("My Prompts") {
                    ForEach(prompts) { prompt in
                        Label {
                            Text(prompt.name)
                        } icon: {
                            Image(systemName: "doc.text")
                        }
                        .contextMenu {
                            Button("Edit") {
                                  self.promptSelection = .prompt(prompt)
                                  self.isEditingPromptSheetPresented = true
                            }
                            .frame(width: 100)

                            Button("Delete", role: .destructive) {
                                promptToDelete = prompt
                            }.frame(width: 100)
                        }
                        .tag(PromptSelection.prompt(prompt))
                    }
                    .onDelete(perform: deletePrompts)
                }
            }
            .listStyle(.sidebar)
            .help("Click 'All Prompts' to browse all prompts, or select a specific prompt to view details")


            HStack {
                Button {
                    isPresentingNewPromptDialog.toggle()
                } label: {
                    HStack(spacing: 12) { // Adjusted spacing for better balance
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text("New Prompt")
                    }
                }
                .buttonStyle(.plain)
                .padding(.leading, 8) // Give the button some breathing room
                
                Spacer()
                
                Button {
                    openWindow(id: "settings-window")
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .padding(.trailing, 8)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.bar)
        }
        .confirmationDialog(
            "Delete Prompt", // Title is more direct
            isPresented: isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let prompt = promptToDelete {
                    deletePrompt(prompt)
                }
            }
            Button("Cancel", role: .cancel) {
                promptToDelete = nil
            }
        } message: {
            if let promptName = promptToDelete?.name {
                Text("Are you sure you want to delete '\(promptName)'? This action cannot be undone.")
            }
        }
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding<Bool>(
            get: { promptToDelete != nil },
            set: { newValue in
                if !newValue {
                    promptToDelete = nil
                }
            }
        )
    }

    private func deletePrompts(at offsets: IndexSet) {
        let promptsToDelete = offsets.map { prompts[$0] }
        for prompt in promptsToDelete {
             promptToDelete = prompt
        }
    }


    private func deletePrompt(_ prompt: Prompt) {
        // Delete the prompt - SwiftData will automatically cascade delete related history
        modelContext.delete(prompt)
        
        do {
            try modelContext.save()
            
            // Reset selection if the deleted prompt was currently selected
            if case .prompt(let selectedPrompt) = promptSelection, selectedPrompt == prompt {
                promptSelection = .allPrompts
            }
        } catch {
            print("Failed to delete prompt: \(error.localizedDescription)")
        }
        promptToDelete = nil
    }

}

#Preview {
    @Previewable @State var promptSelection: PromptSelection = .allPrompts
    @Previewable @State var isEditingPromptSheetPresented = false
    @Previewable @State var isPresentingNewPromptDialog = false
    
    PromptSideBar(
        isEditingPromptSheetPresented: $isEditingPromptSheetPresented,
        promptSelection: $promptSelection,
        isPresentingNewPromptDialog: $isPresentingNewPromptDialog
    )
    .modelContainer(PreviewData.previewContainer)
}
