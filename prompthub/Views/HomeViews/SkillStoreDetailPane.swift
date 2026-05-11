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

    private let iconSymbols = [
        "hammer.fill", "paintpalette.fill", "terminal.fill",
        "wand.and.stars", "cpu.fill", "shippingbox.fill", "doc.text.magnifyingglass"
    ]
    private let iconColors: [Color] = [.blue, .orange, .green, .pink, .mint, .indigo, .teal]
    private let orderedScopes: [SkillInstallScope] = [.project, .global]

    private var canInstallMore: Bool {
        orderedScopes.contains { !missingAgents(for: $0).isEmpty }
    }

    private var preferredInstallScope: SkillInstallScope {
        missingAgents(for: .project).isEmpty ? .global : .project
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
                    SkillInstallationBadges(
                        installationState: installationState,
                        isInstalling: isInstalling,
                        justInstalled: justInstalled
                    )
                }
                Spacer()
            }

            Text(skill.summary).font(.body).foregroundStyle(.secondary)

            SkillLibraryMetadataBlock(
                title: "Availability",
                rows: [
                    ("Scopes", installationState.scopes.isEmpty ? "Not installed yet" : installationState.scopes.map(\.displayName).joined(separator: ", ")),
                    ("Project CLIs", cliDescription(for: .project)),
                    ("Global CLIs",  cliDescription(for: .global))
                ]
            )

            SkillLibraryMetadataBlock(
                title: "Package",
                rows: [
                    ("Identifier", skill.package.rawValue),
                    ("Managed", skill.isManagedByPromptHub ? "PromptHub managed" : "External")
                ]
            )

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Quick Actions")
                    .font(.headline)

                HStack(spacing: 10) {
                    installActions
                    if skill.url != nil {
                        Button("Open Source Page", action: onOpenSourcePage).buttonStyle(.bordered)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Summary")
                    .font(.headline)

                ScrollView {
                    Text(skill.summary)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
                .frame(minHeight: 96, idealHeight: 120, maxHeight: 140)
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SkillStoreInspectorChrome())
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

    private var iconSeed: Int { skill.displayName.unicodeScalars.reduce(0) { $0 + Int($1.value) } }
    private var iconSymbol: String { iconSymbols[iconSeed % iconSymbols.count] }
    private var iconColor: Color   { iconColors[iconSeed % iconColors.count] }

    private func cliDescription(for scope: SkillInstallScope) -> String {
        let agents = installationState.agentsByScope[scope] ?? []
        return agents.isEmpty ? "Not installed" : agents.map(\.displayName).joined(separator: ", ")
    }

    private func missingAgents(for scope: SkillInstallScope) -> [AgentWorkflow] {
        let installed = Set(installationState.agentsByScope[scope] ?? [])
        return AgentWorkflow.defaultTargets.filter { !installed.contains($0) }
    }
}
