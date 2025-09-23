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
        Section("Keyboard Shortcuts") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Quick Search:")
                        .frame(width: 120, alignment: .trailing)
                    KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name.toggleSearch)
                }
                
                Text("Press the keyboard shortcut to quickly search for prompts from anywhere in the app.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 128)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    KeyboardShortcutSettingsView()
}
