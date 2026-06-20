#!/bin/zsh
# End-to-end shell assertions for the v1 scripting contract documented in
# docs/cli-contract.md §3 (exit codes) and §1 (stdout/stderr policy).
#
# Exercises representative failure modes against the release binary:
#   * success → exit 0, JSON to stdout only, no stderr noise
#   * not found → non-zero exit, actionable stderr message
#   * ambiguous match → non-zero exit, candidates on stderr
#   * invalid input (bad --var, missing render variable) → non-zero exit
#   * safety refusal (unmanaged uninstall without --force) → non-zero exit
#   * doctor warning on missing exports → exit 0 (warnings do not block)

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

# Two prompts whose slugs share the prefix "rev" so ambiguous-match exercises.
cat >"$prompts_dir/E0000001-0000-0000-0000-000000000001.md" <<'MARKDOWN'
---
id: E0000001-0000-0000-0000-000000000001
name: Review One
slug: review-one
---

Hello {{name}}, welcome to {{place}}.
MARKDOWN

cat >"$prompts_dir/E0000002-0000-0000-0000-000000000002.md" <<'MARKDOWN'
---
id: E0000002-0000-0000-0000-000000000002
name: Review Two
slug: review-two
---

Body two.
MARKDOWN

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# --- success: stdout-only JSON, no stderr ---------------------------------
echo "==> success: prompt list --json"
stdout_file="$tmp/list.json"
stderr_file="$tmp/list.err"
"$ph" prompt list --json >"$stdout_file" 2>"$stderr_file"
rc=$?
[[ $rc -eq 0 ]] || fail "list exit code should be 0, got $rc"
[[ -s "$stdout_file" ]] || fail "list stdout should not be empty"
[[ -s "$stderr_file" ]] && fail "list stderr should be empty: $(cat "$stderr_file")"
python3 -c "import json,sys; doc=json.load(open(sys.argv[1])); assert isinstance(doc, list) and len(doc)==2, doc" "$stdout_file" \
  || fail "list JSON should be a 2-element array"

# --- not found: non-zero exit, stderr has actionable message --------------
echo "==> not found: prompt show never-exported"
if "$ph" prompt show never-exported >/dev/null 2>"$tmp/notfound.err"; then
  fail "show should exit non-zero for missing prompt"
fi
grep -q "never-exported" "$tmp/notfound.err" || fail "stderr should mention the missing identifier"

# --- ambiguous match: non-zero exit, candidates on stderr -----------------
echo "==> ambiguous: prompt show rev"
if "$ph" prompt show rev >/dev/null 2>"$tmp/ambig.err"; then
  fail "ambiguous prefix should exit non-zero"
fi
grep -qi "matched" "$tmp/ambig.err" || fail "stderr should explain the ambiguous match"
grep -q "review-one" "$tmp/ambig.err" || fail "stderr should list candidate review-one"
grep -q "review-two" "$tmp/ambig.err" || fail "stderr should list candidate review-two"

# --- invalid input: bad --var assignment ----------------------------------
echo "==> invalid input: render --var without ="
if "$ph" prompt render review-one --var bad-format >/dev/null 2>"$tmp/badvar.err"; then
  fail "render should reject malformed --var"
fi
grep -q "Invalid --var" "$tmp/badvar.err" || fail "stderr should mention 'Invalid --var'"

# --- invalid input: missing required render variable ----------------------
echo "==> invalid input: render missing variable"
if "$ph" prompt render review-one --var name=Ada >/dev/null 2>"$tmp/missvar.err"; then
  fail "render with missing variable should exit non-zero"
fi
grep -q "place" "$tmp/missvar.err" || fail "stderr should list missing variable 'place'"

# --- safety refusal: uninstall hand-authored skill without --force --------
echo "==> safety refusal: uninstall unmanaged without --force"
mkdir -p "$tmp/.codex/skills/hand-authored"
cat >"$tmp/.codex/skills/hand-authored/SKILL.md" <<'SKILL'
---
description: hand-authored
---

body
SKILL
# Point ph at a CWD whose project root has no .agents/skills so the only
# discovered install is the unmanaged file in the codex global directory.
if HOME="$tmp" "$ph" skill uninstall hand-authored --scope global --project-root "$tmp" >/dev/null 2>"$tmp/refuse.err"; then
  fail "uninstall of unmanaged skill should refuse without --force"
fi
grep -q "force" "$tmp/refuse.err" || fail "stderr should mention --force"
# File must still be present.
[[ -f "$tmp/.codex/skills/hand-authored/SKILL.md" ]] || fail "unmanaged file should not be deleted on refusal"

# --- doctor warning-only environment exits 0 ------------------------------
echo "==> doctor warning-only exits 0"
warn_tmp=$(mktemp -d)
trap 'rm -rf "$tmp" "$warn_tmp"' EXIT
# warn_tmp has no .prompthub exports → warnings, but the path itself exists
# so no error-severity findings fire.
HOME="$warn_tmp" "$ph" doctor --home "$warn_tmp" --project-root "$warn_tmp" --json >"$warn_tmp/doctor.json" 2>"$warn_tmp/doctor.err"
rc=$?
[[ $rc -eq 0 ]] || fail "doctor with warnings only should exit 0, got $rc (stderr: $(cat "$warn_tmp/doctor.err"))"
python3 -c "
import json,sys
doc=json.load(open(sys.argv[1]))
codes=[f['code'] for f in doc['findings']]
assert 'exports_root_missing' in codes, codes
" "$warn_tmp/doctor.json" || fail "doctor JSON should include exports_root_missing warning"

# --- doctor error-severity exits non-zero ---------------------------------
echo "==> doctor error-severity exits non-zero"
missing_project="$warn_tmp/does-not-exist"
if "$ph" doctor --home "$warn_tmp" --project-root "$missing_project" --json >/dev/null 2>"$warn_tmp/doctor-err.err"; then
  fail "doctor should exit non-zero when project root is missing"
fi

echo "OK"
