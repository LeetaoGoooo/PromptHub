//
//  SettingView.swift
//  prompthub
//
//  Created by leetao on 2025/3/7.
//

import SwiftUI

struct SettingsView: View {
    @State private var selectedSetting: SettingItem? = .general

    enum SettingItem: String, CaseIterable, Identifiable {
        case general = "General"
        case about = "About"

        var id: Self { self }
    }

    var body: some View {
        NavigationView {
            List(SettingItem.allCases) { setting in // Sidebar List
                NavigationLink(
                    destination: settingView(for: setting), // Content view based on selected setting
                    tag: setting,
                    selection: $selectedSetting
                ) {
                    Text(setting.rawValue)
                }
            }
            .listStyle(SidebarListStyle())
            settingView(for: selectedSetting ?? .general)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func settingView(for setting: SettingItem) -> some View {
        switch setting {
            case .general:
                GeneralView()
                    .padding()
            case .about:
                AboutContentView()
        }
    }
}

#Preview {
    return SettingsView()
        .environmentObject(AppSettings())
}
