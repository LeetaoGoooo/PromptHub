import AppKit
import PromptHubSkillKit
import SwiftUI

struct SkillStoreDetailPane: View {
    let skill: CatalogSkill
    let installationState: CatalogSkillInstallationState
    let isInstalling: Bool
    let justInstalled: Bool
    let onConfigureInstall: (SkillInstallScope) -> Void
    let onRemove: (SkillInstallScope) -> Void
    let onOpenSourcePage: () -> Void

    private let orderedScopes: [SkillInstallScope] = [.project, .global]

    private var canInstallMore: Bool {
        orderedScopes.contains { !missingAgents(for: $0).isEmpty }
    }

    private var preferredInstallScope: SkillInstallScope {
        missingAgents(for: .project).isEmpty ? .global : .project
    }

    private var headerMetrics: [(String, String)] {
        var metrics: [(String, String)] = []
        if installationState.isInstalled {
            metrics.append(("Installed", installationState.scopes.map(\.displayName).joined(separator: ", ")))
        } else {
            metrics.append(("Availability", "Not installed"))
        }
        if let source = skill.displaySource {
            metrics.append(("Source", source))
        }
        return metrics
    }

    var body: some View {
        SkillLibraryInspectorCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(skill.displayName)
                        .font(PH.Font.heroTitle)
                        .foregroundStyle(PH.Color.primary)
                    Text(skill.summary)
                        .font(.subheadline)
                        .foregroundStyle(PH.Color.secondary)
                        .lineSpacing(PH.Font.bodyLineSpacing)
                }
                .frame(maxWidth: 560, alignment: .leading)

                HStack(spacing: 10) {
                    ForEach(Array(headerMetrics.enumerated()), id: \.offset) { _, metric in
                        HStack(spacing: 6) {
                            Text(metric.0)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(PH.Color.tertiary)
                            Text(metric.1)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(PH.Color.secondary)
                                .lineLimit(1)
                        }
                    }
                }

                Divider().opacity(0.55)

                SkillLibraryMetadataBlock(
                    title: "Install",
                    rows: [
                        ("Project CLIs", cliDescription(for: .project)),
                        ("Global CLIs",  cliDescription(for: .global)),
                        ("Managed", skill.isManagedByPromptHub ? "PromptHub managed" : "External")
                    ]
                )

                SkillLibraryMetadataBlock(
                    title: "Package",
                    rows: [
                        ("Identifier", skill.package.rawValue)
                    ]
                )

                HStack(spacing: 10) {
                    installActions
                    if skill.url != nil {
                        Button("Open Source Page", action: onOpenSourcePage).buttonStyle(.bordered)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var installActions: some View {
        if isInstalling {
            Label("Installing…", systemImage: "hourglass").foregroundStyle(.secondary)
        } else {
            HStack(spacing: 10) {
                if canInstallMore {
                    Button {
                        onConfigureInstall(preferredInstallScope)
                    } label: {
                        Label(installationState.isInstalled ? "Configure Install…" : "Install…",
                              systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                }
                if !installationState.removableScopes.isEmpty {
                    Menu {
                        ForEach(installationState.removableScopes, id: \.rawValue) { scope in
                            Button(role: .destructive) { onRemove(scope) }
                            label: { Label("Remove \(scope.displayName)", systemImage: "trash") }
                        }
                    } label: { Label("Remove", systemImage: "trash") }
                    .menuStyle(.borderedButton)
                }
            }
        }
    }

    private func cliDescription(for scope: SkillInstallScope) -> String {
        let agents = installationState.agentsByScope[scope] ?? []
        return agents.isEmpty ? "Not installed" : agents.map(\.displayName).joined(separator: ", ")
    }

    private func missingAgents(for scope: SkillInstallScope) -> [AgentWorkflow] {
        let installed = Set(installationState.agentsByScope[scope] ?? [])
        return AgentWorkflow.defaultTargets.filter { !installed.contains($0) }
    }
}
