//
//  NewFolderDialog.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//


import SwiftUI
import SwiftData

struct NewPromptDialog: View {
    @State private var promptName: String = ""
    @State private var prompt: String = ""
    @Binding var isPresented: Bool // Binding to control the dialog's presentation

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            // Overlay Background
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                     isPresented = false
                }

            // Dialog Box
            VStack(spacing: 8) {
                Text("New Prompt")
                    .font(.headline)
                    .padding(.top)

                VStack(alignment: .leading) {
                    Text("Name")
                        .font(.subheadline)

                    TextField("Name", text: $promptName)
                        .padding(8)// Light gray background
                        .cornerRadius(6)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading){
                    Text("Prompt")
                        .font(.subheadline)

                    TextField("New Prompt", text: $prompt,  axis: .vertical)
                        .padding(8)// Light gray background
                        .cornerRadius(6)
                        .lineLimit(5...10)
                 
                        
                }.padding(.horizontal)



                HStack {
                    Spacer() // Push buttons to the right
                    Button("Cancel") {
                        isPresented = false // Dismiss the dialog
                    }
                    .padding(.trailing, 10)

                    Button("OK") {
                      
                        isPresented = false // Dismiss the dialog
                        
                        Task { @MainActor in
                            savePrompt()
                        }
                        
                    }
                    .buttonStyle(.borderedProminent) // Use prominent style for OK
                }
                .padding([.horizontal, .bottom])
            }
            .padding(20)
            .background(colorScheme == .light ? Color.white : Color.black)
            .cornerRadius(12)
        }
    }
    
    @MainActor
    func savePrompt() {
        do {
            let newPrompt = Prompt(name: promptName)
            modelContext.insert(newPrompt)

            let newPromptHistory = PromptHistory(promptId: newPrompt.id, prompt: prompt)
            modelContext.insert(newPromptHistory)

            // Save the context, committing the transaction.
            try modelContext.save()


        } catch {
            print("Failed to save prompt and PromptHistory transactionally: \(error)")
        }
    }
}

// Preview Provider (for Xcode Canvas)
struct NewPromptDialog_Previews: PreviewProvider {
    static var previews: some View {
        @State var isDialogPresented = true // State for preview purposes
        return NewPromptDialog(isPresented: $isDialogPresented)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
