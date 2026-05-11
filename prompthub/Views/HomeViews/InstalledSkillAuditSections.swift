import AppKit
import PromptHubSkillKit
import SwiftUI

// MARK: - Agent Visibility

struct InstalledSkillAgentVisibilityView: View {
    let visibility: [SkillAgentVisibility]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Agent Visibility")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.mini)
                }
            }

            if visibility.isEmpty && !isLoading {
                Text("Visibility scan not available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(visibility, id: \.agent.rawValue) { entry in
                        let isVisible = entry.status == .visible
                        let isMissing = entry.status == .missing
                        HStack(spacing: 8) {
                            Image(systemName: isVisible ? "checkmark.circle.fill" : (isMissing ? "xmark.circle.fill" : "questionmark.circle.fill"))
                                .foregroundStyle(isVisible ? Color.green : (isMissing ? Color.red : Color.secondary))
                                .font(.system(size: 13))
                            Text(entry.agent.displayName)
                                .font(.callout)
                            Spacer()
                            Text(isVisible ? "Visible" : (isMissing ? "Missing" : "Unknown path"))
                                .font(.caption)
                                .foregroundStyle(isVisible ? Color.green : (isMissing ? Color.red : Color.secondary))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        if entry.agent != visibility.last?.agent {
                            Divider()
                        }
                    }
                }
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

// MARK: - Source Integrity

struct InstalledSkillIntegrityView: View {
    let integrity: SkillSourceIntegrity?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Source Integrity")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoading { ProgressView().controlSize(.mini) }
            }

            if isLoading && integrity == nil {
                Text("Checking source…").font(.caption).foregroundStyle(.secondary)
            } else if let integrity {
                VStack(spacing: 0) {
                    integrityStatusRow(integrity)
                    Divider()
                    if let hash = integrity.localHash {
                        integrityInfoRow(label: "Local SHA-256", value: String(hash.prefix(16)) + "…", fullValue: hash)
                    }
                    if let remoteHash = integrity.remoteHash {
                        Divider()
                        integrityInfoRow(label: "Remote SHA-256", value: String(remoteHash.prefix(16)) + "…", fullValue: remoteHash)
                    }
                }
                .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            } else if !isLoading {
                Text("Integrity check not available.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func integrityStatusRow(_ integrity: SkillSourceIntegrity) -> some View {
        let (icon, label, color): (String, String, Color) = {
            switch integrity.status {
            case .verified:      return ("checkmark.shield.fill",      "Verified — matches remote",              .green)
            case .modified:      return ("exclamationmark.shield.fill", "Modified — differs from remote",        .orange)
            case .remoteUnavailable: return ("wifi.slash",             "Remote unavailable (offline check)",    .secondary)
            case .noRemoteSource:    return ("internaldrive",          "Local-only skill, no remote source",    .secondary)
            case .notInstalled:  return ("xmark.circle",               "SKILL.md not found locally",            .red)
            }
        }()
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color).font(.system(size: 13))
            Text(label).font(.callout)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }

    private func integrityInfoRow(label: String, value: String, fullValue: String? = nil) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption.monospaced()).foregroundStyle(.primary)
                .help(fullValue ?? value)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Effectiveness / Quality

struct InstalledSkillEffectivenessView: View {
    let effectiveness: SkillEffectivenessReport?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Skill Quality")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoading { ProgressView().controlSize(.mini) }
            }

            if isLoading && effectiveness == nil {
                Text("Analyzing SKILL.md…").font(.caption).foregroundStyle(.secondary)
            } else if let report = effectiveness {
                if !report.fileFound {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                        Text("SKILL.md not found — cannot analyze quality.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().stroke(Color(NSColor.separatorColor), lineWidth: 3)
                                Circle()
                                    .trim(from: 0, to: report.score)
                                    .stroke(tierColor(report.tier), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                Text("\(Int(report.score * 100))")
                                    .font(.system(size: 11, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 5) {
                                    Image(systemName: report.tier.systemImage)
                                        .foregroundStyle(tierColor(report.tier)).font(.caption)
                                    Text(report.tier.label)
                                        .font(.callout.weight(.semibold))
                                        .foregroundStyle(tierColor(report.tier))
                                }
                                Text("\(report.checks.filter(\.passed).count) of \(report.checks.count) checks passed")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }

                        VStack(spacing: 0) {
                            ForEach(report.checks, id: \.title) { check in
                                effectivenessCheckRow(check)
                                if check.title != report.checks.last?.title { Divider() }
                            }
                        }
                        .background(Color(NSColor.textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else if !isLoading {
                Text("Quality analysis not available.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func tierColor(_ tier: EffectivenessTier) -> Color {
        switch tier {
        case .excellent: return .green
        case .good:      return .blue
        case .fair:      return .orange
        case .poor:      return .red
        }
    }

    @ViewBuilder
    private func effectivenessCheckRow(_ check: SkillEffectivenessCheck) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: check.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(check.passed ? Color.green : Color.red).font(.caption)
                Text(check.title).font(.callout)
                Spacer()
            }
            if !check.passed, let hint = check.hint {
                Text(hint).font(.caption).foregroundStyle(.secondary).padding(.leading, 20)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}
