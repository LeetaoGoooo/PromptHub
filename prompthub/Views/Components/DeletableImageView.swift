//
//  DeletableImageView.swift
//  prompthub
//
//  Created by leetao on 2025/5/23.
//


import SwiftUI

struct DeletableImageView: View {
    @Binding var image: NSImage?
    
    var maxWidth: CGFloat = 400
    var maxHeight: CGFloat = 400

    var body: some View {
        if let nsImage = image {
            ZStack(alignment: .topTrailing) { // ZStack 用于叠加视图，对齐方式为右上角
                // 原始的图片显示逻辑
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    // .frame(maxWidth: maxWidth, maxHeight: maxHeight) // 将 frame 应用到 ZStack 上，或者按需调整
                    // .padding() // 原始的 padding 也可能需要调整或应用到 ZStack

                // 关闭按钮
                Button {
                    // 点击按钮时，将绑定的 image 设置为 nil
                    withAnimation { // 可选：添加动画效果
                        self.image = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill") // 使用 SF Symbols 图标
                        .font(.title2) // 调整图标大小
                        .foregroundColor(.gray) // 图标颜色
                        // 为了在各种背景图片上都清晰可见，可以给图标加一个半透明背景
                        .background(Circle().fill(.white.opacity(0.7)))
                        .shadow(radius: 2) // 轻微阴影增加立体感
                }
                .buttonStyle(.plain) // 在 macOS 上移除默认的按钮边框和背景
                .padding(8) // 给按钮一些内边距，使其不完全贴边
                // .offset(x: -5, y: 5) // 如果需要更精细的位置调整，可以使用 offset
            }
            .frame(maxWidth: maxWidth, maxHeight: maxHeight) // 将 frame 应用到 ZStack
            .padding() // 原始的 padding，现在应用到 ZStack 的外部
            
        } else {

            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .scaledToFit()
                .frame(width: 124, height: 124)
                .foregroundColor(.gray)
                .padding()
        }
    }
}

// MARK: - 预览和使用示例

struct ContentView_DeletableImagePreview: View {
    // @State 变量用于存储图片，并通过 @Binding 传递给 DeletableImageView
    @State private var sampleImage: NSImage? = NSImage(systemSymbolName: "photo.artframe", accessibilityDescription: nil) // 初始图片
    @State private var anotherImage: NSImage? = NSImage(named: "NSFlower") // 尝试加载一个AppKit命名图片
    @State private var imageFromURL: NSImage? = nil


    var body: some View {
        VStack(spacing: 20) {
            Text("Deletable Image Demo")
                .font(.headline)

            DeletableImageView(image: $sampleImage, maxWidth: 200, maxHeight: 200)
            
            DeletableImageView(image: $anotherImage) // 使用默认的 400x400

            DeletableImageView(image: $imageFromURL, maxWidth: 300, maxHeight: 200)


            if sampleImage == nil && anotherImage == nil && imageFromURL == nil {
                Button("Reset Images") {
                    sampleImage = NSImage(systemSymbolName: "photo.artframe", accessibilityDescription: nil)
                    anotherImage = NSImage(named: "NSFlower")
                    loadImageFromURL()
                }
                .padding(.top)
            }
        }
        .padding()
        .onAppear {
            if anotherImage == nil { // 如果 NSFlower 加载失败，给个默认图
                anotherImage = NSImage(systemSymbolName: "camera.macro", accessibilityDescription: "Flower placeholder")
            }
            loadImageFromURL()
        }
    }
    
    func loadImageFromURL() {
        // 替换为一个实际的图片URL
        guard let url = URL(string: "https://source.unsplash.com/random/400x400") else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let downloadedImage = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.imageFromURL = downloadedImage
                }
            } else {
                print("Failed to load image from URL: \(error?.localizedDescription ?? "Unknown error")")
                // Fallback image if URL load fails
                DispatchQueue.main.async {
                    self.imageFromURL = NSImage(systemSymbolName: "wifi.exclamationmark", accessibilityDescription: "Network error")
                }
            }
        }.resume()
    }
}

struct DeletableImageView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView_DeletableImagePreview()
            .frame(width: 500, height: 800) // 给预览一个合适的尺寸
    }
}
