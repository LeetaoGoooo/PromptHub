import Foundation

enum WorkspaceDomain: Hashable {
    case prompts
    case skills
    case agents
    case special
}

enum PromptWorkspaceLens: Hashable {
    case all
    case mine
    case shared
    case explore
}

enum SkillWorkspaceLens: Hashable {
    case installed
    case drafts
    case store
}

enum AgentWorkspaceLens: Hashable {
    case workspaces
}

enum WorkspaceSpecialPage: Hashable {
    case settings
    case cliDashboard
    case onboarding
}

enum WorkspaceDetailSelection: Hashable {
    case prompt(UUID)
    case skill(UUID)
}

enum WorkspaceRoute: Hashable {
    case prompts(PromptWorkspaceLens)
    case skills(SkillWorkspaceLens)
    case agents(AgentWorkspaceLens)
    case special(WorkspaceSpecialPage)

    var domain: WorkspaceDomain {
        switch self {
        case .prompts: return .prompts
        case .skills: return .skills
        case .agents: return .agents
        case .special: return .special
        }
    }
}

struct WorkspaceNavigationState: Hashable {
    var domain: WorkspaceDomain = .prompts
    var promptLens: PromptWorkspaceLens = .all
    var skillLens: SkillWorkspaceLens = .installed
    var agentLens: AgentWorkspaceLens = .workspaces
    var detailSelection: WorkspaceDetailSelection? = nil
    var specialPage: WorkspaceSpecialPage? = nil
    var lastWorkspaceDomain: WorkspaceDomain = .prompts

    var currentRoute: WorkspaceRoute {
        switch domain {
        case .prompts:
            return .prompts(promptLens)
        case .skills:
            return .skills(skillLens)
        case .agents:
            return .agents(agentLens)
        case .special:
            return .special(specialPage ?? .settings)
        }
    }

    var currentWorkspaceDomain: WorkspaceDomain {
        domain == .special ? lastWorkspaceDomain : domain
    }

    var isDetailPresented: Bool {
        detailSelection != nil
    }

    mutating func showPrompts(_ lens: PromptWorkspaceLens? = nil) {
        if domain != .special {
            lastWorkspaceDomain = .prompts
        }
        domain = .prompts
        specialPage = nil
        detailSelection = nil
        if let lens { promptLens = lens }
    }

    mutating func showSkills(_ lens: SkillWorkspaceLens? = nil) {
        if domain != .special {
            lastWorkspaceDomain = .skills
        }
        domain = .skills
        specialPage = nil
        detailSelection = nil
        if let lens { skillLens = lens }
    }

    mutating func showAgents(_ lens: AgentWorkspaceLens? = nil) {
        if domain != .special {
            lastWorkspaceDomain = .agents
        }
        domain = .agents
        specialPage = nil
        detailSelection = nil
        if let lens { agentLens = lens }
    }

    mutating func showSpecial(_ page: WorkspaceSpecialPage) {
        if domain != .special {
            lastWorkspaceDomain = domain
        }
        domain = .special
        specialPage = page
        detailSelection = nil
    }

    mutating func selectPromptDetail(_ promptID: UUID) {
        lastWorkspaceDomain = .prompts
        domain = .prompts
        specialPage = nil
        detailSelection = .prompt(promptID)
    }

    mutating func selectSkillDetail(_ skillID: UUID) {
        lastWorkspaceDomain = .skills
        domain = .skills
        specialPage = nil
        detailSelection = .skill(skillID)
    }

    mutating func returnFromDetail() {
        detailSelection = nil
    }

    mutating func returnFromSpecial() {
        domain = lastWorkspaceDomain
        specialPage = nil
        detailSelection = nil
    }
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
