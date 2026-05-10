import AppKit
import PromptHubSkillKit
import SwiftUI

struct PrivateSkillSourcesView: View {
    @ObservedObject private var store = PrivateSkillSourceStore.shared
    @State private var showingAddSheet = false
    @State private var editingSource: PrivateSkillSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

    // MARK: - Onboarding Callout

    private var privateSourcesCallout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Color.purple)
                    .font(.callout)
                Text("What are Private Sources?")
                    .font(.subheadline.weight(.semibold))
            }

            VStack(alignment: .leading, spacing: 6) {
                PrivateSourceTip(
                    icon: "building.2",
                    text: "Connect a **private GitHub repo** (e.g. `owner/repo` → `SKILL.md` files inside) to install your team's internal skills."
                )
                PrivateSourceTip(
                    icon: "folder.badge.person.crop",
                    text: "Or point to a **local directory** on disk that contains `SKILL.md` files — great for monorepos."
                )
                PrivateSourceTip(
                    icon: "key",
                    text: "GitHub Private repos require a **Personal Access Token** with `repo` (read) scope. Tokens are stored in the macOS Keychain."
                )
                PrivateSourceTip(
                    icon: "square.and.arrow.down",
                    text: "Once added, install skills from private sources via **Skill Store → ↓ → Install from Private Source…**"
                )
            }
        }
        .padding(12)
        .background(Color.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.purple.opacity(0.15), lineWidth: 1))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.rectangle.stack").font(.system(size: 32)).foregroundStyle(.secondary)
            Text("No Private Sources").font(.headline)
            Text("Add a private GitHub repo or team-shared directory to install skills that aren't in the public registry.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
            Button("Add Private Source…") { showingAddSheet = true }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 24)
    }

    // MARK: - Sources List

    private var sourcesList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Private Skill Sources").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button { showingAddSheet = true } label: { Label("Add", systemImage: "plus") }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
            VStack(spacing: 0) {
                ForEach(store.sources) { source in
                    PrivateSkillSourceRow(source: source, hasToken: store.hasToken(for: source.id))
                        .contextMenu {
                            Button("Edit…") { editingSource = source }
                            Divider()
                            Button("Delete", role: .destructive) { store.remove(id: source.id) }
                        }
                        .onTapGesture(count: 2) { editingSource = source }
                    if source.id != store.sources.last?.id { Divider() }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
        }
    }
}

// MARK: - Tip Row

private struct PrivateSourceTip: View {
    let icon: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .center)
                .padding(.top, 2)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

