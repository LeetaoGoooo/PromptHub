//
//  ImageViewerView.swift
//  prompthub
//
//  Created by leetao on 2025/5/23.
//


import SwiftUI

struct ImageViewerView: View {
    let imageData: Data

    var body: some View {
        if let displayImage = imageFromData(imageData) {
            displayImage
                .resizable()
                .scaledToFit()
                .padding()
        } else {
            Text("Error: Could not load image from data.")
                .padding()
        }
    }
}

#Preview {
    ImageViewerView(imageData: Data())
        .frame(width: 400, height: 300)
}
