# PromptHub CLI

PromptHub CLI is the standalone command-line companion for the PromptHub macOS app.

It supports two real workflows:

- Read prompts and skills exported by the app into `~/.prompthub/`
- Install and inspect skills for supported CLI agents through `PromptHubSkillKit`

## App vs `ph` CLI — when to use which

The macOS app and `ph` share the same on-disk surface
(`~/.prompthub/` for exports, the agent skill directories for installs)
but are intentionally narrower than each other:

| Use the **app** when…                                  | Use **`ph`** when…                                                  |
|--------------------------------------------------------|----------------------------------------------------------------------|
| Authoring or editing prompts and multi-file skills     | Scripting, automating, or running from CI / a headless shell        |
| Granting agent folder access (sandbox prompts)         | Installing / uninstalling skills from a terminal or workflow         |
| Live-testing prompts across models with previews       | Reading exported prompts / skills as JSON to pipe into other tools  |
| Browsing the skill store with a UI                     | Searching the remote skill catalog from the shell (`ph skill search`) |
| Anything that benefits from a window                   | Anything that benefits from a pipe                                   |

Both surfaces operate on the same canonical state. SwiftData inside the
app is the source of truth for prompt content; `~/.prompthub/` is the
bidirectional interchange surface the CLI reads and writes. See
[docs/cli-writable-contract.md](../docs/cli-writable-contract.md) for
the writable boundaries.

## Local Build

```bash
swift test --package-path PromptHubCLI
swift build --package-path PromptHubCLI -c release --product ph
./PromptHubCLI/.build/release/ph --help
```

## Install Paths

`ph` v1 ships an Apple Silicon (`arm64`) binary on macOS 14+. Intel macOS
users can install via the `--HEAD` (source-build) path. The full release
and platform-support story lives in [docs/cli-release.md](../docs/cli-release.md).

### Homebrew (stable)

Once a `ph-vX.Y.Z` release has been published and `Formula/ph.rb` bumped:

```bash
brew tap dosomeforfun/prompthub https://github.com/DoSomeForFun/PromptHub.git
brew install dosomeforfun/prompthub/ph
ph --help
```

### Homebrew (`--HEAD`, builds from source)

Always available, including on Intel macOS:

```bash
brew tap dosomeforfun/prompthub https://github.com/DoSomeForFun/PromptHub.git
brew install --HEAD dosomeforfun/prompthub/ph
ph --help
```

### Direct binary download

```bash
VERSION=0.1.0
curl -L -o ph.tar.gz \
  "https://github.com/DoSomeForFun/PromptHub/releases/download/ph-v$VERSION/ph-macos-arm64.tar.gz"
tar -xzf ph.tar.gz
install -m 755 ph ~/.local/bin/ph
```

### Build from source (clone)

```bash
git clone https://github.com/DoSomeForFun/PromptHub.git
cd PromptHub
swift build --package-path PromptHubCLI -c release --product ph
install -m 755 "$(swift build --package-path PromptHubCLI -c release --product ph --show-bin-path)/ph" ~/.local/bin/ph
```

## Commands

### Prompts

```bash
ph prompt list                                            # list every exported prompt
ph prompt list --json                                     # machine-readable list

ph prompt show landing-page-review                        # print the prompt body
ph prompt show landing-page-review --json                 # full asset metadata + body

ph prompt search hero                                     # case-insensitive substring over
                                                          # name, slug, installation name, id,
                                                          # tags, description, and body

ph prompt render landing-page-review \                    # substitute {{variables}}
  --var brand=Acme --var audience=designers
ph prompt render landing-page-review --json \             # rendered text + resolved vars
  --var brand=Acme --var audience=designers
diff -u /etc/hosts - | ph prompt render review \          # pipe stdin into a named variable
  --var-stdin diff
```

#### Identifier resolution precedence

All read commands resolve the identifier in this order:

1. Exact match (case-insensitive) on `id`, `slug`, installation name, or display name.
2. Prefix match on `id`, `slug`, or installation name.

If multiple prompts match at the same level the command exits with a non-zero status
and lists every candidate on stderr. Missing prompts and missing required render
variables also exit non-zero with actionable stderr messages, so shell scripts can
branch on `$?`.

#### Render variable syntax

Prompts use `{{name}}` placeholders (whitespace inside the braces is tolerated).
Provide values via repeated `--var name=value` flags, or pipe the entire standard
input into a single variable with `--var-stdin name`. Every declared placeholder
must be supplied or `render` fails with `missingPromptVariables`.

#### Write commands

```bash
ph prompt create --name "Launch Brief" --body "@launch.md"   # from a file
ph prompt create --name "Inline" --body "Hello there."        # from a literal
echo "Hello {{name}}." | ph prompt create --name "Greeting" --body-stdin
ph prompt create --name "Pinned" --id 11111111-2222-3333-4444-555555555555

ph prompt update launch-brief --description "Q3 wave"        # mutate metadata
ph prompt update launch-brief --name "Launch Brief Q3"       # rename + regenerate slug
ph prompt update launch-brief --body "@launch.md"            # replace body from a file

ph prompt delete launch-brief --yes                          # remove (TTY requires --yes)
```

Write commands operate on `~/.prompthub/prompts/<uuid>.md` and emit a one-line
app-resync hint to **stderr** on success so scripts and humans both know the
running PromptHub app needs to re-import. Identifier resolution on `update` /
`delete` follows the same precedence as the read commands; ambiguous matches
abort before any file is touched. Slug is derived from `--name` via the same
rule the app uses, so a CLI-written prompt is byte-equivalent to one the app
would export. The full source-of-truth and conflict story is in
[docs/cli-writable-contract.md](../docs/cli-writable-contract.md).

### Skills

```bash
ph skill exports                                          # list exported skill packages
ph skill exports --json

ph skill search review                                    # discover remote skills by keyword
ph skill search                                           # default ordered listing (most-installed first)
ph skill search review --json                             # JSON; .package is install-ready

ph skill show ui-reviewer                                 # print exported skill metadata + body
ph skill show ui-reviewer --json                          # full asset incl. package path + markdown

ph skill list                                             # discovered installed skills
ph skill list --scope global --json
ph skill list --scope project --project-root ./

ph skill inspect repo-review                              # detail for one installed package
ph skill inspect repo-review --scope global               # disambiguate when installed in both
ph skill inspect repo-review --json                       # array of every scope's record

ph skill install owner/repo@skill-name                    # remote install
ph skill install ui-reviewer --agent codex --scope global # install an exported skill locally

ph skill uninstall ui-reviewer --scope global             # remove a PromptHub-managed install
ph skill uninstall hand-authored --force                  # also remove unmanaged files (refuses without --force)
ph skill update owner/repo@skill-name                     # pull latest remote content + apply
ph skill reinstall ui-reviewer                            # re-run the original install
ph skill where ui-reviewer                                # one (agent, scope, path) row per location
ph skill where ui-reviewer --json
```

#### Remote discovery

`ph skill search <query>` queries the same registry the PromptHub app uses
(PromptHub registry → curated crawler snapshot → live GitHub crawl of seed
repos as fallback). Each row's `package` is already in `owner/repo@skill`
shape so you can pipe directly into install:

```bash
ph skill search code-review --json \
  | jq -r '.[0].package' \
  | xargs -I PKG ph skill install PKG
```

`isInstalled: true` marks results that are already installed locally so you
can hide them from selection menus. When the remote catalog is unreachable
the command exits non-zero with an actionable stderr message that explicitly
points users at `ph skill exports` and `ph skill list --scope all` as the
local fallbacks that keep working offline. Set `PROMPTHUB_GITHUB_TOKEN` for
authenticated GitHub access if you hit rate limits.

#### Lifecycle commands

- `uninstall <package>` removes a PromptHub-managed install. To prevent accidental
  deletion of hand-authored skill files, it refuses to touch files that were not
  installed by PromptHub. Pass `--force` to delete them anyway. Per-agent results
  are reported individually so a partial failure does not silently hide successes.
- `update <package>` pulls the latest remote content (for skills installed from an
  `owner/repo@skill` source) and applies it across every agent path. Reports
  `upToDate` / `updated` / `noRemoteSource` / `remoteUnavailable` / `notInstalled`
  so scripts can branch without parsing error strings.
- `reinstall <package>` re-runs the original install. Routes by package shape:
  `owner/repo@skill` triggers the remote install path; anything else resolves
  against an exported PromptHub asset by identifier. Fails with
  `noKnownInstallSource` when neither path is available.
- `where <package>` prints one tab-separated `<agent>\t<scope>\t<path>` row per
  install location, designed for piping into `awk`/`cut`/`cd`. Use `--json` for
  the full record including `isManagedByPromptHub`.

#### Inspect output

`ph skill inspect` returns an array of installed records (one per scope the package
is found in). Each record reports:

- `package` — installation name (matches `installationName` from `ph skill exports`)
- `scope` — `global` or `project`
- `agents` — sorted list of agent workflows that resolve this skill
- `isManagedByPromptHub` — distinguishes PromptHub-managed installs from
  pre-existing files already present in an agent directory
- `installedPaths` — resolved on-disk paths where the SKILL.md is visible
- `description`, `url` — metadata copied from the source SKILL.md

The same record shape is used by `ph skill list`, so external tooling can join
exported and installed JSON on `name` / `package`, `scope`, and `installedPaths`.
Missing exported skills, missing installed packages, and invalid remote
`owner/repo@skill` references all exit non-zero with actionable stderr.

### Doctor

`ph doctor` is a read-only diagnostic that explains why a list/show/install might
be failing. It checks every directory the CLI relies on, reports per-agent
visibility, and emits machine-readable findings with `--json`.

```bash
ph doctor                              # human-readable report
ph doctor --json                       # stable JSON for scripts
ph doctor --project-root ./some/repo   # use a specific project root
```

Doctor exits non-zero only when a finding has `error` severity (for example,
`project_root_missing` or `agent_*_unwritable`), so it can guard scripts:

```bash
ph doctor >/dev/null || { echo "ph environment is broken"; exit 1; }
```

#### Troubleshooting

| Finding code | What it means | Fix |
|--------------|---------------|-----|
| `exports_root_missing` | `~/.prompthub` does not exist | Open the PromptHub app and trigger a sync |
| `prompts_root_missing` / `skills_root_missing` | The export directory exists but is empty | Author or sync at least one prompt/skill |
| `install_root_missing` | `PROMPTHUB_INSTALL_ROOT` points to a directory that does not exist | Unset the env var or create the directory |
| `project_root_missing` | `--project-root` (or `PROMPTHUB_PROJECT_ROOT`) does not exist | Pass an existing directory or `cd` into the project before running |
| `no_agent_paths` | No supported agent (codex, claude-code, cursor, …) is installed | Install at least one CLI agent so `ph skill install` has a target |
| `agent_paths_missing` | One agent has neither global nor project skill directory | That agent will be skipped by install/list; ignorable if you don't use it |
| `agent_global_unwritable` / `agent_project_unwritable` | The skill directory exists but `ph` cannot write to it | Fix the directory permissions; this blocks `ph skill install` |

## Environment Variables

- `PROMPTHUB_HOME`: override the home directory used to resolve `~/.prompthub` and agent folders
- `PROMPTHUB_INSTALL_ROOT`: override PromptHub's managed skill registry root
- `PROMPTHUB_PROJECT_ROOT`: override the default project root for project-scoped operations
- `PROMPTHUB_GITHUB_TOKEN`: GitHub token for authenticated remote skill fetches

## Scripting Contract

The full scripting contract (stable JSON shapes, stdout/stderr policy, exit-code
categories, identifier precedence, and version policy) is documented in
[docs/cli-contract.md](../docs/cli-contract.md). It is the source of truth for
automation built on top of `ph`. Snapshot tests in
[`PromptHubCLI/Tests/PromptHubCLITests/CLIContractTests.swift`](Tests/PromptHubCLITests/CLIContractTests.swift)
fail if any documented JSON key or doctor finding code changes.
Shell-level coverage of exit codes for every documented failure category lives
in [`PromptHubCLI/Tests/Smoke/exit-codes.sh`](Tests/Smoke/exit-codes.sh).

Quick contract summary:

- `--json` output is the only content on stdout and uses sorted, camelCase keys.
- Optional string fields are omitted when nil; required keys always appear.
- Exit 0 on success and partial success; non-zero on failure; doctor warnings
  do not block.
- Identifier precedence is `id` → `slug` → `installationName` → `name`, exact
  match first then prefix (display name is never prefix-matched).

The contract version is exposed as
`PromptHubCLILib.PromptHubCLISchemaVersion` (currently `"1"`). The release
version of the binary is separate and printed by `ph --version`
(`PromptHubCLILib.PromptHubCLIVersion`); it tracks the Homebrew formula's
`STABLE_VERSION`.

## Writable Command Contract

The decision record for what `ph` is allowed to **write** in v1 — source
of truth, sync timing, conflict semantics, identifier strategy,
out-of-scope deferrals, and the required regression tests every
writable command must add — is documented in
[docs/cli-writable-contract.md](../docs/cli-writable-contract.md).
Implementation tasks for writable commands (starting with CLI-14
`ph prompt create/update/delete`) MUST link back to that contract
rather than re-deciding behavior in the command file.

Headline decisions you can rely on today:

- The `~/.prompthub/` directory tree is the bidirectional interchange
  surface between the app and the CLI. SwiftData inside the app remains
  the canonical store; the CLI mutates the export directory and the
  app reconciles on its next sync.
- Prompt write commands are in v1. Skill write commands are explicitly
  deferred to v2.
- CLI does not drive the running app. Writes are durable on disk
  immediately; the app picks them up on its next launch or explicit
  reload-from-disk.

## App ↔ CLI Parity

The `ph` CLI reads the same `~/.prompthub/` directory the PromptHub macOS app
writes. The fields that must agree between the two surfaces (and the
intentional differences) are documented in [docs/cli-parity.md](../docs/cli-parity.md).
A regression in that contract is enforced by two paired tests:

- `cliParsesBridgeFixtureFormat` in `PromptHubCLITests` reads a markdown fixture
  byte-equivalent to what `PromptHubBridge` writes.
- `CLIParityTests` in `prompthubTests` exercises `PromptHubBridge` and asserts
  the on-disk format carries every field the CLI's decoder depends on.

Both run under `tools/buildcheck/validate.sh`.

## Release Automation

- CI workflow: `.github/workflows/prompthub-cli-ci.yml`
- Release workflow: `.github/workflows/prompthub-cli-release.yml`
- Homebrew tap formula: `Formula/ph.rb`
- End-to-end release & install reference: [docs/cli-release.md](../docs/cli-release.md)
- Acceptance regression matrix: [docs/cli-acceptance-matrix.md](../docs/cli-acceptance-matrix.md)
- Local rehearsal of the public Homebrew install path:
  `tools/homebrew/verify-formula.sh`
- Run every shell smoke against the release binary:
  `PromptHubCLI/Tests/Smoke/run-all.sh`