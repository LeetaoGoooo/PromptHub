//
//  EditPromptSheet.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import SwiftData
import SwiftUI

struct EditPromptSheet: View {
    @State var prompt: Prompt // Use ObservedObject to observe changes from sheet
    @Binding var isPresented: Bool
    @State private var editedName: String

    init(prompt: Prompt, isPresented: Binding<Bool>) {
        self.prompt = prompt
        _isPresented = isPresented
        _editedName = State(initialValue: prompt.name) // Initialize with current name
    }

    var body: some View {
        NavigationView {
            Form {
                TextField("Prompt Name", text: $editedName)
            }
            .navigationTitle("Edit Prompt")
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .navigation) {
                    Button("Save") {
                        prompt.name = editedName // Update the prompt's name directly
                        do {
                            try prompt.modelContext?.save() // Save the context
                            print("Prompt name updated")
                        } catch {
                            print("Failed to save prompt name: \(error)")
                        }
                        isPresented = false
                    }
                }
            }
        }
    }
}
