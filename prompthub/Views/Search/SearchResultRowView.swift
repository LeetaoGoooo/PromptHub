//
//  SearchResultRowView.swift
//  prompthub
//
//  Created by leetao on 2025/4/5.
//

import SwiftUI

struct SearchResultRowView: View {
    let item: any SearchableItem
    let type: SearchResultType
    let isSelected: Bool
    let onOpen: () -> Void
    let onCopy: () -> Void
    let index: Int
    let copiedIndex: Int?
    
    @State private var isHovering = false
    @State private var didCopy = false
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: onOpen) {
                Group {
                    if didCopy || (copiedIndex != nil && index == copiedIndex) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                            Text("Copied!")
                                .fontWeight(.semibold)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.caption)
                                .foregroundColor(getColor())
                            Text(item.name)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if item.navigationTarget != nil {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(height: 38)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: triggerCopy) {
                Image(systemName: didCopy || (copiedIndex != nil && index == copiedIndex) ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(didCopy || (copiedIndex != nil && index == copiedIndex) ? .green : .secondary)
                    .frame(width: 28, height: 28)
                    .background(Color.primary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Copy")
            .padding(.trailing, 8)
        }
        .background(
            Group {
                if didCopy || (copiedIndex != nil && index == copiedIndex) {
                    Color.green.opacity(0.2)     // 复制成功时显示绿色背景
                } else if isSelected {
                    getColor().opacity(0.1)       // 选中状态显示浅色背景
                } else if isHovering {
                    getColor().opacity(0.1)       // 悬停状态显示浅色背景
                } else {
                    Color.clear                  // 默认状态透明
                }
            }
        )
        .cornerRadius(6)
        .onHover { hovering in
            if !didCopy && (copiedIndex == nil || index != copiedIndex) {
                withAnimation(.easeOut(duration: 0.1)) {
                    isHovering = hovering
                }
            }
        }
    }

    private func triggerCopy() {
        guard !didCopy else { return }

        onCopy()

        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            didCopy = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                didCopy = false
                if isHovering {
                    isHovering = !isHovering
                }
            }
        }
    }
    
    private func getColor() -> Color {
        switch type.color {
        case "blue":
            return .blue
        case "orange":
            return .orange
        case "systemGray":
            return .gray
        case "mint":
            return .mint
        case "green":
            return .green
        case "purple":
            return .purple
        case "accent":
            return .accentColor
        default:
            return .primary
        }
    }
}
