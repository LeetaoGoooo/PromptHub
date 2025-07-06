//
//  PromptViewHelpers.swift
//  prompthub
//
//  Created by leetao on 2025/6/24.
//

import SwiftUI

/// Shared helper functions for prompt views
struct PromptViewHelpers {
    /// Calculates the number of columns based on the available width
    static func columns(for width: CGFloat) -> [GridItem] {
        let columnCount = max(1, Int(width / 300))
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: columnCount)
    }
    
    /// Standard styling for prompt item backgrounds
    static func promptItemBackground(borderColor: Color) -> some View {
        promptItemBackground(borderColor: borderColor, cornerRadius: 10)
    }
    
    /// Standard styling for prompt item backgrounds with custom corner radius
    static func promptItemBackground(borderColor: Color, cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(NSColor.windowBackgroundColor))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(0.12),
                radius: 5,
                x: 0,
                y: 2
            )
    }
    
    /// Standard empty state view
    static func emptyStateView(
        iconName: String,
        title: String,
        subtitle: String
    ) -> some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
