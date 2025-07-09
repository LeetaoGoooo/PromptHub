//
//  UniformInputStyle.swift
//  prompthub
//
//  Created by leetao on 2025/7/9.
//


import SwiftUI

struct UniformInputStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .cornerRadius(8)
    }
}

extension View {
    func uniformInputStyle() -> some View {
        self.modifier(UniformInputStyle())
    }
}

