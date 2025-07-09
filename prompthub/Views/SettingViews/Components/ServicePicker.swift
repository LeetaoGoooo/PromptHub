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
        VStack(alignment:.leading) {
            Text("Service")
                .font(.subheadline)
                .foregroundColor(.gray)
            
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
