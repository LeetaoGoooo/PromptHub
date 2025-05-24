//
//  ImageProvider.swift
//  prompthub
//
//  Created by leetao on 2025/5/23.
//


//
//  ImageProvider.swift
//  prompthub
//
//  Created by leetao on 2025/5/23.
//


import SwiftUI

#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#elseif os(iOS) || os(tvOS) || os(watchOS)
import UIKit
typealias PlatformImage = UIImage
#endif

public func imageFromData(_ data: Data) -> Image? {
    if let platformImage = PlatformImage(data: data) {
        #if os(macOS)
        return Image(nsImage: platformImage)
        #else
        return Image(uiImage: platformImage)
        #endif
    }
    return nil
}
