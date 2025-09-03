//
//  PromptTestView.swift
//  prompthub
//
//  Created by leetao on 2025/8/31.
//

import AlertToast
import GenKit
import SwiftUI

struct PromptTestView: View {
    let originPrompt: String
    let refactorPrompt: String
    
    @State private var userInput: String = ""
    
    @State private var originOutputResult = ""
    @State private var refactorOutputResult = ""
    @State private var isGenerating = false
    
    @State private var showToast = false
    @State private var toastTitle = ""
    @State private var toastType: AlertToast.AlertType = .regular
    
    @Environment(ServicesManager.self) private var servicesManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header with title and close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Prompt Comparison Test")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text("Compare the outputs of original and refactored prompts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .background(Color.clear)
                }
                .buttonStyle(PlainButtonStyle())
                .help("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Test Content")
                    .font(.headline)
                    .foregroundColor(.primary)
            
                TextEditor(text: $userInput)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .frame(minHeight: 120, maxHeight: 240)
            }
            .padding(16)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            HStack {
                if let selectedService = servicesManager.get(servicesManager.selectedServiceID) {
                    Label {
                        Text(selectedService.preferredChatModel ?? "Unknown Model")
                            .foregroundStyle(.secondary)
                        
                    } icon: {
                        Image(systemName: "shippingbox")
                    }
                }
                
                Spacer()
                
                Button {
                    Task {
                        await runComparison()
                    }
                } label: {
                    Label("Run", systemImage: "play")
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundColor(.accentColor)
                        .cornerRadius(8)
                }.disabled(userInput.isEmpty || isGenerating)
                    .buttonStyle(PlainButtonStyle())
                
            }.padding(.horizontal, 20)
               
            HStack(alignment: .top, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Origin")
                        .font(.headline)
                        .foregroundColor(.primary)
                 
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            TextEditor(text: .constant(originOutputResult))
                                .padding(12)
                                .background(Color(NSColor.textBackgroundColor))
                                .disabled(true)
                                .frame(maxHeight: .infinity)
                        }
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                        )
                        .cornerRadius(8)
                            
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(8)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                                .cornerRadius(8)
                                .padding([.top, .trailing], 10)
                        }
                    }
                }
                .padding(16)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .shadow(color: Color.blue.opacity(0.1), radius: 2, x: 0, y: 1)
                .frame(maxHeight: .infinity)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Refactor")
                        .font(.headline)
                        .foregroundColor(.primary)
         
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            TextEditor(text: .constant(refactorOutputResult))
                                .padding(12)
                                .background(Color(NSColor.textBackgroundColor))
                                .disabled(true)
                                .frame(maxHeight: .infinity)
                        }
                        .background(Color(NSColor.textBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                        )
                        .cornerRadius(8)
                            
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.7)
                                .padding(8)
                                .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
                                .cornerRadius(8)
                                .padding([.top, .trailing], 10)
                        }
                    }
                }
                .padding(16)
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)
                .shadow(color: Color.green.opacity(0.1), radius: 2, x: 0, y: 1)
                .frame(maxHeight: .infinity)
                
            }.padding(.horizontal, 20)
        }
        .padding(20)
        .background(Color(NSColor.windowBackgroundColor))
        .toast(isPresenting: $showToast) {
            AlertToast(type: toastType, title: toastTitle)
        }
    }
    
    private func runComparison() async {
        guard let selectedService = servicesManager.get(servicesManager.selectedServiceID) else {
            showToastMsg(msg: "No selected service found")
            return
        }
             
        guard !selectedService.token.isEmpty else {
            showToastMsg(msg: "Service token is missing")
            return
        }
             
        guard let modelId = selectedService.preferredChatModel,
              let model = selectedService.models.first(where: { $0.id == modelId })
        else {
            showToastMsg(msg: "Service model is missing or not configured")
            return
        }

        isGenerating = true
        originOutputResult = ""
        refactorOutputResult = ""
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.runPrompt(
                    prompt: self.originPrompt,
                    with: self.userInput,
                    service: selectedService,
                    model: model,
                    updating: self.$originOutputResult // 传入绑定
                )
            }
               
            group.addTask {
                await self.runPrompt(
                    prompt: self.refactorPrompt,
                    with: self.userInput,
                    service: selectedService,
                    model: model,
                    updating: self.$refactorOutputResult // 传入绑定
                )
            }
        }
          
        isGenerating = false
    }

    private func runPrompt(
        prompt: String,
        with input: String,
        service selectedService: Service,
        model: Model,
        updating outputBinding: Binding<String>
    ) async {
        do {
            guard let chatService = selectedService.modelService(session: nil) as? ChatService else {
                showToastMsg(msg: "Service does not support chat completion", alertType: .error(Color.orange))
                return
            }

            var streamRequest = ChatSessionRequest(service: chatService, model: model)
            streamRequest.with(system: prompt)
            streamRequest.with(history: [Message(role: .user, content: input)])

            for try await message in ChatSession.shared.stream(streamRequest) {
                if let contentChunk = message.content {
                    await MainActor.run {
                        outputBinding.wrappedValue = contentChunk
                    }
                }
            }
        } catch {
            await MainActor.run {
                showToastMsg(msg: "API request failed: \(error.localizedDescription)")
                outputBinding.wrappedValue = "Error: \(error.localizedDescription)"
            }
        }
    }

    @MainActor
    private func showToastMsg(msg: String, alertType: AlertToast.AlertType = .error(Color.red)) {
        showToast.toggle()
        toastTitle = msg
        toastType = alertType
    }
}

#Preview {
    PromptTestView(
        originPrompt: "TestPrompt", refactorPrompt: "Refactor Prompt"
    )
}
