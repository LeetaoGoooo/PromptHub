//
//  NewFolderDialog.swift
//  prompthub
//
//  Created by leetao on 2025/3/1.
//

import AlertToast
import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import QuickLook


struct NewPromptDialog: View {
    @State private var promptName: String = ""
    @State private var prompt: String = ""
    @State private var link: String = ""
    @State private var showingFileImporter = false
    @State private var selectedImage: NSImage?
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var desc:String = ""

    @Binding var isPresented: Bool // Binding to control the dialog's presentation

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 8) {
                Text("New Prompt")
                    .font(.headline)
                    .padding(.top)

                VStack(alignment: .leading) {
                    Text("Name")
                        .font(.subheadline)

                    TextField("Name", text: $promptName)
                        .padding(8) // Light gray background
                        .cornerRadius(6)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    Text("Description")
                        .font(.subheadline)

                    TextField("Description", text: $desc)
                        .padding(8)
                        .cornerRadius(6)
                }
                .padding(.horizontal)

                VStack(alignment: .leading) {
                    Text("Prompt")
                        .font(.subheadline)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $prompt)
                            .padding(4)
                            .frame(minHeight: 120, maxHeight: 240)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )

                        if prompt.isEmpty {
                            Text("New Prompt")
                                .foregroundColor(.gray.opacity(0.6))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }

                }.padding(.horizontal)

                VStack(alignment: .leading) {
                    Text("Source")
                        .font(.subheadline)

                    TextField("Source", text: $link)
                        .padding(8) // Light gray background
                        .cornerRadius(6)
                }
                .padding(.horizontal)

                DeletableImageView(image: $selectedImage)
                .contentShape(Rectangle())
                .onTapGesture {
                    showingFileImporter = true
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
                        if let url = urls.first {
                            loadImage(from: url)
                        }
                    case .failure(let error):
                        print("Error: Could not load image from file importer: \(error.localizedDescription)")
                    }
                }
                .frame(minWidth: 512, minHeight: 128)
                .padding(.vertical)

                HStack {
                    Spacer()
                    Button("Cancel") {
                        isPresented = false
                    }
                    .padding(.trailing, 10)

                    Button("OK") {
                        isPresented = false
                        Task { @MainActor in
                            savePrompt()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding([.horizontal, .bottom])
            }
            .padding(20)
            .background(colorScheme == .light ? Color.white : Color.black)
            .cornerRadius(12)
        }.toast(isPresenting: $showToast) {
            AlertToast(type: .error(Color.red), title: toastTitle)
        }
    }

    @MainActor
    func savePrompt() {
        do {
            let selectImageData: Data? = selectedImage?.png
            let externalSource: [Data] = selectImageData.map { [$0] } ?? []
            let promptName = promptName.trimmingCharacters(in: .whitespacesAndNewlines)
            let promptDesc = desc.trimmingCharacters(in: .whitespacesAndNewlines)
            let link = link.trimmingCharacters(in: .whitespacesAndNewlines)

            if promptName.isEmpty {
                showToastMsg(msg: "Name can't be empty")
                return
            }

            if !link.isEmpty, (URL(string: link) == nil || URL(string: link)?.scheme == nil) {
                showToastMsg(msg: "Source must be a valid URL (e.g. https://www.example.com)")
                return
            }

            let newPrompt = Prompt(name: promptName, desc: promptDesc.isEmpty ? nil : promptDesc, link: link.isEmpty ? nil : link, externalSource: externalSource)
            modelContext.insert(newPrompt)

            let prompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

            if prompt.isEmpty {
                showToastMsg(msg: "Prompt can't be empty")
                return
            }

            let newPromptHistory = newPrompt.createHistory(prompt: prompt, version: 0)
            modelContext.insert(newPromptHistory)

            // Save the context, committing the transaction.
            try modelContext.save()

            isPresented = false
        } catch {
            print("Failed to save prompt and PromptHistory transactionally: \(error)")
            showToastMsg(msg: "Failed to save prompt: \(error)")
        }
    }

    private func loadImage(from url: URL) {
        let RshouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if RshouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        if let image = NSImage(contentsOf: url) {
            selectedImage = image
        } else {
            showToastMsg(msg: "Error: Could not create NSImage from URL: \(url.path)")
            selectedImage = nil
            showToast = true
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        if provider.canLoadObject(ofClass: NSURL.self) {
            provider.loadObject(ofClass: NSURL.self) { object, error in
                DispatchQueue.main.async { // Ensure UI updates are on the main thread
                    if let fileURL = object as? URL { // Cast directly to URL
                        print("Successfully loaded item as URL: \(fileURL)")
                        self.processFileURL(fileURL)
                    } else if let err = error {
                        self.showToastMsg(msg: "Error loading item as NSURL/URL: \(err.localizedDescription)")
                        self.tryLoadingAsBookmarkData(provider: provider)
                    } else {
                        self.showToastMsg(msg: "Item was not a URL and no error occurred.")
                        self.tryLoadingAsBookmarkData(provider: provider)
                    }
                }
            }
            return true
        } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            DispatchQueue.main.async {
                self.tryLoadingAsBookmarkData(provider: provider)
            }
            return true
        } else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                DispatchQueue.main.async {
                    guard let imageData = data, error == nil else {
                        self.showToastMsg(msg: "Error loading image data: \(error?.localizedDescription ?? "Unknown error")")
                        return
                    }
                    print("Image data received directly. Size: \(imageData.count)")
                    self.showToastMsg(msg: "Received image data directly. Implement loading from Data.")
                }
            }
            return true
        }

        return false
    }

    private func tryLoadingAsBookmarkData(provider: NSItemProvider) {
        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, error in
            DispatchQueue.main.async {
                guard error == nil else {
                    self.showToastMsg(msg: "Error loading item data for bookmark: \(error!.localizedDescription)")
                    return
                }

                guard let bookmarkData = data else {
                    self.showToastMsg(msg: "No data received for bookmark.")
                    return
                }

                var isStale = false
                do {
                    let fileURL = try URL(resolvingBookmarkData: bookmarkData,
                                          options: .withSecurityScope,
                                          relativeTo: nil,
                                          bookmarkDataIsStale: &isStale)
                    if isStale {
                        self.showToastMsg(msg: "Bookmark data is stale. Consider re-selecting the file.")
                        return
                    }
                    print("Successfully resolved bookmark data to URL: \(fileURL)")
                    self.processFileURL(fileURL)
                } catch {
                    self.showToastMsg(msg: "Error resolving bookmark data: \(error.localizedDescription)")
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { innerItem, _ in
                        DispatchQueue.main.async {
                            print("Fallback: Raw item type when bookmark resolution failed: \(type(of: innerItem))")
                            print("Fallback: Raw item value: \(String(describing: innerItem))")
                        }
                    }
                }
            }
        }
    }

    private func processFileURL(_ url: URL) {
        do {
            let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey, .isAliasFileKey, .isSymbolicLinkKey])
            if resourceValues.isAliasFile == true || resourceValues.isSymbolicLink == true {
                showToastMsg(msg: "Note: Dropped item is an alias or symbolic link. URL should be to the target if resolved from a bookmark.")
                return
            }

            if let contentType = resourceValues.contentType {
                print("Content type: \(contentType.identifier), preferred MIME: \(contentType.preferredMIMEType ?? "N/A")")
                if contentType.conforms(to: .image) {
                    loadImage(from: url)
                } else {
                    showToastMsg(msg: "Dropped file is not an image type. Detected type: \(contentType.preferredMIMEType ?? contentType.identifier)")
                }
            } else {
                showToastMsg(msg: "Could not determine content type for dropped file.")
            }
        } catch {
            showToastMsg(msg: "Error getting resource values for dropped file: \(error.localizedDescription)")
        }
    }

    private func showToastMsg(msg: String) {
        print(msg)
        showToast.toggle()
        toastTitle = msg
    }
}

#Preview {
    @Previewable @State var isDialogPresented = true
    return NewPromptDialog(isPresented: $isDialogPresented)
        .modelContainer(PreviewData.previewContainer)
        .padding()
}
