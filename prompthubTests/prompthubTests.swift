import Foundation
import Testing
@testable import prompthub

// MARK: - DiffResult Tests

struct DiffResultTests {

    @Test func textReturnsLineForAllCases() {
        #expect(DiffResult.added("hello").text == "hello")
        #expect(DiffResult.removed("world").text == "world")
        #expect(DiffResult.common("same").text == "same")
    }

    @Test func prefixIsCorrectForAllCases() {
        #expect(DiffResult.added("a").prefix == "+")
        #expect(DiffResult.removed("b").prefix == "-")
        #expect(DiffResult.common("c").prefix == " ")
    }

    @Test func hashableConformance() {
        let a1 = DiffResult.added("x")
        let a2 = DiffResult.added("x")
        let r1 = DiffResult.removed("x")
        var set = Set<DiffResult>()
        set.insert(a1)
        set.insert(a2)
        set.insert(r1)
        #expect(set.count == 2)
    }
}

// MARK: - DifferPromptChanges Tests

struct DifferPromptChangesTests {

    @Test func identicalInputsProduceAllCommonLines() {
        let lines = ["line one", "line two", "line three"]
        let result = createDiffWithDifferenceKit(old: lines, new: lines)
        let allCommon = result.allSatisfy { if case .common = $0 { return true }; return false }
        #expect(allCommon)
        #expect(result.count == lines.count)
    }

    @Test func emptyOldProducesAllAdded() {
        let newLines = ["alpha", "beta"]
        let result = createDiffWithDifferenceKit(old: [], new: newLines)
        let allAdded = result.allSatisfy { if case .added = $0 { return true }; return false }
        #expect(allAdded)
        #expect(result.count == newLines.count)
    }

    @Test func emptyNewProducesAllRemoved() {
        let oldLines = ["alpha", "beta"]
        let result = createDiffWithDifferenceKit(old: oldLines, new: [])
        let allRemoved = result.allSatisfy { if case .removed = $0 { return true }; return false }
        #expect(allRemoved)
        #expect(result.count == oldLines.count)
    }

    @Test func addedLineAppearsInResult() {
        let old = ["line one", "line two"]
        let new = ["line one", "inserted", "line two"]
        let result = createDiffWithDifferenceKit(old: old, new: new)
        let addedTexts = result.compactMap { if case .added(let t) = $0 { return t } else { return nil } }
        #expect(addedTexts.contains("inserted"))
    }

    @Test func removedLineAppearsInResult() {
        let old = ["keep", "remove me", "keep"]
        let new = ["keep", "keep"]
        let result = createDiffWithDifferenceKit(old: old, new: new)
        let removedTexts = result.compactMap { if case .removed(let t) = $0 { return t } else { return nil } }
        #expect(removedTexts.contains("remove me"))
    }
}

// MARK: - String+Extensions Tests

struct StringExtensionsTests {

    @Test func titleCasedConvertsKebabCase() {
        #expect("apple-ios-design-expert".titleCased == "Apple iOS Design Expert")
    }

    @Test func titleCasedConvertsSnakeCase() {
        let result = "my_skill_name".titleCased
        #expect(result == "My Skill Name")
    }

    @Test func titleCasedPreservesSpecialTerms() {
        #expect("macos-cli-tool".titleCased == "macOS CLI Tool")
    }

    @Test func titleCasedSingleWord() {
        #expect("hello".titleCased == "Hello")
    }

    @Test func titleCasedEmptyString() {
        #expect("".titleCased == "")
    }
}

// MARK: - SearchNavigationRequest Tests

struct SearchNavigationRequestTests {

    @Test func postAndReceivePromptTarget() async {
        let expectation = AsyncStream<SearchNavigationTarget>.makeStream()
        let token = NotificationCenter.default.addObserver(
            forName: .searchNavigationRequested,
            object: nil,
            queue: nil
        ) { note in
            if let target = SearchNavigationRequest.from(note) {
                expectation.continuation.yield(target)
                expectation.continuation.finish()
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let targetID = UUID()
        SearchNavigationRequest.post(.prompt(targetID))

        var iterator = expectation.stream.makeAsyncIterator()
        let received = await iterator.next()
        #expect(received == .prompt(targetID))
    }

    @Test func postAndReceiveSkillTarget() async {
        let expectation = AsyncStream<SearchNavigationTarget>.makeStream()
        let token = NotificationCenter.default.addObserver(
            forName: .searchNavigationRequested,
            object: nil,
            queue: nil
        ) { note in
            if let target = SearchNavigationRequest.from(note) {
                expectation.continuation.yield(target)
                expectation.continuation.finish()
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let targetID = UUID()
        SearchNavigationRequest.post(.skill(targetID))

        var iterator = expectation.stream.makeAsyncIterator()
        let received = await iterator.next()
        #expect(received == .skill(targetID))
    }

    @Test func fromNotificationWithMissingKeyReturnsNil() {
        let note = Notification(name: .searchNavigationRequested, object: nil, userInfo: [:])
        #expect(SearchNavigationRequest.from(note) == nil)
    }
}

// MARK: - PromptSelection Tests

struct PromptSelectionTests {

    @Test func allPromptsCaseIsDistinct() {
        let sel = PromptSelection.allPrompts
        if case .allPrompts = sel {
            // pass
        } else {
            Issue.record("Expected .allPrompts")
        }
    }

    @Test func equalityForSimpleCases() {
        #expect(PromptSelection.allPrompts == .allPrompts)
        #expect(PromptSelection.mySkills == .mySkills)
        #expect(PromptSelection.settings == .settings)
        #expect(PromptSelection.skillStore == .skillStore)
    }

    @Test func inequalityForDifferentSimpleCases() {
        #expect(PromptSelection.allPrompts != .mySkills)
        #expect(PromptSelection.settings != .explore)
    }
}
