import AppKit
import PromptHubSkillKit
import SwiftUI

struct PrivateSkillSourcesView: View {
    @ObservedObject private var store = PrivateSkillSourceStore.shared
    @State private var showingAddSheet = false
    @State private var editingSource: PrivateSkillSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            privateSourcesCallout
            if store.sources.isEmpty { emptyState } else { sourcesList }
        }
        .sheet(isPresented: $showingAddSheet) {
            PrivateSkillSourceEditSheet(source: nil) { newSource, token in
                store.add(newSource)
                if let token { store.saveToken(token, for: newSource.id) }
            }
        }
        .sheet(item: $editingSource) { source in
            PrivateSkillSourceEditSheet(source: source) { updated, token in
                store.update(updated)
                if let token { store.saveToken(token, for: updated.id) }
            }
        }
    }

    private var privateSourcesCallout: some View {
        SettingsInfoBanner(icon: "lock.shield.fill", tint: PH.Color.accent) {
            Text("Private sources let PromptHub load internal skills from a private GitHub repository or a shared folder.")
                .font(PH.Font.rowName)
                .foregroundStyle(PH.Color.primary)

            VStack(alignment: .leading, spacing: 6) {
                PrivateSourceTip(icon: "building.2", text: "Use `owner/repo` for GitHub sources.")
                PrivateSourceTip(icon: "folder.badge.person.crop", text: "Use an absolute filesystem path for shared folders.")
                PrivateSourceTip(icon: "key", text: "GitHub tokens stay in the macOS Keychain.")
                PrivateSourceTip(icon: "square.and.arrow.down", text: "Install from these sources through Skill Store.")
            }
        }
    }

    private var emptyState: some View {
        SettingsCard(title: "Sources", icon: "lock.rectangle.stack") {
            VStack(spacing: 12) {
                Image(systemName: "lock.rectangle.stack")
                    .font(.system(size: 30))
                    .foregroundStyle(PH.Color.tertiary)
                Text("No Private Sources")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(PH.Color.primary)
                Text("Add a private GitHub repo or shared directory to install skills that are not in the public catalog.")
                    .font(PH.Font.body)
                    .foregroundStyle(PH.Color.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 420)
                Button("Add Private Source") { showingAddSheet = true }
                    .buttonStyle(PHChromeButtonStyle(emphasis: .accent))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private var sourcesList: some View {
        SettingsCard(title: "Private Skill Sources", icon: "externaldrive.connected.to.line.below") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(store.sources.count) connected")
                        .font(PH.Font.rowSub)
                        .foregroundStyle(PH.Color.secondary)

                    Spacer()

                    Button("Add Source") { showingAddSheet = true }
                        .buttonStyle(PHChromeButtonStyle(emphasis: .accent))
                }

                VStack(spacing: 10) {
                    ForEach(store.sources) { source in
                        PrivateSkillSourceRow(source: source, hasToken: store.hasToken(for: source.id))
                            .contextMenu {
                                Button("Edit…") { editingSource = source }
                                Divider()
                                Button("Delete", role: .destructive) { store.remove(id: source.id) }
                            }
                            .onTapGesture(count: 2) { editingSource = source }
                    }
                }
            }
        }
    }
}

private struct PrivateSourceTip: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(PH.Color.secondary)
                .frame(width: 14, alignment: .center)
                .padding(.top, 2)
            Text(text)
                .font(PH.Font.rowSub)
                .foregroundStyle(PH.Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
