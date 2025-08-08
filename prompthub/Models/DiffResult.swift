//
//  DiffResult.swift
//  prompthub
//
//  Created by leetao on 2025/8/6.
//

import Foundation

// Represents a single line in the diff output
enum DiffResult: Hashable, Identifiable {
    case added(String)
    case removed(String)
    case common(String)

    var id: String {
        switch self {
        case .added(let line):
            return "add:\(line.hashValue)"
        case .removed(let line):
            return "rem:\(line.hashValue)"
        case .common(let line):
            return "com:\(line.hashValue)"
        }
    }

    var text: String {
        switch self {
        case .added(let line), .removed(let line), .common(let line):
            return line
        }
    }
    
    var prefix: String {
        switch self {
        case .added: return "+"
        case .removed: return "-"
        case .common: return " "
        }
    }
}
