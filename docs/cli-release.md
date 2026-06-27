# PromptHub CLI Release & Install

This document is the authoritative reference for how `ph` is published and
how end users install it. It is the install-side counterpart to
[`docs/cli-contract.md`](cli-contract.md) and
[`docs/cli-writable-contract.md`](cli-writable-contract.md).

## When to use the app vs `ph`

`ph` is the scripting and automation surface for PromptHub. The macOS
app remains the primary authoring surface. They share state through
`~/.prompthub/` and the agent skill directories.

- Use the **app** to author and edit prompts and multi-file skills,
  grant agent folder access, run live previews, and browse the skill
  store with a UI.
- Use **`ph`** to install / inspect skills from a terminal or CI, pipe
  JSON output into other tools, search the remote skill catalog from
  the shell, and run `ph doctor` when something looks off.

The CLI is intentionally narrower than the app: it covers everything
that benefits from being scriptable, but anything that benefits from a
window stays in the app.

## Supported platforms (v1)

| Target            | Status                                  |
|-------------------|------------------------------------------|
| macOS 14+, Apple Silicon (arm64) | **Supported** (primary)       |
| macOS Intel (x86_64)             | **Not supported in v1.**      |
| Linux                            | Not planned.                  |

v1 ships only an Apple Silicon binary archive because the macOS app's
toolchain and code-signing story is exclusively `arm64` on `macos-14`
runners. Intel macOS users can still install `ph` by building from source
through the `--HEAD` Homebrew path described below, which compiles
locally with the user's Swift toolchain.

## Public install commands

### Stable Homebrew (recommended after a tagged release exists)

```bash
brew tap leetaogoooo/prompthub https://github.com/LeetaoGoooo/PromptHub.git
brew install leetaogoooo/prompthub/ph
ph --help
```

This pulls the prebuilt `ph-macos-arm64.tar.gz` from the GitHub release
matching [`Formula/ph.rb`](../Formula/ph.rb)'s `STABLE_VERSION`.

### HEAD Homebrew (always available; builds from source)

```bash
brew tap leetaogoooo/prompthub https://github.com/LeetaoGoooo/PromptHub.git
brew install --HEAD leetaogoooo/prompthub/ph
ph --help
```

`--HEAD` clones the main branch and runs the same
`swift build … --product ph` invocation the release workflow uses.

### Direct binary download

```bash
VERSION=0.1.0
curl -L -o ph.tar.gz \
  "https://github.com/LeetaoGoooo/PromptHub/releases/download/ph-v$VERSION/ph-macos-arm64.tar.gz"
shasum -a 256 -c <(curl -sL \
  "https://github.com/LeetaoGoooo/PromptHub/releases/download/ph-v$VERSION/ph-macos-arm64.sha256" \
  | awk '{print $1"  ph.tar.gz"}')
tar -xzf ph.tar.gz
install -m 755 ph ~/.local/bin/ph
```

## Release artifacts

A tagged release pushes:

| Asset                         | Purpose                                      |
|-------------------------------|----------------------------------------------|
| `ph-macos-arm64.tar.gz`       | Single-file archive of the release binary.   |
| `ph-macos-arm64.sha256`       | One-line SHA256 of the archive (for Brew/curl checks). |

Tags must follow the format `ph-vX.Y.Z`. The workflow at
[`.github/workflows/prompthub-cli-release.yml`](../.github/workflows/prompthub-cli-release.yml)
derives the version from the tag, runs the CLI test suite, builds the
archive, smokes the formula against the local archive using the
`HOMEBREW_PROMPTHUB_BOTTLE_*` env overrides, and then publishes the
release.

## Cutting a new release

1. Land everything you want shipped on `main` and ensure
   `tools/buildcheck/validate.sh` is green.
2. Decide the next version (semver against the previously-tagged
   `ph-vX.Y.Z`).
3. Push the tag:

   ```bash
   git tag ph-v0.1.0
   git push origin ph-v0.1.0
   ```

4. Wait for the release workflow to finish. It will:
   - run `swift test --package-path PromptHubCLI`,
   - build and package `ph-macos-arm64.tar.gz` + `.sha256`,
   - install the formula via a throwaway tap using the local archive,
   - publish the GitHub release with auto-generated notes.
5. Note the published `ph-macos-arm64.sha256` value.
6. Open a follow-up PR that updates `Formula/ph.rb`:
   - bump `STABLE_VERSION` to the just-released version,
   - replace `STABLE_ARM64_SHA` with the published SHA256,
   - bump `PromptHubCLIVersion` in
     [`PromptHubCLISchema.swift`](../PromptHubCLI/Sources/PromptHubCLILib/PromptHubCLISchema.swift)
     to the same value so `ph --version` matches the release. The
     `cliVersionMatchesFormulaStableVersion` test fails if these drift.
7. After the bump merges, run
   [`tools/homebrew/verify-formula.sh`](../tools/homebrew/verify-formula.sh)
   locally (or in a follow-up CI run) to confirm a clean install path.

> The formula falls back to `head` and an env-var override so that the
> stable URL/SHA can intentionally lag the release by one PR without
> blocking the release pipeline or HEAD users.

## Local validation

Run a full local rehearsal of the public Homebrew install path:

```bash
tools/homebrew/verify-formula.sh
```

The script:

1. Builds the release `ph` binary.
2. Archives it identically to the release workflow.
3. Creates a throwaway local tap and installs `Formula/ph.rb` through the
   `HOMEBREW_PROMPTHUB_BOTTLE_*` override.
4. Asserts `ph --help` runs from the brew prefix and runs `brew test`.
5. Tears down the tap and uninstalls.

Exit code 0 means the formula installs cleanly from a fresh tap.

## Override env vars

| Env var                              | Purpose                                          |
|--------------------------------------|--------------------------------------------------|
| `HOMEBREW_PROMPTHUB_BOTTLE_URL`      | Override the prebuilt archive URL. Used by CI and `tools/homebrew/verify-formula.sh`. |
| `HOMEBREW_PROMPTHUB_BOTTLE_SHA256`   | SHA256 of the override archive. Required when `_URL` is set. |
| `HOMEBREW_PROMPTHUB_BOTTLE_VERSION`  | Optional `version` string for the override install. Defaults to `STABLE_VERSION-local`. |

These exist so the release workflow can verify the install path against
the artifact it is about to publish, before publishing it.

## Known platform limitations

- The release runner is GitHub-hosted `macos-14`. macOS 13 and earlier
  are not part of the support matrix.
- The archive is unsigned and unnotarized. macOS may require
  `xattr -dr com.apple.quarantine ph` on first run for direct downloads.
  Homebrew installs are not affected because Homebrew strips quarantine
  on its own pours.
- Intel macOS is intentionally out of scope for v1. The `--HEAD` path
  works on Intel because it builds locally, but no prebuilt Intel
  archive is published.
