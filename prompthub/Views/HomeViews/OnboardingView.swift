import SwiftUI

/// Onboarding view — guides new users through 4 setup steps.
/// Full implementation: UI-4 task.
struct OnboardingView: View {
    let onFinish: () -> Void
    let onCLI: () -> Void

    @AppStorage("onboarding.aiServiceConnected") private var aiServiceConnected = false
    @AppStorage("onboarding.firstPromptCreated") private var firstPromptCreated = false
    @AppStorage("onboarding.cliSetupSeen") private var cliSetupSeen = false
    @ObservedObject private var cliAccess = CLIDirectoryAccessManager.shared

    private var cliConnected: Bool { cliAccess.grantedDirectories.count > 0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // ── Hero ────────────────────────────────────────────────
                VStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundStyle(.tint)
                    Text("Welcome to PromptHub")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Your AI prompt and skills workspace. Let's get you set up in 4 steps.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                // ── Steps ───────────────────────────────────────────────
                VStack(spacing: 12) {
                    OnboardingStepCard(
                        number: 1,
                        title: "Connect AI Service",
                        description: "Link your OpenAI, Anthropic, or Ollama API key so prompts can run live previews and tests.",
                        isDone: aiServiceConnected,
                        ctaLabel: "Open Settings",
                        ctaAction: { aiServiceConnected = true }
                    )
                    OnboardingStepCard(
                        number: 2,
                        title: "Create Your First Prompt",
                        description: "Start with a template or write from scratch. Add variables with {{placeholders}} to make prompts reusable.",
                        isDone: firstPromptCreated,
                        ctaLabel: "Go to Library",
                        ctaAction: { firstPromptCreated = true; onFinish() }
                    )
                    OnboardingStepCard(
                        number: 3,
                        title: "Set Up CLI Integration",
                        description: "This is what makes PromptHub different. Install skills directly into Claude Code, Cursor, Codex — no copy-paste.",
                        isDone: cliConnected,
                        ctaLabel: "Set Up CLI",
                        isHighlighted: true,
                        ctaAction: { cliSetupSeen = true; onCLI() }
                    )
                    OnboardingStepCard(
                        number: 4,
                        title: "Build Your First Skill",
                        description: "Promote a prompt into a reusable Skill — a structured agent instruction that installs into any AI coding agent.",
                        isDone: false,
                        ctaLabel: "Start Building",
                        ctaAction: onFinish
                    )
                }
                .frame(maxWidth: 560)

                // ── Actions ─────────────────────────────────────────────
                HStack(spacing: 12) {
                    Button(action: onFinish) {
                        Label("Go to Library", systemImage: "tray.full")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onCLI) {
                        Label("Set Up CLI", systemImage: "terminal")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Step Card

private struct OnboardingStepCard: View {
    let number: Int
    let title: String
    let description: String
    let isDone: Bool
    let ctaLabel: String
    var isHighlighted: Bool = false
    let ctaAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Step number / checkmark
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isHighlighted ? Color.accentColor : Color(NSColor.separatorColor)))
                    .frame(width: 32, height: 32)
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

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(title)
                        .font(.headline)
                    if isHighlighted && !isDone {
                        Text("RECOMMENDED")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                }
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if isDone {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Button(ctaLabel, action: ctaAction)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .tint(isHighlighted ? .accentColor : nil)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isHighlighted && !isDone ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )
        )
    }
}

#Preview {
    OnboardingView(onFinish: {}, onCLI: {})
        .frame(width: 700, height: 600)
}
