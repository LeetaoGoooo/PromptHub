//
//  DataSource.swift
//  prompthub
//
//  Created by leetao on 2025/6/23.
//


import SwiftData
import Foundation

@Model
final class DataSource {
    var id: UUID = UUID()

    @Attribute(.externalStorage)
    var data: Data = Data()

    var creation: SharedCreation?

    init(data: Data) {
        self.data = data
    }
}
