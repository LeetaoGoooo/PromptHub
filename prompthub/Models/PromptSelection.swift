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
    case cliDashboard
    case onboarding

    static func == (lhs: PromptSelection, rhs: PromptSelection) -> Bool {
        switch (lhs, rhs) {
        case (.allPrompts, .allPrompts), (.mine, .mine), (.shared, .shared),
             (.explore, .explore), (.mySkills, .mySkills), (.skillStore, .skillStore),
             (.installedSkills, .installedSkills), (.settings, .settings),
             (.cliDashboard, .cliDashboard), (.onboarding, .onboarding): return true
        case (.prompt(let l), .prompt(let r)): return l.id == r.id
        case (.skill(let l), .skill(let r)):   return l.id == r.id
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .allPrompts:      hasher.combine("allPrompts")
        case .mine:            hasher.combine("mine")
        case .shared:          hasher.combine("shared")
        case .explore:         hasher.combine("explore")
        case .mySkills:        hasher.combine("mySkills")
        case .skillStore:      hasher.combine("skillStore")
        case .installedSkills: hasher.combine("installedSkills")
        case .settings:        hasher.combine("settings")
        case .cliDashboard:    hasher.combine("cliDashboard")
        case .onboarding:      hasher.combine("onboarding")
        case .prompt(let p):   hasher.combine("prompt"); hasher.combine(p.id)
        case .skill(let s):    hasher.combine("skill"); hasher.combine(s.id)
        }
    }
}

enum SidebarPrimaryArea: String, CaseIterable, Hashable {
    case skills
    case prompts
    case agents
}

enum SkillsSidebarScopeFilter: Hashable {
    case allInstalled
    case global
    case project
    case drafts
}

enum SkillsSidebarSourceFilter: Hashable {
    case all
    case external
    case localOnly
    case discover
}

extension PromptSelection {
    var sidebarPrimaryArea: SidebarPrimaryArea {
        switch self {
        case .allPrompts, .mine, .shared, .explore, .prompt:
            return .prompts
        case .mySkills, .skill, .skillStore, .installedSkills:
            return .skills
        case .cliDashboard:
            return .agents
        case .settings, .onboarding:
            return .prompts
        }
    }
}
