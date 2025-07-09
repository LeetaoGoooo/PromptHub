//
//  HoverImageButton.swift
//  prompthub
//
//  Created by leetao on 2025/5/23.
//

import SwiftUI

struct HoverImageButton: View {
    let imageData: Data

    @State private var isHovering: Bool = false

    #if os(macOS)
    @Environment(\.openWindow) private var openWindow // 用于打开新窗口
    #endif

    var body: some View {
        Button {
            openWindow(value: imageData)
        }
        label: {
            Image(systemName: "photo")
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            #if os(macOS)
            withAnimation(.easeInOut(duration: 0.2)) {
                self.isHovering = hovering
            }
            #endif
        }
        .overlay(alignment: .topTrailing) {
            if isHovering {
                if let previewImage = imageFromData(imageData) {
                    previewImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .background(Color.secondary.opacity(0.5))
                        .cornerRadius(8)
                        .shadow(radius: 5)
                        .padding(5)
                        .offset(x: 50, y: 0)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

#Preview {
    HoverImageButton(imageData: Data())
        .padding()
}
