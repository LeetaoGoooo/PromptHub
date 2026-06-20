# PromptHub CLI Acceptance Matrix

This is the v1 acceptance layer for `ph`. It exists so that even when the
unit tests are green, we can still answer: *"does this CLI actually work
end to end as a releasable product?"*

The matrix has three tiers:

1. **Path tests** — shell smoke scripts that exercise a full
   trigger-to-outcome flow against the real release binary, with
   fixtures on disk and observable side effects (files written,
   processes exiting, JSON parsing).
2. **Contract tests** — Swift `Testing` cases in `PromptHubCLITests`
   that pin JSON shapes, exit-code rules, identifier precedence, and
   documentation parity.
3. **Release smoke** — Homebrew install rehearsal that runs both in CI
   (release workflow) and locally
   (`tools/homebrew/verify-formula.sh`).

Every release run blocks on tier 1 and tier 3. Tier 2 runs on every
`swift test` invocation.

## Where to find each tier

| Tier               | Entry point                                                              |
|--------------------|---------------------------------------------------------------------------|
| Path smoke         | [`PromptHubCLI/Tests/Smoke/run-all.sh`](../PromptHubCLI/Tests/Smoke/run-all.sh) |
| Contract tests     | `swift test --package-path PromptHubCLI`                                  |
| Full validation    | [`tools/buildcheck/validate.sh`](../tools/buildcheck/validate.sh)         |
| Release smoke      | [`.github/workflows/prompthub-cli-release.yml`](../.github/workflows/prompthub-cli-release.yml) + [`tools/homebrew/verify-formula.sh`](../tools/homebrew/verify-formula.sh) |
| Acceptance entry   | `PromptHubCLI/Tests/Smoke/run-all.sh` (used by both CI and release)       |

## Coverage matrix

Every `ph` subcommand documented in
[`docs/cli-contract.md`](cli-contract.md) and
[`docs/cli-writable-contract.md`](cli-writable-contract.md) MUST have at
least one row here. Adding a new command without extending this table is
caught by the regression test
`acceptanceMatrixCoversEveryShippedCommand` in
`PromptHubCLITests/AcceptanceMatrixTests.swift`.

### Prompt commands

| Trigger                                          | Fixture                                    | Expected outcome                                                                | Smoke script                                |
|--------------------------------------------------|--------------------------------------------|---------------------------------------------------------------------------------|---------------------------------------------|
| `ph prompt list` / `ph prompt list --json`       | Two exported prompts under `~/.prompthub/prompts` | Stdout-only JSON, exit 0, 2-element array, no stderr                            | `Smoke/exit-codes.sh`                       |
| `ph prompt show <id-or-slug>`                    | Exported prompt with body                  | Body printed to stdout, exit 0                                                  | `Smoke/render.sh`, `Smoke/prompt-write.sh` |
| `ph prompt show <missing>`                       | None                                        | Exit non-zero, stderr names the missing identifier                              | `Smoke/exit-codes.sh`                       |
| `ph prompt show <ambiguous-prefix>`              | Two prompts sharing prefix                  | Exit non-zero, stderr lists candidates                                          | `Smoke/exit-codes.sh`                       |
| `ph prompt search <query>`                       | Exported prompt with matching tag/body      | Stdout match, exit 0                                                            | `Smoke/render.sh`, `Smoke/prompt-write.sh` |
| `ph prompt render --var k=v` (full set)          | Prompt with two `{{variables}}`             | Substituted text on stdout, exit 0                                              | `Smoke/render.sh`                           |
| `ph prompt render --json`                        | Same                                        | Stable JSON shape (`rendered`, `declaredVariables`)                             | `Smoke/render.sh`                           |
| `ph prompt render --var name=...` (incomplete)   | Same                                        | Exit non-zero, stderr lists missing variable                                    | `Smoke/render.sh`, `Smoke/exit-codes.sh`   |
| `ph prompt render --var malformed`               | Same                                        | Exit non-zero, stderr says `Invalid --var`                                      | `Smoke/exit-codes.sh`                       |
| `ph prompt create --body-stdin --json`           | Empty `PROMPTHUB_HOME`                      | New file appears, JSON has stable `id`/`slug`, stderr carries app-resync hint   | `Smoke/prompt-write.sh`                     |
| `ph prompt create --body @file.md`               | Body file on disk                           | File contents land in stored body                                               | `Smoke/prompt-write.sh`                     |
| `ph prompt create --id <existing>`               | Existing prompt with that id                | Exit non-zero, stderr says "already in use"                                     | `Smoke/prompt-write.sh`                     |
| `ph prompt create --body @missing`               | Missing path                                | Exit non-zero, stderr says body file not found                                  | `Smoke/prompt-write.sh`                     |
| `ph prompt update --name <new>`                  | Existing prompt                             | Slug regenerated, id preserved                                                  | `Smoke/prompt-write.sh`                     |
| `ph prompt delete <id> --yes`                    | Existing prompt                             | File removed, subsequent `show` fails, stderr carries app-resync hint           | `Smoke/prompt-write.sh`                     |

### Skill commands

| Trigger                                                                | Fixture                                                            | Expected outcome                                                                                  | Smoke script                |
|------------------------------------------------------------------------|---------------------------------------------------------------------|---------------------------------------------------------------------------------------------------|-----------------------------|
| `ph skill exports --json`                                              | Package directory under `~/.prompthub/skills/<id>/`                 | 1-element array, `kind:"skill"`, `installationName` matches slug                                  | `Smoke/skill-lifecycle.sh`  |
| `ph skill show <slug> --json`                                          | Same                                                                | `name`, `installationName`, `packageDirectoryPath` populated                                      | `Smoke/skill-lifecycle.sh`  |
| `ph skill install <slug> --agent codex --scope global`                 | Same                                                                | `SKILL.md` and sibling package files copied into `~/.codex/skills/<slug>/`; JSON summary returned | `Smoke/skill-lifecycle.sh`  |
| `ph skill list --json`                                                 | After install                                                       | Installed entry visible with correct scope and agent                                              | `Smoke/skill-lifecycle.sh`  |
| `ph skill inspect <pkg> --json`                                        | After install                                                       | Record carries `isManagedByPromptHub: true` and non-empty `installedPaths`                        | `Smoke/skill-lifecycle.sh`  |
| `ph skill where <pkg>`                                                 | After install                                                       | Stdout contains the agent path                                                                    | `Smoke/skill-lifecycle.sh`  |
| `ph skill update <pkg>`                                                | Local-only install (no remote source)                               | Exit non-zero, stderr explains the missing remote (unit test: `updateSkillReportsNoRemoteSourceForLocalInstall`) | contract test               |
| `ph skill reinstall <pkg>`                                             | Exported package                                                    | Re-runs install path (unit test: `reinstallFromExportedAssetRoundTrips`)                          | contract test               |
| `ph skill uninstall <pkg> --scope global`                              | PromptHub-managed install                                           | Files removed; subsequent `ph skill list` no longer reports it                                    | `Smoke/skill-lifecycle.sh`  |
| `ph skill uninstall <pkg>` against unmanaged file (no `--force`)       | Hand-authored `SKILL.md` under `~/.codex/skills/<pkg>`              | Exit non-zero, stderr mentions `--force`, files left in place                                     | `Smoke/exit-codes.sh`       |
| `ph skill search <query>`                                              | Remote catalog stub                                                 | JSON shape stability covered by `RemoteSearchTests` (HTTP stubbed)                                | contract test               |

### Diagnostics

| Trigger                                          | Fixture                                                                 | Expected outcome                                                       | Smoke script        |
|--------------------------------------------------|--------------------------------------------------------------------------|------------------------------------------------------------------------|---------------------|
| `ph doctor --json` (warnings only)               | Empty PROMPTHUB_HOME, missing exports root, project root present         | Exit 0; JSON `findings` includes `exports_root_missing` at `warning` severity | `Smoke/exit-codes.sh` |
| `ph doctor --json` (error severity)              | Same, but `--project-root` points at a missing path                      | Exit non-zero                                                          | `Smoke/exit-codes.sh` |

### Install / release path

| Trigger                                                                | Fixture                                                                 | Expected outcome                                                                 | Driver                                                       |
|------------------------------------------------------------------------|--------------------------------------------------------------------------|----------------------------------------------------------------------------------|---------------------------------------------------------------|
| Tagged release `ph-vX.Y.Z` lands on `main`                              | GitHub Actions runner (`macos-14`, arm64)                                | Workflow builds, packages `ph-macos-arm64.tar.gz` + `.sha256`                    | `.github/workflows/prompthub-cli-release.yml`                |
| Release-time formula smoke                                              | Locally-built archive, env override pointed at it                        | `brew install` + `brew test` succeed against `Formula/ph.rb` in throwaway tap     | Same workflow                                                |
| Local "act like a user" install rehearsal                               | Developer machine with brew + Xcode                                      | `tools/homebrew/verify-formula.sh` installs `ph` and runs `ph --help`            | [`tools/homebrew/verify-formula.sh`](../tools/homebrew/verify-formula.sh) |

## Documented invariants the matrix protects

These are the cross-cutting promises that any failing row would catch:

- **JSON contract**: every JSON-emitting command returns the keys listed
  in [`docs/cli-contract.md`](cli-contract.md), with camelCase keys,
  prettyPrinted + sortedKeys formatting, and optional-nil keys omitted.
- **Exit-code contract**: success and partial success exit 0; failure
  exits non-zero; `doctor` only exits non-zero on error severity.
- **Identifier resolution**: exact match wins; ambiguous prefixes error
  out with a candidate list on stderr.
- **Stderr vs stdout**: JSON only on stdout; human-readable warnings,
  errors, and the app-resync hint only on stderr.
- **Bridge parity**: anything written via `ph prompt create/update`
  must be readable by the live app (and vice versa). Enforced by
  `CLIParityTests` and `cliParsesBridgeFixtureFormat`.
- **Install path**: every public install path
  (Homebrew stable, Homebrew `--HEAD`, direct download, source build)
  produces a `ph` binary whose `ph --help` lists `prompt` and `skill`
  subcommands. Enforced by `Formula/ph.rb`'s `test do` block and the
  release-workflow smoke step.

## Extending the matrix

When you add a new `ph` subcommand:

1. Add at least one path-test row in the table above and wire it into
   the appropriate `PromptHubCLI/Tests/Smoke/*.sh` script (or add a new
   one and register it in `run-all.sh`).
2. Add a JSON-shape contract test in
   `PromptHubCLITests/CLIContractTests.swift`.
3. If the command surfaces a new error condition, extend
   `Smoke/exit-codes.sh` so the failure mode is observable from a shell.
4. Update `docs/cli-contract.md` (and `docs/cli-writable-contract.md`
   for write paths) so the matrix has a referenced contract to assert.

The regression test `acceptanceMatrixCoversEveryShippedCommand` keeps
this file in sync with the actual command surface; a forgotten command
fails CI before it can land.
