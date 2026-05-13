import SwiftUI

struct SkillProjectPickerPopover: View {
    let workspaceService: SkillWorkspaceService
    let onChooseProjects: () -> Void

    @State private var isPresented = false
    @State private var selectionRevision = 0

    private var savedProjects: [URL] {
        workspaceService.savedProjectRootURLs
    }

    private var activeProject: URL? {
        workspaceService.selectedProjectRootURL
    }

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label(workspaceService.selectedProjectMenuLabel, systemImage: "folder")
                .labelStyle(.titleAndIcon)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .fixedSize()
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            content
                .id(selectionRevision)
        }
        .onReceive(NotificationCenter.default.publisher(for: .skillProjectSelectionDidChange)) { _ in
            selectionRevision += 1
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Projects")
                    .font(.headline)
                Text("Project-scoped installs use the active project below. Save multiple roots, switch quickly, or forget old workspaces.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                statPill(title: activeProject == nil ? "No active project" : "Active", value: workspaceService.selectedProjectDisplayName)
                statPill(title: "Saved", value: "\(workspaceService.savedProjectCount)")
            }

            HStack(spacing: 8) {
                Button("Add Project…") {
                    onChooseProjects()
                }
                .buttonStyle(.borderedProminent)

                if activeProject != nil {
                    Button("Clear Active") {
                        workspaceService.setSelectedProjectRootURL(nil)
                    }
                    .buttonStyle(.bordered)
                }
            }

            if savedProjects.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(savedProjects, id: \.path) { projectURL in
                            projectRow(projectURL)
                        }
                    }
                }
                .frame(minWidth: 420, idealWidth: 460, maxWidth: 520, minHeight: 120, maxHeight: 280)
            }
        }
        .padding(18)
        .frame(minWidth: 420)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No saved projects yet")
                .font(.subheadline.weight(.medium))
            Text("Add one or more project folders to make project-scope skill installs switchable.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func projectRow(_ projectURL: URL) -> some View {
        let isActive = activeProject?.path == projectURL.path

        return HStack(alignment: .top, spacing: 10) {
            Button {
                workspaceService.setSelectedProjectRootURL(projectURL)
                isPresented = false
            } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isActive ? Color.accentColor : .secondary)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(workspaceService.projectDisplayName(for: projectURL))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)

                            if isActive {
                                Text("Active")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                            }
                        }

                        Text(projectURL.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isActive ? Color.accentColor.opacity(0.10) : Color(NSColor.controlBackgroundColor))
                )
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                workspaceService.removeProjectRootURL(projectURL)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Forget this saved project")
            .padding(.top, 10)
        }
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}