#!/bin/zsh
# End-to-end shell scenario for `ph prompt create/update/delete` covering
# `docs/cli-writable-contract.md` §8 #1, #5, #7, #8, #9, #10. Verifies that:
#   * create → show → list → search → render round-trips
#   * stderr always carries the app-resync hint
#   * --id collision exits non-zero
#   * --body @file.md reads from disk
#   * --body-stdin reads from stdin
#   * update preserves id and regenerates slug on --name
#   * delete --yes removes the file and subsequent show fails

set -euo pipefail
cd "$(dirname "$0")/../../.."

ph_bin_dir=$(swift build --package-path PromptHubCLI -c release --product ph --show-bin-path)
ph="$ph_bin_dir/ph"
swift build --package-path PromptHubCLI -c release --product ph >/dev/null

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export PROMPTHUB_HOME="$tmp"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

# --- create with --body-stdin -----------------------------------------------
echo "==> create from stdin"
created_stderr="$tmp/created.err"
printf 'Hello {{name}}.' | "$ph" prompt create --name "Lifecycle Demo" --description "v1" --body-stdin --json \
  >"$tmp/created.json" 2>"$created_stderr"
grep -q "running PromptHub app will pick this change up" "$created_stderr" \
  || fail "create stderr should carry the app-resync hint"

created_id=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['id'])" "$tmp/created.json")
created_slug=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['slug'])" "$tmp/created.json")
[[ "$created_slug" == "lifecycle-demo" ]] || fail "expected slug lifecycle-demo, got $created_slug"

# --- show, list, search round-trip ------------------------------------------
echo "==> show round-trip"
"$ph" prompt show lifecycle-demo | grep -q "Hello {{name}}." \
  || fail "show should return the body we wrote"
"$ph" prompt list --json | python3 -c "
import json,sys
docs=json.load(sys.stdin)
assert len(docs)==1, docs
assert docs[0]['slug']=='lifecycle-demo', docs
" || fail "list should report exactly one prompt"

"$ph" prompt search Hello | grep -q "lifecycle-demo" \
  || fail "search should match the prompt body"

# --- render against CLI-written body ----------------------------------------
echo "==> render against CLI-written body"
rendered=$("$ph" prompt render lifecycle-demo --var name=Ada)
[[ "$rendered" == "Hello Ada." ]] || fail "render mismatch: $rendered"

# --- --body @file.md path ---------------------------------------------------
echo "==> create with --body @file.md"
body_file="$tmp/body.md"
printf 'Sourced from a file.' >"$body_file"
"$ph" prompt create --name "From File" --body "@$body_file" --json >"$tmp/file.json" 2>/dev/null
"$ph" prompt show from-file | grep -q "Sourced from a file." \
  || fail "expected file-sourced body"

# --- --id collision exits non-zero ------------------------------------------
echo "==> --id collision"
if "$ph" prompt create --name "Duplicate" --id "$created_id" --body "x" >/dev/null 2>"$tmp/collide.err"; then
  fail "duplicate --id should exit non-zero"
fi
grep -qi "already in use" "$tmp/collide.err" || fail "collision stderr missing"

# --- update --name regenerates slug, preserves id ---------------------------
echo "==> update --name regenerates slug"
update_out=$("$ph" prompt update lifecycle-demo --name "Renamed Thing" --json 2>>/dev/null)
new_slug=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['slug'])" "$update_out")
new_id=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['id'])" "$update_out")
[[ "$new_slug" == "renamed-thing" ]] || fail "expected slug renamed-thing, got $new_slug"
[[ "$new_id" == "$created_id" ]] || fail "id must be preserved on rename"

# --- delete --yes removes file ----------------------------------------------
echo "==> delete --yes"
"$ph" prompt delete renamed-thing --yes >/dev/null 2>"$tmp/delete.err"
grep -q "running PromptHub app will pick" "$tmp/delete.err" \
  || fail "delete stderr should carry app-resync hint"

if "$ph" prompt show renamed-thing >/dev/null 2>"$tmp/post-delete.err"; then
  fail "show should fail after delete"
fi

# --- body-source not found exits non-zero -----------------------------------
echo "==> --body @missing-file"
if "$ph" prompt create --name "Missing Body" --body "@$tmp/no-such-file.md" >/dev/null 2>"$tmp/missing.err"; then
  fail "missing --body file should exit non-zero"
fi
grep -qi "body file not found" "$tmp/missing.err" || fail "missing body stderr should be actionable"

echo "OK"
