import AppKit
import SwiftUI

// MARK: - Metric Model

struct SkillLibraryMetric: Identifiable {
    let value: String
    let title: String
    let systemImage: String
    var id: String { title }
}

// MARK: - Header Card

struct SkillLibraryHeaderCard<Accessory: View>: View {
    let title: String
    let subtitle: String
    let metrics: [SkillLibraryMetric]
    @ViewBuilder let accessory: () -> Accessory

    init(title: String, subtitle: String, metrics: [SkillLibraryMetric],
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.title = title; self.subtitle = subtitle; self.metrics = metrics; self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.title3.weight(.semibold))
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                }
            }
            Spacer(minLength: 8)
            if !metrics.isEmpty {
                HStack(spacing: 6) {
                    ForEach(metrics) { metric in
                        HStack(spacing: 4) {
                            Image(systemName: metric.systemImage).font(.caption2).foregroundStyle(.secondary)
                            Text(metric.value).font(.caption.weight(.semibold)).foregroundStyle(.primary)
                            Text(metric.title).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor)).clipShape(Capsule())
                        .overlay(Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 0.5))
                    }
                }
            }
            accessory()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
        Divider()
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
        self.title = title; self.subtitle = subtitle; self.metrics = metrics; self.accessory = accessory; self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            SkillLibraryHeaderCard(title: title, subtitle: subtitle, metrics: metrics, accessory: accessory)
            content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        self.sidebarMinWidth = sidebarMinWidth; self.sidebarIdealWidth = sidebarIdealWidth
        self.sidebarMaxWidth = sidebarMaxWidth; self.detailMinWidth = detailMinWidth
        self.sidebar = sidebar; self.detail = detail
    }

    var body: some View {
        HSplitView {
            sidebar()
                .frame(minWidth: sidebarMinWidth, idealWidth: sidebarIdealWidth, maxWidth: sidebarMaxWidth, maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.controlBackgroundColor))
            detail()
                .frame(minWidth: detailMinWidth, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
