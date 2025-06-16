//
//  SearchBarView.swift
//  prompthub
//
//  Created by leetao on 2025/6/16.
//

import SwiftUICore
import SwiftUI


struct SearchBarView: View {
    @Binding var searchText: String
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.primary)
            
            TextField("Search prompt...", text: $searchText)
                .textFieldStyle(.plain)
                .focused($isTextFieldFocused)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }
        }
        .padding(8)
        .background(Color(.unemphasizedSelectedContentBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            DispatchQueue.main.async {
                isTextFieldFocused = true
            }
        }
    }
}
