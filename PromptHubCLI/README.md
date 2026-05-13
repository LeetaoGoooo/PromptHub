# PromptHub CLI

PromptHub CLI is the standalone command-line companion for the PromptHub macOS app.

It supports two real workflows:

- Read prompts and skills exported by the app into `~/.prompthub/`
- Install and inspect skills for supported CLI agents through `PromptHubSkillKit`

## Local Build

```bash
swift test --package-path PromptHubCLI
swift build --package-path PromptHubCLI -c release --product ph
./PromptHubCLI/.build/release/ph --help
```

## Current Install Paths

Today, the guaranteed install path is from the public repository source:

```bash
git clone https://github.com/LeetaoGoooo/PromptHub.git
cd PromptHub
swift build --package-path PromptHubCLI -c release --product ph
install -m 755 "$(swift build --package-path PromptHubCLI -c release --product ph --show-bin-path)/ph" ~/.local/bin/ph
```

The guaranteed Homebrew path is the repository tap formula:

```bash
brew tap LeetaoGoooo/PromptHub https://github.com/LeetaoGoooo/PromptHub.git
brew install --HEAD LeetaoGoooo/PromptHub/ph
```

After the first tagged CLI release is pushed with the format `ph-vX.Y.Z`, GitHub Actions will publish:

- `ph-macos-arm64.tar.gz`
- `ph-macos-arm64.sha256`

The release artifacts are for direct binary download. Homebrew remains tap-based via `Formula/ph.rb` in the repository.

## Commands

```bash
ph prompt list
ph prompt show landing-page-review

ph skill exports
ph skill install owner/repo@skill-name
ph skill install ui-reviewer --agent codex --scope global
ph skill list --scope all
```

## Environment Variables

- `PROMPTHUB_HOME`: override the home directory used to resolve `~/.prompthub` and agent folders
- `PROMPTHUB_INSTALL_ROOT`: override PromptHub's managed skill registry root
- `PROMPTHUB_PROJECT_ROOT`: override the default project root for project-scoped operations
- `PROMPTHUB_GITHUB_TOKEN`: GitHub token for authenticated remote skill fetches

## Release Automation

- CI workflow: `.github/workflows/prompthub-cli-ci.yml`
- Release workflow: `.github/workflows/prompthub-cli-release.yml`
- Homebrew tap formula: `Formula/ph.rb`