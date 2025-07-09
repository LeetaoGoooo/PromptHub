//
//  ServicesView.swift
//  prompthub
//
//  Created by leetao on 2025/7/7.
//

import SwiftUI

struct ServicesView: View {
    @Environment(ServicesManager.self) var manager

    private var selectedServiceIndex: Int? {
        manager.services.firstIndex(where: { $0.id == manager.selectedServiceID })
    }

    var body: some View {
        @Bindable var manager = manager

        VStack(alignment: .leading) {
            ServicePicker()

            Group {
                if let index = selectedServiceIndex {
                    ServiceForm(service: $manager.services[index])
                        .id(manager.services[index].id)
                } else {
                    ContentUnavailableView(
                        "No Service Selected",
                        systemImage: "square.stack.3d.up.slash",
                        description: Text("Please select a service from the list above.")
                    )
                }
            }
        }
    }
}

#Preview {
    let manager = ServicesManager()
    return ServicesView()
        .environment(manager)
}
