//
//  SearchBarView.swift
//  prompthub
//
//  Created by leetao on 2025/6/16.
//

import SwiftUI


struct SearchBarView: View {
    @Binding var searchText: String
    
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.primary)
            
            TextField("Search prompt...", text: $searchText)
                .textFieldStyle(.plain)
                .focused(isFocused)
            
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
    }
}

#Preview {
    @FocusState var isFocused: Bool
    @State var searchText = ""
    
    return SearchBarView(searchText: $searchText, isFocused: $isFocused)
        .padding()
        .onAppear {
            // Simulate the parent view's behavior in the preview
            isFocused = true
        }
}
