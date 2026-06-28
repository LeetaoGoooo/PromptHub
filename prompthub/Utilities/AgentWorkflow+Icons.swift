import PromptHubSkillKit
import SwiftUI

extension AgentWorkflow {
    var assetIconName: String? {
        switch self {
        case .codex:
            return "tool-codex"
        case .claudeCode:
            return "tool-claude"
        case .cursor:
            return "tool-cursor"
        case .geminiCLI:
            return nil
        case .iflow:
            return nil
        case .opencode:
            return "tool-opencode"
        case .qwenCode:
            return nil
        case .qoder:
            return nil
        }
    }

    var fallbackSystemIconName: String {
        switch self {
        case .codex:
            return "terminal"
        case .claudeCode:
            return "bolt.horizontal.circle"
        case .cursor:
            return "cursorarrow"
        case .geminiCLI:
            return "sparkles"
        case .iflow:
            return "paperplane"
        case .opencode:
            return "curlybraces"
        case .qwenCode:
            return "network"
        case .qoder:
            return "chevron.left.forwardslash.chevron.right"
        }
    }

    var iconImage: Image {
        if let name = assetIconName {
            return Image(name).renderingMode(.template)
        }
        return Image(systemName: fallbackSystemIconName)
    }

    var iconColor: Color {
        switch self {
        case .codex:
            return .purple
        case .claudeCode:
            return .orange
        case .cursor:
            return .mint
        case .geminiCLI:
            return .indigo
        case .iflow:
            return .blue
        case .opencode:
            return .pink
        case .qwenCode:
            return .teal
        case .qoder:
            return .green
        }
    }
}

struct AgentIconBadge: View {
    let agent: AgentWorkflow

    var body: some View {
        HStack(spacing: 6) {
            agent.iconImage
                .resizable()
                .scaledToFit()
                .frame(width: 14, height: 14)
                .foregroundStyle(agent.iconColor)

            Text(agent.displayName)
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(agent.iconColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
