import Foundation
import Testing
@testable import prompthub

class MockCommandLineExecutor: CommandLineExecutor, @unchecked Sendable {
    var resultToReturn: Result<String, Error>?
    var lastArgs: [String]?

    func execute(args: [String]) async throws -> String {
        lastArgs = args
        guard let result = resultToReturn else {
            fatalError("MockCommandLineExecutor: resultToReturn not set")
        }
        switch result {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }
}

struct SkillCLIServiceTests {

    @Test func testFindSkillsSuccess() async throws {
        let mockExecutor = MockCommandLineExecutor()
        let service = SkillCLIService(executor: mockExecutor)
        
        // Realistic npx skills find --list output
        let mockOutput = """
        sandboxagent/dev@sandbox
        └ https://skills.sh/sandboxagent/dev/sandbox

        johnlindquist/claude@agent-mail
        └ https://skills.sh/johnlindquist/claude/agent-mail
        """
        mockExecutor.resultToReturn = .success(mockOutput)
        
        let skills = try await service.findSkills(query: "agent")
        
        #expect(skills.count == 2)
        #expect(skills[0].name == "sandboxagent/dev@sandbox")
        #expect(skills[0].description == "https://skills.sh/sandboxagent/dev/sandbox")
        #expect(mockExecutor.lastArgs?.contains("agent") == true)
    }
    
    @Test func testListInstalledSkillsSuccess() async throws {
        let mockExecutor = MockCommandLineExecutor()
        let service = SkillCLIService(executor: mockExecutor)
        
        // Realistic npx skills list -g output
        let mockOutput = """
        Global Skills

        apple-ios-design-expert ~/.agents/skills/apple-ios-design-expert
          Agents: Codex, Gemini CLI, iFlow CLI, Qwen Code
        ios-dev-expert ~/.agents/skills/ios-dev-expert
          Agents: Codex, Gemini CLI, iFlow CLI, Qwen Code
        """
        mockExecutor.resultToReturn = .success(mockOutput)
        
        let skills = try await service.listInstalledSkills()
        
        #expect(skills.count == 2)
        #expect(skills[0].name == "apple-ios-design-expert")
        #expect(skills[0].isInstalled == true)
        #expect(skills[0].description.contains("Agents: Codex"))
    }
    
    @Test func testCommandFailedError() async throws {
        let mockExecutor = MockCommandLineExecutor()
        let service = SkillCLIService(executor: mockExecutor)
        
        mockExecutor.resultToReturn = .failure(RealCommandLineExecutor.ExecutorError.commandFailed("Permission denied"))
        
        await #expect(throws: SkillCLIService.CLIError.self) {
            try await service.findSkills()
        }
    }
}
