import Foundation

// MARK: - Navigation Selection

enum PromptSelection: Hashable, Equatable {
    case allPrompts
    case mine
    case shared
    case explore
    case mySkills
    case prompt(Prompt)
    case skill(Skill)
    case skillStore
    case installedSkills
    case settings

    static func == (lhs: PromptSelection, rhs: PromptSelection) -> Bool {
        switch (lhs, rhs) {
        case (.allPrompts, .allPrompts), (.mine, .mine), (.shared, .shared),
             (.explore, .explore), (.mySkills, .mySkills), (.skillStore, .skillStore),
             (.installedSkills, .installedSkills), (.settings, .settings): return true
        case (.prompt(let l), .prompt(let r)): return l.id == r.id
        case (.skill(let l), .skill(let r)):   return l.id == r.id
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .allPrompts:     hasher.combine("allPrompts")
        case .mine:           hasher.combine("mine")
        case .shared:         hasher.combine("shared")
        case .explore:        hasher.combine("explore")
        case .mySkills:       hasher.combine("mySkills")
        case .skillStore:     hasher.combine("skillStore")
        case .installedSkills: hasher.combine("installedSkills")
        case .settings:       hasher.combine("settings")
        case .prompt(let p):  hasher.combine("prompt"); hasher.combine(p.id)
        case .skill(let s):   hasher.combine("skill"); hasher.combine(s.id)
        }
    }
}
