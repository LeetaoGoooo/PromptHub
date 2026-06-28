//
//  ServicesPicker.swift
//  prompthub
//
//  Created by leetao on 2025/7/7.
//

import SwiftUI

struct ServicePicker: View {
    @Environment(ServicesManager.self) var manager
    
    private var selectedServiceIDBinding: Binding<String?> {
        Binding<String?>(
            get: {
                manager.selectedServiceID.isEmpty ? nil : manager.selectedServiceID
            },
            set: { newValue in
                manager.selectedServiceID = newValue ?? ""
            }
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsFieldLabel(
                "Active Service",
                caption: "Switch the provider whose endpoint, token, and preferred model you're editing."
            )

            Picker("", selection: selectedServiceIDBinding) {
                Text("None").tag(String?.none)
                ForEach(manager.services) { service in
                    Text(service.name).tag(service.id as String?)
                }
            }
            .pickerStyle(.menu)
        }
    }
}

#Preview {
    ServicePicker()
        .environment(ServicesManager())
}
