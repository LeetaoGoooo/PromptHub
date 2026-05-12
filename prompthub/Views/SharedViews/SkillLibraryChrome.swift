import AppKit
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
    @Binding var promptSelection: PromptSelection

    private var selectedTab: Binding<SkillsWorkspaceTab> {
        Binding(
            get: {
                switch promptSelection {
                case .installedSkills:
                    return .installed
                case .mySkills, .skill:
                    return .drafts
                case .skillStore:
                    return .discover
                default:
                    return .installed
                }
            },
            set: { newValue in
                switch newValue {
                case .installed:
                    promptSelection = .installedSkills
                case .drafts:
                    promptSelection = .mySkills
                case .discover:
                    promptSelection = .skillStore
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
    @Binding var promptSelection: PromptSelection

    private var selectedTab: Binding<PromptsWorkspaceTab> {
        Binding(
            get: {
                switch promptSelection {
                case .mine:    return .mine
                case .shared:  return .shared
                case .explore: return .explore
                default:       return .all
                }
            },
            set: { newValue in
                switch newValue {
                case .all:     promptSelection = .allPrompts
                case .mine:    promptSelection = .mine
                case .shared:  promptSelection = .shared
                case .explore: promptSelection = .explore
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

// MARK: - Liquid Glass Material

/// Bridges NSVisualEffectView into SwiftUI for true macOS vibrancy.
/// This is the foundation of the Liquid Glass aesthetic — blending the window
/// content behind the header surface rather than using a flat colour fill.
struct LibraryGlassMaterial: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Header Card

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
        VStack(alignment: .leading, spacing: 10) {
            // Row 1 — title only (full width, breathes)
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)

            // Row 2 — subtitle (allowed to wrap up to 2 lines instead of mid-truncating)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Row 3 — accessory bar on its own row, right-aligned
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                // FIX (line 38 crash): isolate AppKit-backed controls' layout pass.
                HStack(spacing: 6) { accessory() }
                    .fixedSize(horizontal: true, vertical: false)
            }

            // Row 4 — metric strip
            if !metrics.isEmpty {
                HStack(spacing: 14) {
                    ForEach(metrics) { metric in
                        HStack(spacing: 5) {
                            Image(systemName: metric.systemImage)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.tertiary)
                            Text(metric.value)
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(metric.title)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Liquid Glass: vibrancy layer + specular edge highlight
            ZStack(alignment: .top) {
                LibraryGlassMaterial(material: .headerView, blendingMode: .withinWindow)
                LinearGradient(
                    colors: [Color.white.opacity(0.11), Color.clear],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.6)
                )
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 0.5)
        }
    }
}

// MARK: - Screen Layout

struct SkillLibraryScreen<Accessory: View, Content: View>: View {
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
        .background {
            // In-window content vibrancy. Use .contentBackground + .withinWindow
            // so the surface samples the window's own backdrop rather than the
            // desktop wallpaper behind the window (which .behindWindow would do).
            LibraryGlassMaterial(material: .contentBackground, blendingMode: .withinWindow)
                .ignoresSafeArea()
        }
    }
}

// MARK: - Browser Split Layout

struct SkillLibraryBrowser<Sidebar: View, Detail: View>: View {
    let sidebarMinWidth: CGFloat
    let sidebarIdealWidth: CGFloat
    let sidebarMaxWidth: CGFloat
    let detailMinWidth: CGFloat
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

            init(sidebarMinWidth: CGFloat = 220, sidebarIdealWidth: CGFloat = 260,
                sidebarMaxWidth: CGFloat = 380, detailMinWidth: CGFloat = 400,
         @ViewBuilder sidebar: @escaping () -> Sidebar,
         @ViewBuilder detail: @escaping () -> Detail) {
        self.sidebarMinWidth = sidebarMinWidth
        self.sidebarIdealWidth = sidebarIdealWidth
        self.sidebarMaxWidth = sidebarMaxWidth
        self.detailMinWidth = detailMinWidth
        self.sidebar = sidebar
        self.detail = detail
    }

    var body: some View {
        HSplitView {
            sidebar()
                .frame(
                    minWidth: sidebarMinWidth,
                    idealWidth: sidebarIdealWidth,
                    maxWidth: sidebarMaxWidth,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .background(Color(NSColor.controlBackgroundColor))
            detail()
                .frame(minWidth: detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

