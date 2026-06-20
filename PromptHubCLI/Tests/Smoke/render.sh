#!/bin/zsh
# End-to-end smoke test for `ph prompt render` against an exported prompt fixture.
#
# Builds the release `ph` binary, sets up a temporary PROMPTHUB_HOME with a single
# exported prompt that declares two `{{variables}}`, then verifies:
#   * `ph prompt list` finds the fixture
#   * `ph prompt search` matches by tag substring
#   * `ph prompt render --var ...` substitutes both variables
#   * `ph prompt render --json` emits a parseable, stable JSON shape
#   * missing variables exit non-zero with an actionable stderr message

set -euo pipefail

cd "$(dirname "$0")/../../.."

ph_bin_dir=$(swift build --package-path PromptHubCLI -c release --product ph --show-bin-path)
ph="$ph_bin_dir/ph"
swift build --package-path PromptHubCLI -c release --product ph >/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export PROMPTHUB_HOME="$tmp"

prompts_dir="$tmp/.prompthub/prompts"
mkdir -p "$prompts_dir"

cat >"$prompts_dir/E5555555-5555-5555-5555-555555555555.md" <<'MARKDOWN'
---
id: E5555555-5555-5555-5555-555555555555
name: Smoke Greeting
slug: smoke-greeting
description: Smoke test fixture
tags:
  - smoke
  - cli
---

Hello {{name}}, welcome to {{place}}.
MARKDOWN

echo "==> ph prompt list"
"$ph" prompt list | grep -q "Smoke Greeting" || { echo "fail: list"; exit 1; }

echo "==> ph prompt search smoke"
"$ph" prompt search smoke | grep -q "smoke-greeting" || { echo "fail: search"; exit 1; }

echo "==> ph prompt render --var ..."
rendered=$("$ph" prompt render smoke-greeting --var name=Ada --var place=PromptHub)
expected="Hello Ada, welcome to PromptHub."
if [[ "$rendered" != "$expected" ]]; then
  echo "fail: render mismatch"
  echo "  got:      $rendered"
  echo "  expected: $expected"
  exit 1
fi

echo "==> ph prompt render --json"
"$ph" prompt render smoke-greeting --json --var name=Ada --var place=PromptHub \
  | python3 -c "import json,sys; doc=json.load(sys.stdin); assert doc['rendered']=='Hello Ada, welcome to PromptHub.', doc; assert sorted(doc['declaredVariables'])==['name','place'], doc"

echo "==> ph prompt render with missing variable exits non-zero"
if "$ph" prompt render smoke-greeting --var name=Ada >/dev/null 2>"$tmp/err"; then
  echo "fail: expected non-zero exit for missing variable"
  exit 1
fi
if ! grep -q "place" "$tmp/err"; then
  echo "fail: stderr should mention missing variable 'place'"
  cat "$tmp/err"
  exit 1
fi

echo "OK"
