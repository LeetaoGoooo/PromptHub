import SwiftData
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    let onCLI: () -> Void
    let onSettings: () -> Void

    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared
    @Environment(ServicesManager.self) private var servicesManager
    @Query private var prompts: [Prompt]
    @Query(sort: \Skill.updatedAt, order: .reverse) private var skillDrafts: [Skill]

    private var configuredServiceName: String? {
        servicesManager.services.first(where: { !$0.token.isEmpty })?.name
    }

    private var aiServiceConnected: Bool { configuredServiceName != nil }
    private var cliConnected: Bool { cliAccess.grantedDirectories.count > 0 }
    private var hasPrompt: Bool { !prompts.isEmpty }
    private var hasSkillDraft: Bool { !skillDrafts.isEmpty }

    private func finish() {
        onboardingCompleted = true
        onFinish()
    }

    private func goToCLI() {
        onCLI()
    }

    var body: some View {
        HSplitView {
            ScrollView {
                VStack(spacing: 28) {
                    heroSection

                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)], spacing: 16) {
                        OnboardingStepTile(
                            number: 1,
                            title: "Connect AI Service",
                            description: "Link your OpenAI, Anthropic, or Ollama API key so prompts can run live previews and tests.",
                            isDone: aiServiceConnected,
                            ctaText: aiServiceConnected ? "Connected to \(configuredServiceName ?? "service")" : "Open Settings",
                            ctaAction: {
                                if aiServiceConnected {
                                    finish()
                                } else {
                                    onSettings()
                                }
                            }
                        )
                        OnboardingStepTile(
                            number: 2,
                            title: "Create Your First Prompt",
                            description: "Start with a template or write from scratch. Add variables with {{placeholders}} to make prompts reusable.",
                            isDone: hasPrompt,
                            ctaText: hasPrompt ? "\(prompts.count) prompts created" : "Go to Library",
                            ctaAction: finish
                        )
                        OnboardingStepTile(
                            number: 3,
                            title: "Set Up Skill Access",
                            description: "Grant access to your agent folders and choose a project folder when you need project-scoped installs. You can also install the `ph` CLI with `brew install dosomeforfun/prompthub/ph` to script prompt exports and skill installs from your terminal or CI.",
                            isDone: cliConnected,
                            ctaText: cliConnected ? "Access configured" : "Open settings",
                            isHighlighted: true,
                            ctaAction: goToCLI
                        )
                        OnboardingStepTile(
                            number: 4,
                            title: "Build Your First Skill",
                            description: "Promote a prompt into a reusable Skill that can be installed globally or scoped to a project.",
                            isDone: hasSkillDraft,
                            ctaText: hasSkillDraft ? "\(skillDrafts.count) skills drafted" : "Start building",
                            ctaAction: finish
                        )
                    }

                    HStack(spacing: 12) {
                        Button(action: finish) {
                            Label("Go to Library", systemImage: "checkmark")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button(action: goToCLI) {
                            Label("Open Skill Access", systemImage: "terminal")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            .background(Color(NSColor.windowBackgroundColor))

            OnboardingProgressSidebar(
                aiServiceConnected: aiServiceConnected,
                hasPrompt: hasPrompt,
                cliConnected: cliConnected,
                hasSkillDraft: hasSkillDraft
            )
            .frame(minWidth: 280, idealWidth: 300, maxWidth: 320, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var heroSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.accent)
            Text("Welcome to PromptHub")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Your AI prompt and skills workspace. Let's get you set up in 4 steps — it only takes a few minutes.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 760)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}

private struct OnboardingStepTile: View {
    let number: Int
    let title: String
    let description: String
    let isDone: Bool
    let ctaText: String
    var isHighlighted: Bool = false
    let ctaAction: () -> Void

    var body: some View {
        Button(action: ctaAction) {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isDone ? Color.green : (isHighlighted ? Color.accentColor : Color(NSColor.separatorColor).opacity(0.7)))
                        .frame(width: 34, height: 34)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    } else {
                        Text("\(number)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(isHighlighted ? .white : .primary)
                    }
                }

                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.leading)

                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Image(systemName: isDone ? "checkmark" : "arrow.right")
                    Text(ctaText)
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isDone ? .green : .accent)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
            .background(Color(NSColor.controlBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isHighlighted && !isDone ? Color.accentColor.opacity(0.35) : Color(NSColor.separatorColor).opacity(0.28), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

private struct OnboardingProgressSidebar: View {
    let aiServiceConnected: Bool
    let hasPrompt: Bool
    let cliConnected: Bool
    let hasSkillDraft: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Setup Progress")
                .font(.headline)

            ProgressItem(title: "Welcome", isDone: true)
            ProgressItem(title: "Connect AI Service", isDone: aiServiceConnected)
            ProgressItem(title: "Create First Prompt", isDone: hasPrompt)
            ProgressItem(title: "Set Up CLI", isDone: cliConnected)
            ProgressItem(title: "Build First Skill", isDone: hasSkillDraft)

            Spacer()
        }
        .padding(18)
    }
}

private struct ProgressItem: View {
    let title: String
    let isDone: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isDone ? .green : .secondary)
            Text(title)
                .font(.callout)
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    OnboardingView(onFinish: {}, onCLI: {}, onSettings: {})
        .frame(width: 1080, height: 760)
    .modelContainer(PreviewData.previewContainer)
}
