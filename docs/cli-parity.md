# PromptHub App ↔ `ph` CLI Parity Matrix

This document is the contractual surface between the PromptHub macOS app and the
standalone `ph` CLI. The integration seam is the filesystem layout under
`~/.prompthub/`. Anything in the **Must match** column below MUST behave
identically on both sides. A failing parity regression test against this contract
should block release.

## Filesystem layout

```
~/.prompthub/
  prompts/<uuid>.md           # one file per prompt
  skills/<uuid>/SKILL.md      # package directory per skill
  skills/<uuid>/<sibling…>    # arbitrary sibling files copied verbatim
```

Both sides agree the UUID is the **stable identity** of the asset. Slugs and
display names are derived attributes and may change without breaking the bridge.

## Exported prompt parity

| Field         | App source (PromptHubBridge.promptMarkdown) | CLI surface (`ph prompt list/show`)          | Must match | Notes |
|---------------|---------------------------------------------|----------------------------------------------|------------|-------|
| `id`          | `Prompt.id.uuidString`                       | `PromptHubExportedAsset.id`                  | yes        | filename stem == `id`
| `name`        | `Prompt.name` (YAML scalar quoted as needed) | `PromptHubExportedAsset.name`                | yes        |
| `slug`        | `PromptHubBridge.slug(for:)`                 | `PromptHubExportedAsset.slug`                | yes        |
| `description` | `Prompt.desc`                                | `PromptHubExportedAsset.summary`             | yes        | optional
| `link`        | `Prompt.link`                                | not surfaced today                           | no         | app-only metadata
| `exported_at` | ISO8601 timestamp                            | `PromptHubExportedAsset.exportedAt`          | yes        | rendered as opaque string; both sides ignore on read
| body          | `Prompt.getLatestPromptContent()`            | `PromptHubExportedAsset.body`                | yes        |

## Exported skill parity

| Field         | App source (PromptHubBridge.skillMarkdown)   | CLI surface (`ph skill exports/show`)        | Must match | Notes |
|---------------|----------------------------------------------|----------------------------------------------|------------|-------|
| `id`          | `Skill.id.uuidString`                        | `PromptHubExportedAsset.id`                  | yes        | also the package directory name
| `name`        | `Skill.displayName`                          | `PromptHubExportedAsset.name`                | yes        |
| `slug`        | `Skill.installationName`                     | `PromptHubExportedAsset.slug`                | yes        | also drives `installationName`
| `description` | `Skill.desc`                                 | `PromptHubExportedAsset.summary`             | yes        |
| `category`    | `Skill.category`                             | `PromptHubExportedAsset.category`            | yes        |
| `tags`        | `Skill.tags`                                 | `PromptHubExportedAsset.tags`                | yes        | YAML inline array
| `exported_at` | ISO8601 timestamp                            | `PromptHubExportedAsset.exportedAt`          | yes        |
| body          | `Skill.latestVersion?.instructions`          | `PromptHubExportedAsset.body`                | yes        |
| package files | sibling files under the package directory     | preserved verbatim under exported package    | yes        | `PromptHubBridge.exportSkill` copies the whole directory

## Installed skill parity

| Field                    | App (SkillCLIService / dashboard)            | CLI surface (`ph skill list/inspect`)        | Must match | Notes |
|--------------------------|----------------------------------------------|----------------------------------------------|------------|-------|
| package name             | `InstalledSkillSnapshot.name`                | `PromptHubInstalledSkillSummary.package`     | yes        |
| scope (`global`/`project`)| `InstalledSkillSnapshot.isGlobal`            | `PromptHubInstalledSkillSummary.scope`       | yes        |
| agents resolved          | `InstalledSkillSnapshot.installedAgents`     | `PromptHubInstalledSkillSummary.agents`      | yes        | sorted string array on CLI
| managed-by-PromptHub flag | `InstalledSkillSnapshot.isManagedByPromptHub`| `PromptHubInstalledSkillSummary.isManagedByPromptHub` | yes |
| source URL                | `InstalledSkillSnapshot.url`                 | `PromptHubInstalledSkillSummary.url`         | yes        | optional
| installed paths           | `InstalledSkillSnapshot.installedPaths`      | `PromptHubInstalledSkillSummary.installedPaths` | yes      | sorted; macOS `/var ↔ /private/var` symlink may produce two equivalent entries
| description copy          | UI string                                    | `PromptHubInstalledSkillSummary.description` | best-effort | UI may shorten for layout

## Doctor parity

| Item                            | App equivalent                          | CLI surface (`ph doctor`)        | Must match |
|---------------------------------|------------------------------------------|----------------------------------|------------|
| Exports directory present       | Bridge `ensureDirectories()` runs        | `exports_root_missing` finding   | yes        |
| Install root override valid     | Settings UI / env var indication         | `install_root_missing` finding   | yes        |
| Project root resolution         | Project picker selection                 | `project_root_missing` / `project_root_not_directory` | yes |
| Per-agent skill folder reachable| Audit Console visibility column          | `agent_paths_missing` / `agent_*_unwritable` | yes  |

## Allowed differences

These are intentional and **do not** count as parity regressions:

1. **Latency after export writes** — the app may not have flushed sync to disk
   when the CLI is invoked from a separate process. Users running `ph` from a
   shell immediately after editing a prompt may see the previous version until
   the next `syncAll()` runs (currently on app launch and explicit sync).
2. **UI-only presentation fields** — icons, badge colors, ordering, and
   shortened descriptions in the app dashboard do not have a CLI equivalent and
   are not part of the parity contract.
3. **Symlink-resolved paths** — `installedPaths` may contain both `/var/...` and
   `/private/var/...` for the same on-disk file because the underlying file
   resolution returns both forms on macOS. CLI tooling that joins on path
   should normalize through `URL.standardizedFileURL` first.

## Regression coverage

The two halves of the bridge are pinned by **paired** tests that meet in the
middle on a byte-identical on-disk format. Both halves run on every
`tools/buildcheck/validate.sh` invocation.

- **App side**: [prompthubTests/CLIParityTests.swift](../prompthubTests/CLIParityTests.swift) exports prompts and skills via the real `PromptHubBridge` into a temp directory and asserts the on-disk format contains every field the CLI's decoder needs.
- **CLI side**: [PromptHubCLI/Tests/PromptHubCLITests/PromptHubCLITests.swift](../PromptHubCLI/Tests/PromptHubCLITests/PromptHubCLITests.swift) (`cliParsesBridgeFixtureFormat`) reads a fixture that is byte-identical to the bridge's output and asserts the resulting `PromptHubExportedAsset` carries every contractual field.
- **App-side skill install**: [prompthubTests/SkillCLIServiceTests.swift](../prompthubTests/SkillCLIServiceTests.swift) covers the in-app install path so it stays in lockstep with what the CLI installs into the same agent directories. The suite is hermetic — it injects a `CLIDirectoryAccessManager(directoryBaseOverride:)` and an isolated `SkillProjectSelectionStore` so discovery/install never touch the developer's real `~/.agents`, `~/.codex`, etc., and it runs `@Suite(.serialized)` because the `MockURLProtocol` handler is process-global.
- **CLI lifecycle smoke**: [PromptHubCLI/Tests/Smoke/skill-lifecycle.sh](../PromptHubCLI/Tests/Smoke/skill-lifecycle.sh) and siblings forge the exact same on-disk format manually and run the real release `ph` binary against it end-to-end.

### Why there is no automated app-launch → `ph` cross-process test

The PromptHub macOS app runs under full
`com.apple.security.app-sandbox`. Test bundles built into that app
inherit the sandbox, which blocks `xcrun` / arbitrary subprocess
execution from a test process. That makes a true "boot the app, then
fork the `ph` binary against the same `~/.prompthub/`" test
impossible to wire into `validate.sh` without entitlements changes
that would weaken the shipping app's security posture.

The contract is instead protected by two byte-equivalent fixtures:
`CLIParityTests` proves the live bridge writes the documented bytes,
and `cliParsesBridgeFixtureFormat` plus the shell smoke scripts prove
the CLI reads exactly those bytes. A divergence in either side fails
`validate.sh`. The manual release checklist below is the residual
spot-check for the once-per-release "did the real bits travel through
two real processes" question.

## Release checklist

Before tagging a `ph-vX.Y.Z` release, run the following on a seeded workspace and
confirm parity:

1. Build the app, sync once, and note the count of prompts and skills shown in
   the CLI Dashboard ("Exports" section).
2. From a shell, run `ph prompt list --json | jq length` and
   `ph skill exports --json | jq length`. Both numbers MUST match the dashboard.
3. Install one exported skill via the app, then run
   `ph skill list --scope all --json | jq -r '.[].package'` and confirm the
   installed package appears.
4. Run `ph doctor --json | jq '.findings | map(.code)'` and confirm no
   `error`-severity findings.
5. Run `swift test --package-path PromptHubCLI` and the xcodebuild
   `prompthubTests/CLIParityTests` suite; both must pass.
