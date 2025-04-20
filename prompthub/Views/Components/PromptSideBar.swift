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

    @State private var isEditingMode: Bool = false
    @State private var isEditingPromptSheetPresented: Bool = false
    @State private var promptToEditInSheet: Prompt?
    @State private var promptToDelete: Prompt?
    @State private var editingPromptIds: Set<UUID> = []

    @State private var searchText: String = ""
    @Binding var promptSelection: UUID?
    @Binding var isPresentingNewPromptDialog: Bool
    
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        VStack {
            List(selection: $promptSelection) {
                ForEach(filteredPrompts) { prompt in
                    if editingPromptIds.contains(prompt.id) {
                        promptNameTextField(for: prompt)
                    } else {
                        Text(prompt.name)
                            .tag(prompt.persistentModelID)
                            .contextMenu {
                                Button("Edit") {
                                    editingPromptIds.insert(prompt.id)
                                }
                                .frame(width: 100)

                                Button("Delete") {
                                    promptToDelete = prompt
                                }.frame(width: 100)
                            }
                    }
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
        .sheet(isPresented: $isEditingPromptSheetPresented) {
            if let prompt = promptToEditInSheet {
                EditPromptSheet(prompt: prompt, isPresented: $isEditingPromptSheetPresented)
            }
        }
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

    private func promptNameTextField(for prompt: Prompt) -> some View {
        TextField("Prompt Name", text: promptNameBinding(for: prompt), onCommit: {
            editingPromptIds.remove(prompt.id)
        })
        .font(.body)
        .onSubmit {
            editingPromptIds.remove(prompt.id)
        }
    }

    private func promptNameBinding(for prompt: Prompt) -> Binding<String> {
        Binding<String>(
            get: { prompt.name },
            set: { newName in
                prompt.name = newName
                do {
                    try modelContext.save()
                } catch {
                    print("Error saving edited prompt: \(error)")
                }
            }
        )
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

struct PromptSideBar_Previews: PreviewProvider {
    static var previews: some View {
        @State var promptSelection: UUID? = nil
        @State var isPresentingNewPromptDialog = false

        return PromptSideBar(promptSelection: $promptSelection, isPresentingNewPromptDialog: $isPresentingNewPromptDialog)
            .modelContainer(for: [Prompt.self, PromptHistory.self], inMemory: true)
    }
}
