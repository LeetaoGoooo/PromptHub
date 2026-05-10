# PromptHub CLI

**PromptHub CLI** is the agent/script interface to your [PromptHub](https://github.com/LeetaoGoooo/PromptHub) library. It lets AI agents, scripts, and CI pipelines read prompts and skills managed by the macOS app — without opening the UI.

```
┌─────────────────────────────────────────────────────────────────┐
│  GUI (macOS app)       │  CLI (this package)                    │
│  ─────────────────     │  ─────────────────                     │
│  Create / edit /       │  Read / render / audit /               │
│  delete prompts &      │  pipe to agents, scripts, CI           │
│  skills                │                                        │
│  Audit / compare /     │  prompthub prompt list                 │
│  review outputs        │  prompthub skill read <name>           │
└─────────────────────────────────────────────────────────────────┘
                          ↕  shared via ~/.prompthub/
```

## Installation

### Homebrew (recommended)

```sh
brew tap LeetaoGoooo/tap
brew install LeetaoGoooo/tap/prompthub
```

### curl

```sh
curl -fsSL https://raw.githubusercontent.com/LeetaoGoooo/PromptHub/main/install.sh | sh
```

### Build from source

```sh
git clone https://github.com/LeetaoGoooo/PromptHub.git
cd PromptHub/PromptHubCLI
swift build --configuration release
cp .build/release/prompthub /usr/local/bin/
```

## Quick Start

```sh
# Verify the environment
prompthub agent doctor

# List all prompts
prompthub prompt list

# Get a prompt by name or slug
prompthub prompt get code-review

# Render a prompt template, substituting variables
prompthub prompt render launch-copy --var product=MyApp --var audience=developers

# List skills
prompthub skill list

# Read a skill's full instructions
prompthub skill read product-manager

# Check if a skill is accessible to agents
prompthub skill visible product-manager

# Static quality audit of a skill
prompthub skill audit product-manager

# Full environment health check
prompthub agent doctor --json
```

## Asset Bridge

The PromptHub macOS app writes assets to `~/.prompthub/` on every save:

```
~/.prompthub/
  prompts/
    <uuid>.md   ← YAML front-matter + prompt body
  skills/
    <uuid>.md   ← YAML front-matter + SKILL.md instructions
```

The CLI reads directly from these files. No running app, no network, no database.

## Requirements

- macOS 14 (Sonoma) or later
- PromptHub.app (to populate the asset library)

## License

MIT — see [LICENSE](../LICENSE).
