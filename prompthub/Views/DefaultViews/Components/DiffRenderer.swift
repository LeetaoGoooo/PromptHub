//
//  DiffLine.swift
//  prompthub
//
//  Created by leetao on 2025/8/7.
//


import SwiftUI



struct DiffRenderer: View {
    let diffResults: [DiffResult]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(diffResults) { line in
                    DiffLineView(line: line)
                }
            }
            .font(.system(.body, design: .monospaced))
            .padding(8)
        }
        .background(Color(.textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

private struct DiffLineView: View {
    let line: DiffResult
    
    var body: some View {
        HStack(spacing: 8) {
            Text(line.prefix)
                .font(.system(.body, design: .monospaced).bold())
                .foregroundColor(lineColor)
                .frame(width: 16, alignment: .center)


            Text(line.text)
                .textSelection(.enabled) // 允许用户选择和复制文本
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .background(backgroundColor)
    }
    
    // MARK: - Computed Properties for Styling
    
    private var backgroundColor: Color {
        switch line {
        case .added:
            return Color.green.opacity(0.15)
        case .removed:
            return Color.red.opacity(0.15)
        case .common:
            return Color.clear
        }
    }
    
    private var lineColor: Color {
        switch line {
        case .added:
            return .green
        case .removed:
            return .red
        case .common:
            return .primary.opacity(0.8) // 普通文本用稍暗的颜色
        }
    }
    
    private var prefixSymbol: String {
        switch line {
        case .added:
            return "+"
        case .removed:
            return "-"
        case .common:
            return " "
        }
    }
}


