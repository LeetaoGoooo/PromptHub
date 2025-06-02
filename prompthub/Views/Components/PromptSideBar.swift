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

    @State private var searchText: String = ""
    @Binding var promptSelection: Prompt?
    @Binding var isPresentingNewPromptDialog: Bool
    
    @Environment(\.openWindow) var openWindow
    
    
    var body: some View {
        VStack {
            List(selection: $promptSelection) {
                ForEach(filteredPrompts) { prompt in
                    Text(prompt.name)
                        .contextMenu {
                            Button("Edit") {
                                  self.isEditingPromptSheetPresented = true
                            }
                            .frame(width: 100)

                            Button("Delete") {
                                promptToDelete = prompt
                            }.frame(width: 100)
                        }.tag(prompt)
                }
                .onDelete(perform: deletePrompts)
            }

            HStack {
                Button {
                    isPresentingNewPromptDialog.toggle()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "plus.circle.fill")
                            .resizable()
                            .frame(width: 16, height: 16)
                        Text("New Prompt")
                    }

                }.buttonStyle(.plain)
                  
                
                Spacer()
                
                Button {
                    promptSelection = nil
                } label: {
                    Image(systemName: "lightbulb.max")
                }.buttonStyle(.plain)
                    .frame(width: 16, height: 16)
                
                Button {
                    openWindow(id: "settings-window")
                } label: {
                    Image(systemName: "gear")
                }.buttonStyle(.plain)
                    .frame(width: 16, height: 16)
                    
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .searchable(text: $searchText, prompt: "Seach Prompt...")
        .confirmationDialog( // Confirmation for delete
            "Are you sure you want to delete this prompt?",
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
                Text("Are you sure you want to delete '\(promptName)'?")
            } else {
                Text("Are you sure you want to delete this prompt?")
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
        for index in offsets {
            let promptToDelete = filteredPrompts[index]
            deletePrompt(promptToDelete)
        }
    }


    private func deletePrompt(_ prompt: Prompt) {
        let promptId  = prompt.id;
        let relatedPromptHistoriesDescriptor = FetchDescriptor<PromptHistory>(predicate: #Predicate { history in
            history.promptId == promptId
        })

        do {
            let promptHistories = try modelContext.fetch(relatedPromptHistoriesDescriptor)
            for history in promptHistories {
                modelContext.delete(history)
            }
            modelContext.delete(prompt)
            try modelContext.save()

        } catch {
            print("Failed to delete prompt or related history: \(error)")
        }
        promptToDelete = nil // Clear promptToDelete after deletion or cancel
    }

    private var filteredPrompts: [Prompt] {
        if searchText.isEmpty {
            return prompts
        } else {
            return prompts.filter { prompt in
                prompt.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}
