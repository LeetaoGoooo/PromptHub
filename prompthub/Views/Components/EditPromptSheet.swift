//
//  EditPromptSheet.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import AlertToast
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct EditPromptSheet: View {
    @State var prompt: Prompt
    @Binding var isPresented: Bool
    @State private var editedName: String
    @State private var editedLink: String
    @State private var editedDesc: String
    @State private var selectedImage: NSImage?
    @State private var showingFileImporter = false
    @State private var showToast = false
    @State private var toastTitle = ""
    
    @Environment(\.colorScheme) private var colorScheme

    init(prompt: Prompt, isPresented: Binding<Bool>) {
        self.prompt = prompt
        _isPresented = isPresented
        _editedName = State(initialValue: prompt.name)
        _editedLink = State(initialValue: prompt.link ?? "")
        _editedDesc = State(initialValue: prompt.desc ?? "")
        
        if let imageData = prompt.externalSource?.first {
            _selectedImage = State(initialValue: NSImage(data: imageData))
        } else {
            _selectedImage = State(initialValue: nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Text("Name")
                    .font(.subheadline)
                TextField("Prompt Name", text: $editedName)
            }.padding(.horizontal)
            
            VStack(alignment: .leading) {
                Text("Description")
                    .font(.subheadline)
                TextField("Description", text: $editedDesc)
            }.padding(.horizontal)
            
            
            VStack(alignment: .leading) {
                Text("Source")
                    .font(.subheadline)
                TextField("Source", text: $editedLink)
            }.padding(.horizontal)
            

            VStack {
                DeletableImageView(image: $selectedImage)
                
                HStack {
                    Text("Attachment")
                    Spacer()
                    Button {
                        showingFileImporter = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                }
            }
                
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [UTType.image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else {
                        showToastMsg(msg: "No URL selected")
                        return
                    }
                    loadImage(from: url)
                case .failure(let error):
                    showToastMsg(msg: "Error selecting file: \(error.localizedDescription)")
                    selectedImage = nil
                }
            }
        }
        .padding()
        .frame(minWidth: 400, idealWidth: 500, maxWidth: .infinity,
               minHeight: 300, idealHeight: 450, maxHeight: .infinity)
        .navigationTitle("Edit Prompt")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isPresented = false
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    updatePrompt()
                    isPresented = false
                }
            }
        }
        .toast(isPresenting: $showToast) {
            AlertToast(type: .error(Color.red), title: toastTitle)
        }
    }
    
    @MainActor
    private func updatePrompt() {
        do {
            // Update prompt properties
            prompt.name = editedName
            prompt.link = editedLink
            prompt.desc = editedDesc.isEmpty ? nil : editedDesc.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Update image data
            if let imageData = selectedImage?.png {
                prompt.externalSource = [imageData]
            } else {
                prompt.externalSource = nil
            }
            
            // Save changes to the prompt
            try prompt.modelContext?.save()
            print("Prompt updated")
            
        } catch {
            print("Failed to update prompt: \(error)")
            showToastMsg(msg: "Failed to update prompt: \(error.localizedDescription)")
        }
    }
    
    private func loadImage(from url: URL) {
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let image = NSImage(contentsOf: url) {
            selectedImage = image
        } else {
            showToastMsg(msg: "Error: Could not create NSImage from URL")
            selectedImage = nil
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.canLoadObject(ofClass: NSURL.self) {
            provider.loadObject(ofClass: NSURL.self) { object, error in
                DispatchQueue.main.async {
                    if let fileURL = object as? URL {
                        self.processFileURL(fileURL)
                    } else if let err = error {
                        self.showToastMsg(msg: "Error loading item as URL: \(err.localizedDescription)")
                    } else {
                        self.showToastMsg(msg: "Item was not a URL and no error occurred.")
                    }
                }
            }
            return true
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                DispatchQueue.main.async {
                    guard let imageData = data, error == nil else {
                        self.showToastMsg(msg: "Error loading image data")
                        return
                    }
                    if let image = NSImage(data: imageData) {
                        self.selectedImage = image
                    } else {
                        self.showToastMsg(msg: "Invalid image data")
                    }
                }
            }
            return true
        }
        return false
    }

    private func processFileURL(_ url: URL) {
        if url.pathExtension.lowercased() == "png" ||
            url.pathExtension.lowercased() == "jpg" ||
            url.pathExtension.lowercased() == "jpeg"
        {
            loadImage(from: url)
        } else {
            showToastMsg(msg: "Unsupported file type. Please use an image file.")
        }
    }

    private func showToastMsg(msg: String) {
        print(msg)
        toastTitle = msg
        showToast = true
    }
}

#Preview {
    @Previewable @State var isPresented = true
    EditPromptSheet(prompt: PreviewData.samplePrompt, isPresented: $isPresented)
        .modelContainer(PreviewData.previewContainer)
}
