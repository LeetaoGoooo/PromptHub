import AlertToast
import SwiftUI

// MARK: - Sub Views

extension PromptDetail {

    @ViewBuilder
    var promptHeader: some View {
        SkillLibraryInspectorCard {
            VStack(alignment: .leading, spacing: PH.Spacing.promptHeaderGap) {
                HStack(alignment: .firstTextBaseline) {
                    Group {
                        if isEditing {
                            TextField("Prompt Name", text: $prompt.name)
                                .textFieldStyle(.plain)
                                .focused($focusedField, equals: .name)
                                .padding(.horizontal, -4)
                        } else {
                            Text(prompt.name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .font(PH.Font.heroTitle)
                    Spacer()
                    if let latestHistory = history.first {
                        Text("v\(max(latestHistory.version, 1))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Group {
                    if isEditing {
                        TextField("Add a description...", text: Binding(
                            get: { prompt.desc ?? "" },
                            set: { prompt.desc = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, -4)
                    } else if let desc = prompt.desc, !desc.isEmpty {
                        Text(desc)
                    } else {
                        Text("No description")
                            .foregroundStyle(.tertiary)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, PH.Spacing.promptInset)
        .padding(.top, PH.Spacing.promptInset)
    }

    @ToolbarContentBuilder
    var promptDetailToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button {
                    isShowingDiff.toggle()
                } label: {
                    Label("Diff", systemImage: "clock.arrow.circlepath")
                }

                Button {
                    promotePromptToSkill()
                } label: {
                    Label("Promote to Skill", systemImage: "wand.and.stars.inverse")
                }

                Button {
                    _ = copyPromptToClipboard(prompt.getLatestPromptContent())
                } label: {
                    Label("Copy Content", systemImage: "doc.on.doc")
                }

                Divider()

                Button(role: .destructive) {
                    showingDeletePromptConfirmation = true
                } label: {
                    Label(isEphemeralDraft ? "Discard" : "Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }

            Button {
                isEditing.toggle()
            } label: {
                Image(systemName: isEditing ? "checkmark.circle.fill" : "pencil")
            }
            .help(isEditing ? "Done editing" : "Edit prompt")

            Button {
                isShowingSingleTestView.toggle()
            } label: {
                Image(systemName: "play.fill")
            }
            .help("Test prompt")

            Button {
                optimizeRequestID += 1
            } label: {
                Image(systemName: "wand.and.stars")
            }
            .help("Optimize with AI")

            Button {
                isShowingHistoryDrawer.toggle()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .help(isShowingHistoryDrawer ? "Hide history" : "Show history")

            Button {
                Task { await shareCreation() }
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(isCreateShareLink)
            .help("Share prompt")
        }
    }

    @ViewBuilder
    func promptInfoCard(latestHistory: PromptHistory) -> some View {
        SkillLibraryInspectorCard(title: "Information") {
            VStack(alignment: .leading, spacing: PH.Spacing.promptDrawerCardGap) {
                LabeledContent("Version", value: "v\(max(latestHistory.version, 1))")
                LabeledContent("Created", value: latestHistory.createdAt, format: .dateTime)
                LabeledContent("Updated", value: latestHistory.updatedAt, format: .dateTime)
                LabeledContent("Link", value: prompt.link?.isEmpty == false ? "Attached" : "None")
                LabeledContent("External Sources", value: (prompt.externalSources?.isEmpty ?? true) ? "None" : "Attached")
            }
        }
    }

    @ViewBuilder
    var promptSharingCard: some View {
        SkillLibraryInspectorCard(title: "Sharing") {
            if let shared = existingSharedCreation {
                VStack(alignment: .leading, spacing: PH.Spacing.promptDrawerItemGap) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(shared.isPublic ? "Visible to community" : "Private link only")
                                .font(.headline)
                            Text("Reuse the current share record or switch its visibility.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { shared.isPublic },
                            set: { _ in Task { await togglePublicStatus() } }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .disabled(isTogglingPublic)
                    }

                    HStack(spacing: PH.Spacing.rowItemGap) {
                        Button {
                            Task { await shareCreation() }
                        } label: {
                            Label("Copy Share Link", systemImage: "link")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isCreateShareLink)

                        if isTogglingPublic {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: PH.Spacing.promptDrawerCardGap) {
                    Text("Not shared yet")
                        .font(.headline)
                    Text("Create a share link for this prompt without leaving the editor.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button {
                        Task { await shareCreation() }
                    } label: {
                        Label("Share to Community", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isCreateShareLink)
                }
            }
        }
    }

    @ViewBuilder
    func promptHistoryDrawer(latestHistory: PromptHistory) -> some View {
        VStack(alignment: .leading, spacing: PH.Spacing.promptDrawerGap) {
            HStack(alignment: .top, spacing: PH.Spacing.promptDrawerItemGap) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(PH.Font.drawerTitle)
                    Text("Restore an earlier version without leaving the editor.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    isShowingHistoryDrawer = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Close history")
            }

            if latestHistory.promptText.isEmpty == false {
                promptInfoCard(latestHistory: latestHistory)
            }

            promptSharingCard

            SkillLibraryInspectorCard(title: "Versions") {
                if history.isEmpty {
                    Text("No history yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(spacing: PH.Spacing.promptDrawerCardGap) {
                            ForEach(history) { item in
                                historyDrawerRow(item, latestHistory: latestHistory)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .frame(width: PH.Layout.promptHistoryDrawerWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .padding(PH.Spacing.promptDrawerGap)
        .background(PH.Color.detailBg)
        .overlay(alignment: .leading) {
            Divider()
        }
        .shadow(color: .black.opacity(0.12), radius: 18, x: -4, y: 0)
    }

    @ViewBuilder
    private func historyDrawerRow(_ item: PromptHistory, latestHistory: PromptHistory) -> some View {
        let isCurrentVersion = item.id == latestHistory.id

        VStack(alignment: .leading, spacing: PH.Spacing.promptDrawerCardGap) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("v\(item.version)")
                    .font(.headline)

                if isCurrentVersion {
                    Text("Current")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(item.updatedAt, formatter: dateFormatter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(historySummary(for: item.promptText))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                Spacer()

                Button {
                    applyHistoryVersionToEditor(item)
                } label: {
                    Label(isCurrentVersion ? "Current" : "Restore", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isCurrentVersion)
            }
        }
        .padding(PH.Spacing.promptDrawerItemGap)
        .background(PH.Color.buttonBg)
        .clipShape(RoundedRectangle(cornerRadius: PH.Spacing.promptPanelCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: PH.Spacing.promptPanelCorner, style: .continuous)
                .stroke(PH.Color.buttonBorder, lineWidth: 1)
        )
    }

    private func historySummary(for text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "No content" : normalized
    }
}
