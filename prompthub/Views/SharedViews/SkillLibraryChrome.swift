import AppKit
import SwiftUI

// MARK: - Metric Model

struct SkillLibraryMetric: Identifiable {
    let value: String
    let title: String
    let systemImage: String
    var id: String { title }
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
        VStack(spacing: 0) {
            // Row 1 — title + toolbar
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Spacer(minLength: 12)

                // FIX (line 38 crash): NSView-backed controls (.menuStyle(.borderedButton),
                // .buttonStyle(.bordered)) call -layoutSubtreeIfNeeded during SwiftUI's own
                // layout pass, causing AppKit recursion. Wrapping in HStack + .fixedSize
                // creates an isolated layout boundary — SwiftUI treats the accessory as a
                // fixed-size atom and stops probing it for size during the parent layout pass.
                HStack(spacing: 6) { accessory() }
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, metrics.isEmpty ? 14 : 6)

            // Row 2 — compact metric strip
            if !metrics.isEmpty {
                HStack(spacing: 0) {
                    ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                        HStack(spacing: 4) {
                            Image(systemName: metric.systemImage)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.tertiary)
                            Text(metric.value)
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Text(metric.title)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        if index < metrics.count - 1 {
                            Text("·")
                                .font(.caption2)
                                .foregroundStyle(.quaternary)
                                .padding(.horizontal, 5)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Liquid Glass: vibrancy layer + specular edge highlight
            ZStack(alignment: .top) {
                LibraryGlassMaterial(material: .headerView, blendingMode: .withinWindow)
                // Specular top-edge shimmer — the defining glass highlight
                LinearGradient(
                    colors: [Color.white.opacity(0.11), Color.clear],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.6)
                )
            }
        }
        .overlay(alignment: .bottom) {
            // Bottom edge: thin rule that separates glass header from content
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
        .background(Color(NSColor.windowBackgroundColor))
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

    init(sidebarMinWidth: CGFloat = 280, sidebarIdealWidth: CGFloat = 310,
         sidebarMaxWidth: CGFloat = 460, detailMinWidth: CGFloat = 520,
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

