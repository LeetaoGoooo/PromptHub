//
//  NoHistoryView.swift
//  prompthub
//
//  Created by leetao on 2025/3/16.
//
import SwiftUI

struct NoHistoryView: View {
    private let cardBackground = Color(NSColor.controlBackgroundColor);

    var body: some View {
        Text("No history available for this prompt except the latest version.")
            .font(.callout)
            .foregroundColor(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(cardBackground)
            .cornerRadius(12)
    }
}

#Preview {
    NoHistoryView()
        .padding()
}
