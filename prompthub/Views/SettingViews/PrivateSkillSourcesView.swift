import AppKit
import PromptHubSkillKit
import SwiftUI

struct PrivateSkillSourcesView: View {
    @ObservedObject private var store = PrivateSkillSourceStore.shared
    @State private var showingAddSheet = false
    @State private var editingSource: PrivateSkillSource?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.rectangle.stack").font(.system(size: 32)).foregroundStyle(.secondary)
            Text("No Private Sources").font(.headline)
            Text("Add a private GitHub repo or team-shared directory to install skills that aren't in the public registry.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360)
            Button("Add Private Source…") { showingAddSheet = true }.buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
    }

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
