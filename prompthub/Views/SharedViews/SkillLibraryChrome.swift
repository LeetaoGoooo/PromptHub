import SwiftUI

// MARK: - Metric Model

struct SkillLibraryMetric: Identifiable {
    let value: String
    let title: String
    let systemImage: String
    var id: String { title }
}

enum SkillsWorkspaceTab: String, CaseIterable, Identifiable {
    case installed
    case drafts
    case discover

    var id: String { rawValue }

    var title: String {
        switch self {
        case .installed: return "Installed"
        case .drafts: return "Drafts"
        case .discover: return "Discover"
        }
    }
}

struct SkillsWorkspacePicker: View {
    @Binding var navigationState: WorkspaceNavigationState

    private var selectedTab: Binding<SkillsWorkspaceTab> {
        Binding(
            get: {
                switch navigationState.skillLens {
                case .installed:
                    return .installed
                case .drafts:
                    return .drafts
                case .store:
                    return .discover
                }
            },
            set: { newValue in
                switch newValue {
                case .installed:
                    navigationState.showSkills(.installed)
                case .drafts:
                    navigationState.showSkills(.drafts)
                case .discover:
                    navigationState.showSkills(.store)
                }
            }
        )
    }

    var body: some View {
        Picker("Skills Workspace", selection: selectedTab) {
            ForEach(SkillsWorkspaceTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 270)
        .labelsHidden()
    }
}

// MARK: - Prompts Workspace Picker

enum PromptsWorkspaceTab: String, CaseIterable, Identifiable {
    case all
    case mine
    case shared
    case explore

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:     return "All"
        case .mine:    return "Mine"
        case .shared:  return "Shared"
        case .explore: return "Explore"
        }
    }
}

struct PromptsWorkspacePicker: View {
    @Binding var navigationState: WorkspaceNavigationState

    private var selectedTab: Binding<PromptsWorkspaceTab> {
        Binding(
            get: {
                switch navigationState.promptLens {
                case .all:     return .all
                case .mine:    return .mine
                case .shared:  return .shared
                case .explore: return .explore
                }
            },
            set: { newValue in
                switch newValue {
                case .all:     navigationState.showPrompts(.all)
                case .mine:    navigationState.showPrompts(.mine)
                case .shared:  navigationState.showPrompts(.shared)
                case .explore: navigationState.showPrompts(.explore)
                }
            }
        )
    }

    var body: some View {
        Picker("Prompts Workspace", selection: selectedTab) {
            ForEach(PromptsWorkspaceTab.allCases) { tab in
                Text(tab.title).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 240)
        .labelsHidden()
    }
}

struct AgentsWorkspacePicker: View {
    @Binding var navigationState: WorkspaceNavigationState

    var body: some View {
        Picker("Agents Workspace", selection: Binding(
            get: { navigationState.agentLens },
            set: { newValue in
                navigationState.showAgents(newValue)
            }
        )) {
            Text("Workspaces").tag(AgentWorkspaceLens.workspaces)
        }
        .pickerStyle(.segmented)
        .frame(width: 180)
        .labelsHidden()
    }
}

struct SkillLibraryHeaderCard<Accessory: View>: View {
    let title: String
    let subtitle: String
    let metrics: [SkillLibraryMetric] 
    @ViewBuilder let accessory: () -> Accessory

    init(title: String, subtitle: String, metrics: [SkillLibraryMetric],
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.metrics = metrics
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(PH.Color.primary)

            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(PH.Font.rowSub)
                    .foregroundStyle(PH.Color.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Spacer(minLength: 0)
                HStack(spacing: 6) { accessory() }
                    .fixedSize(horizontal: true, vertical: false)
            }

            if !metrics.isEmpty {
                HStack(spacing: 12) {
                    ForEach(metrics) { metric in
                        HStack(spacing: 4) {
                            Image(systemName: metric.systemImage)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(PH.Color.tertiary)
                            Text(metric.value)
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(PH.Color.secondary)
                            Text(metric.title)
                                .font(.system(size: 11))
                                .foregroundStyle(PH.Color.tertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PH.Color.detailBg)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(PH.Color.strokeSoft)
                .frame(height: 1)
        }
    }
}

// MARK: - Screen Layout

struct SkillLibraryScreen<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(PH.Color.windowBg.ignoresSafeArea())
    }
}

// MARK: - Legacy SkillLibraryScreenWithHeader (for backward compatibility)
struct SkillLibraryScreenWithHeader<Accessory: View, Content: View>: View {
    let title: String
    let subtitle: String
    let metrics: [SkillLibraryMetric]
    @ViewBuilder let accessory: () -> Accessory
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String, metrics: [SkillLibraryMetric],
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() },
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.metrics = metrics
        self.accessory = accessory
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            SkillLibraryHeaderCard(
                title: title,
                subtitle: subtitle,
                metrics: metrics,
                accessory: accessory
            )
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(PH.Color.windowBg.ignoresSafeArea())
    }
}

// MARK: - Shared Split Shell

/// Shared two-pane shell for workspace browsers.
/// Keeps split sizing and background behavior consistent across prompt and skill surfaces.
struct WorkspaceSplitShell<Sidebar: View, Detail: View>: View {
    let sidebarMinWidth: CGFloat
    let sidebarIdealWidth: CGFloat
    let sidebarMaxWidth: CGFloat
    let detailMinWidth: CGFloat
    let allowsSidebarResizing: Bool
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    init(
        sidebarMinWidth: CGFloat = 200,
        sidebarIdealWidth: CGFloat = 240,
        sidebarMaxWidth: CGFloat = 360,
        detailMinWidth: CGFloat = 320,
        allowsSidebarResizing: Bool = false,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.sidebarMinWidth = sidebarMinWidth
        self.sidebarIdealWidth = sidebarIdealWidth
        self.sidebarMaxWidth = sidebarMaxWidth
        self.detailMinWidth = detailMinWidth
        self.allowsSidebarResizing = allowsSidebarResizing
        self.sidebar = sidebar
        self.detail = detail
    }

    var body: some View {
        HSplitView {
            sidebar()
                .frame(minWidth: allowsSidebarResizing ? sidebarMinWidth : sidebarIdealWidth)
                .frame(maxWidth: allowsSidebarResizing ? sidebarMaxWidth : sidebarIdealWidth)
                .background(PH.Color.sidebarBg)
            detail()
                .frame(minWidth: detailMinWidth, maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PH.Color.windowBg)
    }
}
