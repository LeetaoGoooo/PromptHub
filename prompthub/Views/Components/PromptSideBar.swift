
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
    @State private var isEditingPromptSheetPresented: Bool = false // For sheet edit (you might keep this)
    @State private var promptToEditInSheet: Prompt? // For sheet edit
    @State private var promptToDelete: Prompt? // For delete confirmation
    @State private var editingPromptIds: Set<UUID> = [] // Track prompts being edited in-place

    @State private var searchText: String = ""
    @Binding var promptSelection: UUID?
    @Binding var isPresentingNewPromptDialog: Bool

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

            Button {
                isPresentingNewPromptDialog.toggle()

            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 16, height: 16)
                    Text("New Prompt")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)

            }.buttonStyle(.plain)
        }
        .searchable(text: $searchText, prompt: "Seach Prompt...")
        .sheet(isPresented: $isEditingPromptSheetPresented) { // Keep sheet edit if desired
            if let prompt = promptToEditInSheet {
                EditPromptSheet(prompt: prompt, isPresented: $isEditingPromptSheetPresented)
            }
        }
        .confirmationDialog( // Confirmation for delete
            "Are you sure you want to delete this prompt?",
            isPresented: isDeleteConfirmationPresented, // Present when promptToDelete is not nil
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let prompt = promptToDelete {
                    deletePrompt(prompt) // Single prompt delete function
                }
            }
            Button("Cancel", role: .cancel) {
                promptToDelete = nil // Clear promptToDelete on cancel
            }
        } message: {
            if let promptName = promptToDelete?.name {
                Text("Are you sure you want to delete '\(promptName)'?")
            } else {
                Text("Are you sure you want to delete this prompt?") // Fallback message
            }
        }
    }

    private var isDeleteConfirmationPresented: Binding<Bool> {
        Binding<Bool>(
            get: { promptToDelete != nil }, // Getter: Bool based on promptToDelete
            set: { newValue in // Setter: Control promptToDelete from Bool changes
                if !newValue { // If set to false (dialog dismissed)
                    promptToDelete = nil // Reset promptToDelete
                }
            }
        )
    }

    private func deletePrompts(at offsets: IndexSet) { // For swipe-to-delete, might not be needed on macOS
        for index in offsets {
            let promptToDelete = filteredPrompts[index]
            deletePrompt(promptToDelete) // Use single delete function
        }
    }

    private func promptNameTextField(for prompt: Prompt) -> some View {
        TextField("Prompt Name", text: promptNameBinding(for: prompt), onCommit: {
            editingPromptIds.remove(prompt.id)
        })
        .font(.body)
        .onSubmit { // For macOS to handle Enter key commit
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

    private func deletePrompt(_ prompt: Prompt) { // Single function to delete a prompt
        let promptId  = prompt.id;
        // 1. Fetch related PromptHistory records
        let relatedPromptHistoriesDescriptor = FetchDescriptor<PromptHistory>(predicate: #Predicate { history in
            history.promptId == promptId
        })

        do {
            let promptHistories = try modelContext.fetch(relatedPromptHistoriesDescriptor) // Execute fetch request

            // 2. Delete related PromptHistory records
            for history in promptHistories {
                modelContext.delete(history)
            }

            // 3. Delete the Prompt itself
            modelContext.delete(prompt)

            // 4. Save changes to persist deletions (both Prompt and PromptHistory)
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
