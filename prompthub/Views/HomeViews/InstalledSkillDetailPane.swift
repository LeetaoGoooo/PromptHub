import AppKit
import PromptHubSkillKit
import SwiftUI

struct InstalledSkillDetailPane: View {
    let skill: InstalledSkillSnapshot
    let linkedDraft: Skill?
    let agentVisibility: [SkillAgentVisibility]
    let isLoadingVisibility: Bool
    let sourceIntegrity: SkillSourceIntegrity?
    let isLoadingIntegrity: Bool
    let effectiveness: SkillEffectivenessReport?
    let isLoadingEffectiveness: Bool
    let isAdding: Bool
    let isRemoving: Bool
    let onEditDraft: () -> Void
    let onAddAgents: ([AgentWorkflow]) -> Void
    let onRemoveAll: () -> Void
    let onRemoveAgent: (AgentWorkflow) -> Void
    let onOpenSourcePage: () -> Void

    @State private var showingUpdateDiff = false

    private let iconSymbols = [
        "shippingbox.fill", "terminal.fill", "server.rack",
        "folder.badge.gearshape", "square.stack.3d.up.fill", "globe.americas.fill"
    ]

    private let iconColors: [Color] = [.blue, .green, .orange, .teal, .indigo, .mint]

    private var addableAgents: [AgentWorkflow] {
        AgentWorkflow.defaultTargets.filter { !skill.agents.contains($0) }
    }

    private var supportsAddTargets: Bool { !addableAgents.isEmpty }

    var body: some View {
        SkillLibraryInspectorCard {
            VStack(alignment: .leading, spacing: 20) {
                // Header row
                HStack(alignment: .top, spacing: 18) {
                    Image(systemName: iconSymbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 56, height: 56)
                        .background(iconColor.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(skill.displayName).font(.title2.weight(.semibold))
                        if let source = skill.displaySource {
                            Text(source).font(.subheadline).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 6) {
                            InstalledSkillBadge(
                                title: skill.isGlobal ? "Global" : "Project",
                                icon: skill.isGlobal ? "globe" : "folder",
                                foreground: skill.isGlobal ? .blue : .mint,
                                background: (skill.isGlobal ? Color.blue : Color.mint).opacity(0.14)
                            )
                            InstalledSkillBadge(
                                title: skill.isManagedByPromptHub ? "PromptHub Managed" : "External",
                                icon: skill.isManagedByPromptHub ? "checkmark.circle" : "arrow.triangle.branch",
                                foreground: skill.isManagedByPromptHub ? .green : .orange,
                                background: (skill.isManagedByPromptHub ? Color.green : Color.orange).opacity(0.14)
                            )
                        }
                    }
                    Spacer()
                }

                Text(skill.summary.isEmpty ? "No summary was recorded for this installed skill." : skill.summary)
                    .font(.body).foregroundStyle(.secondary)

                InstalledSkillScopeMatrixView(skill: skill)

                InstalledSkillAgentVisibilityView(visibility: agentVisibility, isLoading: isLoadingVisibility)

                InstalledSkillIntegrityView(integrity: sourceIntegrity, isLoading: isLoadingIntegrity)

                InstalledSkillEffectivenessView(effectiveness: effectiveness, isLoading: isLoadingEffectiveness)

                SkillLibraryMetadataBlock(
                    title: "Package",
                    rows: [
                        ("Identifier", skill.package.rawValue),
                        ("Managed", skill.isManagedByPromptHub ? "PromptHub managed" : "External install")
                    ]
                )

                actionBar

                Spacer(minLength: 0)
            }
        }
        .sheet(isPresented: $showingUpdateDiff) {
            SkillUpdateDiffSheet(skill: skill) { showingUpdateDiff = false }
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        HStack(spacing: 10) {
            Button(linkedDraft == nil ? "Duplicate to Draft" : "Open Draft", action: onEditDraft)
                .buttonStyle(.borderedProminent)

            if isAdding {
                Label("Updating CLIs…", systemImage: "hourglass").foregroundStyle(.secondary)
            } else if supportsAddTargets {
                Menu {
                    if addableAgents.count > 1 {
                        Button { onAddAgents(addableAgents) }
                        label: { Label("Add All Missing CLIs", systemImage: "plus.circle") }
                    }
                    ForEach(addableAgents, id: \.rawValue) { agent in
                        Button { onAddAgents([agent]) }
                        label: { Label("Add \(agent.displayName)", systemImage: "plus") }
                    }
                } label: { Label("Add CLI", systemImage: "plus") }
                .menuStyle(.borderedButton)
            }

            if isRemoving {
                Label("Removing…", systemImage: "hourglass").foregroundStyle(.secondary)
            } else {
                Menu {
                    Button(role: .destructive) { onRemoveAll() }
                    label: { Label("Remove from All CLIs", systemImage: "trash") }

                    if !skill.agents.isEmpty {
                        Section("Remove from CLI") {
                            ForEach(skill.agents, id: \.rawValue) { agent in
                                Button(role: .destructive) { onRemoveAgent(agent) }
                                label: { Label(agent.displayName, systemImage: "trash") }
                            }
                        }
                    }
                } label: { Label("Manage CLIs", systemImage: "slider.horizontal.3") }
                .menuStyle(.borderedButton)
            }

            if skill.url != nil {
                Button("Open Source Page", action: onOpenSourcePage).buttonStyle(.bordered)
            }

            if skill.package.remoteInstallDescriptor != nil {
                Button { showingUpdateDiff = true }
                label: { Label("Check for Update…", systemImage: "arrow.down.circle") }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Icon generation

    private var iconSeed: Int {
        skill.displayName.unicodeScalars.reduce(0) { $0 + Int($1.value) }
    }

    private var iconSymbol: String { iconSymbols[iconSeed % iconSymbols.count] }
    private var iconColor: Color   { iconColors[iconSeed % iconColors.count] }
}
