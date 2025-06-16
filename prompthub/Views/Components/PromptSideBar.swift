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
        VStack(spacing: 0) {
            SearchBarView(searchText: $searchText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            List(selection: $promptSelection) {
                ForEach(filteredPrompts) { prompt in
                    Text(prompt.name)
                        .contextMenu {
                            Button("Edit") {
                                  self.promptSelection = prompt
                                  self.isEditingPromptSheetPresented = true
                            }
                            .frame(width: 100)

                            Button("Delete", role: .destructive) {
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
                    promptSelection = nil
                } label: {
                    Image(systemName: "lightbulb.max")
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                
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
        let promptsToDelete = offsets.map { filteredPrompts[$0] }
        for prompt in promptsToDelete {
             promptToDelete = prompt
        }
    }


    private func deletePrompt(_ prompt: Prompt) {
        let promptId = prompt.id
        let historyPredicate = #Predicate<PromptHistory> { $0.promptId == promptId }
        let relatedPromptHistoriesDescriptor = FetchDescriptor<PromptHistory>(predicate: historyPredicate)

        do {
            let promptHistories = try modelContext.fetch(relatedPromptHistoriesDescriptor)
            for history in promptHistories {
                modelContext.delete(history)
            }
            modelContext.delete(prompt)
            try modelContext.save()
            
            if promptSelection == prompt {
                promptSelection = nil
            }

        } catch {
            print("Failed to delete prompt or related history: \(error.localizedDescription)")
        }
        promptToDelete = nil
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
