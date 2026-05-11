import AlertToast
import AppKit
import SwiftData
import SwiftUI
import WhatsNewKit

// MARK: - Actions

extension ContentView {

    func loadGalleryPrompts() {
        isLoading = true
        DispatchQueue.main.async {
            self.galleryPrompts = BuiltInAgents.agents.map { $0.toGalleryPrompt() }
            self.isLoading = false
        }
    }

    func showToastMessage(_ message: String, _ type: AlertToast.AlertType) {
        toastMessage = message; toastType = type; showToast = true
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showToastMessage("Copied to clipboard", .complete(.green))
    }

    func createNewPrompt() {
        let newPrompt = Prompt(name: "Untitled Prompt")
        modelContext.insert(newPrompt)
        let initialHistory = newPrompt.createHistory(prompt: "", version: 1)
        modelContext.insert(initialHistory)
        do {
            try modelContext.save()
            promptSelection = .prompt(newPrompt)
        } catch {
            showToastMessage("Failed to create new prompt", .error(.red))
        }
    }

    func createNewSkillDraft() {
        do {
            let draft = try skillDraftService.createDraft(in: modelContext)
            promptSelection = .skill(draft)
        } catch {
            showToastMessage("Failed to create new skill draft", .error(.red))
        }
    }

    func handleSearchNavigation(_ target: SearchNavigationTarget) {
        switch target {
        case .prompt(let promptID):
            searchText = ""
            if let prompt = prompts.first(where: { $0.id == promptID }) {
                promptSelection = .prompt(prompt)
            } else {
                promptSelection = .allPrompts
            }
        case .skill(let skillID):
            searchText = ""
            if let skill = skillDrafts.first(where: { $0.id == skillID }) {
                promptSelection = .skill(skill)
            } else {
                promptSelection = .mySkills
            }
        case .selection(let selection, let query):
            promptSelection = selection
            searchText = query ?? ""
        case .newPrompt:
            searchText = ""
            createNewPrompt()
        case .newSkillDraft:
            searchText = ""
            createNewSkillDraft()
        }
    }

    func checkForWhatsNew() {
        guard appSettings.lastShownWhatsNewVersion != currentAppVersion else { self.whatsNew = nil; return }
        self.whatsNew = WhatsNew(
            version: WhatsNew.Version(stringLiteral: currentAppVersion),
            title: WhatsNew.Title(stringLiteral: "What's New in PromptHub!"),
            features: [
                .init(image: .init(systemName: "wand.and.stars"),
                      title: WhatsNew.Text("Skill Library"),
                      subtitle: WhatsNew.Text("Browse, install, and manage AI skills from the new Skill Store with project & global scope support.")),
                .init(image: .init(systemName: "doc.text.magnifyingglass"),
                      title: WhatsNew.Text("Skill Drafts"),
                      subtitle: WhatsNew.Text("Create and edit skill drafts — promote any prompt into a reusable skill with one click.")),
                .init(image: .init(systemName: "magnifyingglass"),
                      title: WhatsNew.Text("Enhanced Search"),
                      subtitle: WhatsNew.Text("Search now covers skill drafts, supports navigation targets, and features a cleaner sectioned layout.")),
                .init(image: .init(systemName: "arrow.triangle.2.circlepath"),
                      title: WhatsNew.Text("Workspace Sync"),
                      subtitle: WhatsNew.Text("New workspace service keeps installed skills in sync across project and global scopes."))
            ],
            primaryAction: .init(title: WhatsNew.Text("Got It"), onDismiss: { appSettings.lastShownWhatsNewVersion = currentAppVersion })
        )
    }
}
