//
//  KeyboardShortcutSettingsView.swift
//  prompthub
//
//  Created by leetao on 2025/4/5.
//

import SwiftUI
import KeyboardShortcuts

struct KeyboardShortcutSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Keyboard Shortcuts
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keyboard Shortcuts")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Quick Search:")
                            Spacer()
                            KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name.toggleSearch)
                        }
                        
                        Text("Press the keyboard shortcut to quickly search for prompts from anywhere in the app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 128)
                    }
                }
                
                Spacer() // Push content to top
            }
            .padding(.top, 8) // Add some top padding to match header spacing
        }
        .scrollIndicators(.never)
    }
}

#Preview {
    KeyboardShortcutSettingsView()
        .padding()
}
