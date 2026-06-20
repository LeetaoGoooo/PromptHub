#!/bin/zsh
# Acceptance entry point: runs every shell-level smoke script that
# `docs/cli-acceptance-matrix.md` lists, in a deterministic order, against
# a single freshly-built release `ph` binary.
#
# Each smoke script is self-contained — it sets its own PROMPTHUB_HOME and
# tears it down on EXIT — so they can run sequentially without leaking
# state into each other or into the host environment.
#
# Exit codes:
#   0   every smoke script exited 0
#   1   any smoke script failed (the failing script's stderr is preserved)
#
# Used by:
#   * .github/workflows/prompthub-cli-ci.yml
#   * .github/workflows/prompthub-cli-release.yml
#   * `tools/buildcheck/validate.sh`-equivalent local runs

set -euo pipefail
cd "$(dirname "$0")/../../.."

echo "==> building release ph binary once"
swift build --package-path PromptHubCLI -c release --product ph >/dev/null

scripts=(
  "PromptHubCLI/Tests/Smoke/render.sh"
  "PromptHubCLI/Tests/Smoke/prompt-write.sh"
  "PromptHubCLI/Tests/Smoke/skill-lifecycle.sh"
  "PromptHubCLI/Tests/Smoke/exit-codes.sh"
)

for script in "${scripts[@]}"; do
  echo ""
  echo "==> running $script"
  if ! bash "$script"; then
    echo "FAIL: $script" >&2
    exit 1
  fi
done

echo ""
echo "OK: all smoke scripts passed"
