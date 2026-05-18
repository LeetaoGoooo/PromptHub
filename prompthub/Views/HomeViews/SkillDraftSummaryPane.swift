import SwiftUI

struct SkillDraftSummaryPane: View {
    let skill: Skill
    let exportedMarkdown: String
    let onOpenDraft: () -> Void
    let onCopyMarkdown: () -> Void
    let onCopyName: () -> Void
    let onDeleteDraft: () -> Void

    @State private var showingInstallSheet = false

    private let iconSymbols = ["wand.and.stars", "text.badge.star", "command.square", "slider.horizontal.below.square.and.square.filled", "sparkles.rectangle.stack"]
    private let iconColors: [Color] = [.pink, .blue, .orange, .mint, .indigo]

    private var iconSeed: Int { skill.displayName.unicodeScalars.reduce(0) { $0 + Int($1.value) } }
    private var iconSymbol: String { iconSymbols[iconSeed % iconSymbols.count] }
    private var iconColor: Color { iconColors[iconSeed % iconColors.count] }

    private var latestInstructionsPreview: String {
        let text = skill.latestVersion?.instructions.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "No instructions yet." : text
    }

    private var formattedTags: String { skill.tags.isEmpty ? "No tags yet" : skill.tags.joined(separator: ", ") }

    private var lastInstalledText: String {
        skill.lastInstalledAt.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never"
    }

    var body: some View {
        SkillLibraryInspectorCard {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(alignment: .top, spacing: 18) {
                    Image(systemName: iconSymbol)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 56, height: 56)
                        .background(iconColor.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(skill.displayName).font(.title2.weight(.semibold))
                        Text(skill.desc?.isEmpty == false ? skill.desc! : "No description yet.")
                            .font(.body).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            DraftBadge(title: skill.category, icon: "tag", foreground: .accentColor, background: Color.accentColor.opacity(0.14))
                            if skill.lastInstalledAt != nil {
                                DraftBadge(title: "Installed", icon: "arrow.down.circle.fill", foreground: .green, background: Color.green.opacity(0.14))
                            }
                        }
                    }
                    Spacer()
                }

                SkillLibraryMetadataBlock(title: "Identity", rows: [
                    ("Slug", skill.slug.isEmpty ? "Not set" : skill.slug),
                    ("Identifier", skill.identifier.isEmpty ? "Not set" : skill.identifier),
                    ("Tags", formattedTags)
                ])

                SkillLibraryMetadataBlock(title: "Lifecycle", rows: [
                    ("Version", skill.latestVersion?.version ?? "1.0.0"),
                    ("Updated", skill.updatedAt.formatted(date: .abbreviated, time: .shortened)),
                    ("Installed", lastInstalledText)
                ])

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick Actions")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 10, alignment: .leading)], alignment: .leading, spacing: 10) {
                        Button(action: { showingInstallSheet = true }) {
                            Label("Install…", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: onOpenDraft) {
                            Label("Open Draft", systemImage: "arrow.right.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: onCopyMarkdown) {
                            Label("Copy SKILL.md", systemImage: "doc.on.doc")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(action: onCopyName) {
                            Label("Copy Name", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive, action: onDeleteDraft) {
                            Label("Delete Draft", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest Instructions").font(.headline)
                    ScrollView {
                        Text(latestInstructionsPreview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(14)
                    }
                    .frame(minHeight: 110, idealHeight: 140, maxHeight: 180)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.82), in: RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("SKILL.md Preview").font(.headline)
                    ScrollView([.horizontal, .vertical]) {
                        Text(exportedMarkdown)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: 260, idealHeight: 340, maxHeight: 420)
                    .padding(12)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .sheet(isPresented: $showingInstallSheet) {
                    SkillDraftInstallSheet(skill: skill)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
