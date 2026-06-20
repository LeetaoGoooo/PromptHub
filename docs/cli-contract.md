# PromptHub `ph` CLI — Scripting Contract (v1)

This document is the scripting contract for the `ph` CLI. Every behavior listed
here is **stable for the v1 schema**: shell scripts, CI jobs, and other tools
can rely on it without parsing English error strings.

The contract version is exposed as
`PromptHubCLILib.PromptHubCLISchemaVersion` ("1"). Future breaking changes
(field renames, removed fields, changed semantic types, exit-code remapping)
require bumping that version.

Snapshot tests in
[`PromptHubCLI/Tests/PromptHubCLITests/CLIContractTests.swift`](../PromptHubCLI/Tests/PromptHubCLITests/CLIContractTests.swift)
fail when a covered field or exit-code mapping regresses. Shell-level coverage
for failure modes lives in
[`PromptHubCLI/Tests/Smoke/exit-codes.sh`](../PromptHubCLI/Tests/Smoke/exit-codes.sh).

The companion **writable** contract — what `ph` is allowed to mutate, how
the app and CLI share `~/.prompthub/`, and which mutations are deferred
to v2 — lives in [`docs/cli-writable-contract.md`](cli-writable-contract.md).

## 1. stdout vs stderr

| Stream  | What goes here |
|---------|----------------|
| stdout  | Command output the caller asked for: tables, JSON, prompt bodies, render results, paths. Nothing else. |
| stderr  | Errors, warnings about malformed individual files (the command continues), and ArgumentParser usage messages. |

Concretely:

- `--json` output ALWAYS goes to stdout and is **the only thing** written to
  stdout for that invocation. Tools can pipe `ph … --json` into `jq` without
  filtering.
- Human-readable summaries go to stdout.
- A failed command MUST write a single actionable line to stderr starting with
  the error category (see §3) and a description. Example:
  `error: prompt 'foo' requires variables not provided: place. Supply them with --var name=value (or --var-stdin name).`
- Per-file parse warnings (e.g. one malformed exported prompt) go to stderr
  via `warning:` and the command continues with the remaining files. The exit
  code stays 0 because the request as a whole still produced output.

## 2. JSON shapes (stable in v1)

Every key listed below is part of the v1 contract. Encoder configuration:
`JSONEncoder` with `[.prettyPrinted, .sortedKeys]`. All keys are
**camelCase**. Optional `String` fields are **omitted when nil**
(`JSONEncoder` default for `Optional`). `Identifiable.id` computed
properties are NOT in JSON (Codable synthesis skips them).

### 2.1 `ph prompt list --json`, `ph prompt show --json`, `ph prompt search --json`

Array (list/search) or single object (show) of `PromptHubExportedAsset`:

```json
{
  "body": "Inspect the hero copy.",
  "category": "Design",
  "exportedAt": "2026-05-12T10:00:00Z",
  "id": "8C11E38A-6DDE-42F4-B7B8-94B5D11C0F4C",
  "installationName": null,
  "kind": "prompt",
  "markdown": "---\nid: 8C11E38A-…\n---\n\nInspect the hero copy.",
  "name": "Landing Page Review",
  "packageDirectoryPath": null,
  "path": "/Users/me/.prompthub/prompts/8C11E38A….md",
  "slug": "landing-page-review",
  "summary": "Review a launch page",
  "tags": []
}
```

Required keys (every prompt asset): `body`, `id`, `kind`, `markdown`,
`name`, `path`, `tags`.

Optional keys (present when value is non-nil): `category`, `exportedAt`,
`installationName`, `packageDirectoryPath`, `slug`, `summary`.

`kind` is the literal string `"prompt"`. `tags` is always an array
(possibly empty) of strings.

`ph prompt create --json` and `ph prompt update --json` emit the same
`PromptHubExportedAsset` shape so write callers can chain them through
`jq` exactly like the read commands. `ph prompt delete --json` emits a
two-key object `{"action": "deleted", "path": "/…/prompts/<uuid>.md"}`.
All three write commands additionally emit a one-line
`hint: the running PromptHub app will pick this change up on next launch …`
to **stderr** on success — never to stdout — so a successful write
is always identifiable from the exit code alone but the human nudge
remains visible interactively.

### 2.2 `ph prompt render --json`

Single `PromptHubRenderResult`:

```json
{
  "declaredVariables": ["name", "day"],
  "id": "C3333333-…",
  "name": "Greet",
  "path": "/Users/me/.prompthub/prompts/C3333….md",
  "rendered": "Hello Ada, today is Tuesday.",
  "slug": "greet",
  "variables": {"name": "Ada", "day": "Tuesday"}
}
```

Required keys: `declaredVariables`, `id`, `name`, `path`, `rendered`,
`variables`. Optional: `slug`. `variables` is a string→string map
containing only declared placeholders (extra `--var` assignments are
ignored). `declaredVariables` preserves declaration order.

### 2.3 `ph skill exports --json`, `ph skill show --json`

Same `PromptHubExportedAsset` shape as §2.1, with `kind` set to the
literal `"skill"`. Required keys are unchanged; `installationName` is
populated for skills and acts as the default install package name.

### 2.4 `ph skill list --json`, `ph skill inspect --json`

Array of `PromptHubInstalledSkillSummary`:

```json
{
  "agents": ["codex"],
  "description": "Review repository changes",
  "installedPaths": ["/Users/me/.codex/skills/repo-review"],
  "isManagedByPromptHub": true,
  "package": "repo-review",
  "scope": "global",
  "url": "https://github.com/owner/repo"
}
```

Required keys: `agents`, `description`, `installedPaths`,
`isManagedByPromptHub`, `package`, `scope`. Optional: `url`.

`scope` is the literal `"global"` or `"project"`. `agents` is sorted
alphabetically. `installedPaths` is sorted; macOS may emit both
`/var/…` and `/private/var/…` for the same file (see
[`docs/cli-parity.md`](cli-parity.md)).

### 2.5 `ph skill uninstall --json`

Single `PromptHubLifecycleResult`:

```json
{
  "agents": [
    {"agent": "codex", "error": null, "succeeded": true}
  ],
  "package": "ui-reviewer",
  "removedPaths": ["/Users/me/.codex/skills/ui-reviewer"],
  "scope": "global"
}
```

Required keys: `agents`, `package`, `removedPaths`, `scope`. Each
`agents` element has required `agent` and `succeeded`, optional `error`
(string, present when the per-agent action failed).

### 2.6 `ph skill update --json`

Single `PromptHubUpdateResult`:

```json
{
  "appliedPaths": [],
  "package": "ui-reviewer",
  "scope": "global",
  "status": "noRemoteSource"
}
```

Required keys: `appliedPaths`, `package`, `scope`, `status`. `status`
is one of: `"upToDate"`, `"updated"`, `"noRemoteSource"`,
`"remoteUnavailable"`, `"notInstalled"`.

### 2.7 `ph skill reinstall --json`

Single `PromptHubInstalledSkillSummary` (§2.4 shape).

### 2.7a `ph skill search --json`

Array of `PromptHubRemoteSkillSummary`:

```json
{
  "package": "octo/beta@review",
  "description": "Code Review • 4 installs",
  "isInstalled": false,
  "url": "https://github.com/octo/beta"
}
```

Required keys (every row): `package`, `description`, `isInstalled`.
Optional: `url` (omitted when nil). `package` is always in
`owner/repo@skill` form so it can be passed straight to
`ph skill install`. Most-installed-first ordering from the upstream
catalog is preserved.

When the remote catalog is unreachable the command exits non-zero
with category `environmental failure` (see §3) and a stderr message
that names the still-working local fallbacks (`ph skill exports`,
`ph skill list --scope all`).

### 2.8 `ph skill where --json`

Array of `PromptHubWhereLocation`:

```json
{
  "agent": "codex",
  "isManagedByPromptHub": true,
  "package": "ui-reviewer",
  "path": "/Users/me/.codex/skills/ui-reviewer",
  "scope": "global"
}
```

Required keys (every row): `agent`, `isManagedByPromptHub`, `package`,
`path`, `scope`. Default text output is one tab-separated
`<agent>\t<scope>\t<path>` per line.

### 2.9 `ph doctor --json`

Single `DoctorReport`:

```json
{
  "agents": [{
    "agent": "codex",
    "globalPath": {"exists": true, "isDirectory": true, "isReadable": true, "isWritable": true, "path": "…"},
    "projectPath": {"exists": false, "isDirectory": false, "isReadable": false, "isWritable": false, "path": "…"},
    "visibleSkillCount": 1
  }],
  "exportsRoot": {"…": "DoctorPathCheck"},
  "findings": [{
    "code": "healthy",
    "message": "PromptHub CLI environment looks healthy.",
    "path": null,
    "severity": "ok"
  }],
  "githubTokenPresent": false,
  "homeDirectory": {"…": "DoctorPathCheck"},
  "installRoot": null,
  "projectRoot": {"…": "DoctorPathCheck"},
  "promptsRoot": {"…": "DoctorPathCheck"},
  "skillsRoot": {"…": "DoctorPathCheck"}
}
```

Required keys: `agents`, `exportsRoot`, `findings`, `githubTokenPresent`,
`homeDirectory`, `projectRoot`, `promptsRoot`, `skillsRoot`. Optional:
`installRoot` (present only when `PROMPTHUB_INSTALL_ROOT` is set).

Each `findings` entry has `code`, `message`, `severity`; optional
`path`. `severity` is one of: `"ok"`, `"warning"`, `"error"`.
`finding.code` is a stable identifier; new finding codes may be added in
v1, existing codes will not be renamed or repurposed. The full list is
in [`PromptHubCLI/README.md` Troubleshooting](../PromptHubCLI/README.md#troubleshooting).

Each `DoctorPathCheck` always carries: `exists`, `isDirectory`,
`isReadable`, `isWritable`, `path`.

Each `DoctorAgentReport` always carries: `agent`, `globalPath`,
`projectPath`, `visibleSkillCount`.

## 3. Exit codes

The v1 contract differentiates by **category** not by numeric code. Today
every non-zero exit is `1`, which scripts MUST treat as "command failed,
read stderr for the category". Future minor versions may map categories
to distinct numeric codes; that change will only widen the contract
(zero stays zero, non-zero stays non-zero).

| Category                | Exit | When                                                              |
|-------------------------|------|-------------------------------------------------------------------|
| success                 | 0    | Command produced its requested output.                            |
| partial success         | 0    | Some agents succeeded, some failed (uninstall, update). Per-agent results carry the breakdown. |
| usage / argument error  | 2    | ArgumentParser-level failure (unknown flag, missing required arg). |
| not found               | ≠0   | `assetNotFound`, `installedSkillNotFound`, `noKnownInstallSource`. |
| ambiguous match         | ≠0   | `ambiguousAsset`.                                                 |
| invalid input           | ≠0   | `invalidMarkdown`, `invalidRemoteSkillReference`, `invalidVariableAssignment`, `missingPromptVariables`. |
| safety refusal          | ≠0   | `unmanagedSkill` without `--force`.                               |
| environmental failure   | ≠0   | `ph doctor` finding with `severity == error`. All agents failed during uninstall (`allFailed`). |

Doctor warnings (`severity == warning`) exit 0 by design so partially-set-up
users (e.g. only one agent installed) are not blocked from scripting.

## 4. Identifier precedence

Every read command (`ph prompt show/render/search`, `ph skill show`) and
every install reference (`ph skill install`, `ph skill reinstall`) resolve
identifiers with the same precedence:

1. **Exact match** (case-insensitive) on, in order:
   1. `id`
   2. `slug`
   3. `installationName`
   4. `name` (display name)
2. **Prefix match** (case-insensitive) on `id`, `slug`, or
   `installationName`. Display name is NOT prefix-matched to avoid
   surprising hits on long titles.

If multiple assets tie at the same level, the command fails with the
`ambiguous match` category and writes every candidate to stderr.

For `ph skill install <reference>`:

- If `<reference>` contains both `/` and `@`, it is parsed as
  `owner/repo@skill-name` and dispatched to the remote installer.
  An ill-formed remote reference fails with `invalid input`.
- Otherwise it is resolved as an exported PromptHub skill identifier
  using the rules above.

`ph skill list`, `ph skill inspect`, `ph skill where`, `ph skill update`,
and `ph skill uninstall` accept the installed **package** name
case-insensitively (matches the `package` field from §2.4).

## 5. Stable concrete examples

```bash
# Identifier resolution: exact slug wins over prefix on another field.
ph prompt show landing-page-review

# Render with declared variables; missing vars exit non-zero.
ph prompt render greet --var name=Ada --var day=Tuesday
echo $? # 0

ph prompt render greet --var name=Ada >/dev/null
echo $? # non-zero; stderr explains missing 'day'

# JSON for every command is the only thing on stdout.
ph prompt list --json | jq '.[].slug'
ph skill list --scope all --json | jq '.[] | {package, scope}'
ph doctor --json | jq '.findings[] | select(.severity == "error")'

# Safety refusal exits non-zero unless --force.
ph skill uninstall hand-authored && echo unreachable
ph skill uninstall hand-authored --force

# Doctor in CI: fail the job only on error severity, not warnings.
ph doctor --json >/dev/null || { echo "ph env broken"; exit 1; }
```

## 6. Versioning policy

- **Patch**: new optional JSON keys, new stdout-only human-readable
  formatting, new finding codes, additional supported agents.
- **Minor**: new commands, new flags, mapping non-zero categories to
  distinct numeric exit codes (zero stays zero).
- **Major (schema v2)**: removed or renamed JSON keys, changed
  semantic types, retired finding codes, changed identifier
  precedence. Schema major bumps land alongside a `--schema-version`
  selector so v1 callers can stay on v1.
