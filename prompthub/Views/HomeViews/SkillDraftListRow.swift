import PromptHubSkillKit
import SwiftUI

struct SkillDraftListRow: View {
    let skill: Skill
    let installations: [InstalledSkillSnapshot]
    let isSelected: Bool
    var onSelect: () -> Void = {}

    private var agentLine: String {
        let agents = installations.flatMap(\.agents)
        guard !agents.isEmpty else { return "Draft · Not installed" }
        let names = AgentWorkflow.defaultTargets
            .filter { agents.contains($0) }
            .map(\.displayName)
            .joined(separator: ", ")
        return "Draft · \(names)"
    }

    private var versionText: String? {
        skill.latestVersion?.version
    }

    var body: some View {
        SkillLibraryCompactRow(
            title: skill.displayName,
            metaText: agentLine,
            dotColor: installations.isEmpty ? PH.Color.accent : PH.Color.statusOK,
            isSelected: isSelected,
            onSelect: onSelect
        ) {
            if let versionText {
                Text(versionText)
                    .font(PH.Font.mono)
                    .foregroundStyle(PH.Color.tertiary)
            }
        }
    }
}
