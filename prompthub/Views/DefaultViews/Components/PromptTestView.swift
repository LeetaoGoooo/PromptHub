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
    
    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading) {
                Text("Test Content")
                    .font(.headline)
            
                TextEditor(text: $userInput)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                    .frame(minHeight: 120, maxHeight: 240)
            }
            .padding()
            
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
                }.disabled(userInput.isEmpty || isGenerating)
                
            }.padding(.horizontal)
               
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading) {
                    Text("Origin")
                        .font(.headline)
                    
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            TextEditor(text: .constant(originOutputResult))
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(8)
                                .disabled(true)
                                .frame(maxHeight: .infinity)
                        }
                            
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
                .frame(maxHeight: .infinity)
                
                VStack(alignment: .leading) {
                    Text("Refactor")
                        .font(.headline)
                  
                    ZStack(alignment: .bottomTrailing) {
                        ScrollView {
                            TextEditor(text: .constant(refactorOutputResult))
                                .padding(8)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .cornerRadius(8)
                                .disabled(true)
                                .frame(maxHeight: .infinity)
                        }
                            
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
                .frame(maxHeight: .infinity)
                
            }.padding()
        }
        .padding()
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
