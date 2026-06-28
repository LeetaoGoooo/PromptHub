#!/bin/zsh
# End-to-end shell scenario for the skill lifecycle commands:
#   * ph skill exports (read exported package directory)
#   * ph skill show (per-skill JSON)
#   * ph skill install (copy SKILL.md + sibling files into an agent dir)
#   * ph skill list (discover installed managed skills)
#   * ph skill inspect (full per-install record)
#   * ph skill where (locate on-disk install)
#   * ph skill update (must refuse cleanly when there is no remote source)
#   * ph skill uninstall (remove managed install)
#
# All operations are sandboxed under a temporary $PROMPTHUB_HOME so the
# host's real ~/.codex etc. are untouched. The `--home` flag is forwarded
# to every invocation; it controls both the exports root and the default
# agent directories (~/.codex, ~/.claude, ~/.cursor, ...).

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

# --- ph skill create seeds the exported package ---------------------------
echo "==> ph skill create --json"
"$ph" skill create \
  --home "$tmp" \
  --name "Lifecycle Reviewer" \
  --description "Lifecycle smoke fixture." \
  --category "QA" \
  --tag smoke \
  --tag lifecycle \
  --body "Body content for lifecycle smoke." \
  --json \
  >"$tmp/create.json" 2>"$tmp/create.err"

[[ ! -s "$tmp/create.err" ]] || fail "create stderr should be empty: $(cat "$tmp/create.err")"
skill_id=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['id'])" "$tmp/create.json")
pkg_dir="$tmp/.prompthub/skills/$skill_id"
[[ -f "$pkg_dir/SKILL.md" ]] || fail "create did not write SKILL.md into the export package"
python3 -c "
import json,sys
doc=json.load(open(sys.argv[1]))
assert doc['name']=='Lifecycle Reviewer', doc
assert doc['slug']=='lifecycle-reviewer', doc
assert doc['installationName']=='lifecycle-reviewer', doc
assert doc['kind']=='skill', doc
" "$tmp/create.json" || fail "create JSON did not match"

mkdir -p "$pkg_dir/scripts"

cat >"$pkg_dir/scripts/run.sh" <<'RUN'
#!/bin/sh
echo "ran"
RUN
chmod +x "$pkg_dir/scripts/run.sh"

# --- ph skill exports lists the package directory --------------------------
echo "==> ph skill exports --json"
"$ph" skill exports --home "$tmp" --json >"$tmp/exports.json" 2>"$tmp/exports.err"
[[ -s "$tmp/exports.err" ]] && fail "exports stderr should be empty: $(cat "$tmp/exports.err")"
python3 -c "
import json,sys
docs=json.load(open(sys.argv[1]))
assert isinstance(docs, list) and len(docs)==1, docs
e=docs[0]
assert e['slug']=='lifecycle-reviewer', e
assert e['kind']=='skill', e
assert e['installationName']=='lifecycle-reviewer', e
" "$tmp/exports.json" || fail "exports JSON did not match"

# --- ph skill show by slug --------------------------------------------------
echo "==> ph skill show by slug"
"$ph" skill show lifecycle-reviewer --home "$tmp" --json >"$tmp/show.json" 2>/dev/null
python3 -c "
import json,sys
doc=json.load(open(sys.argv[1]))
assert doc['name']=='Lifecycle Reviewer', doc
assert doc['installationName']=='lifecycle-reviewer', doc
assert doc.get('packageDirectoryPath','').endswith('lifecycle-reviewer') or '/skills/' in doc.get('packageDirectoryPath',''), doc
" "$tmp/show.json" || fail "show JSON did not match"

# --- ph skill install (global, codex) --------------------------------------
echo "==> ph skill install --agent codex --scope global"
"$ph" skill install lifecycle-reviewer \
  --home "$tmp" --project-root "$tmp" \
  --agent codex --scope global --json \
  >"$tmp/install.json" 2>"$tmp/install.err"

[[ -f "$tmp/.codex/skills/lifecycle-reviewer/SKILL.md" ]] \
  || fail "install did not write SKILL.md into ~/.codex/skills/lifecycle-reviewer/"
[[ -f "$tmp/.codex/skills/lifecycle-reviewer/scripts/run.sh" ]] \
  || fail "install did not copy package sibling files"
python3 -c "
import json,sys
doc=json.load(open(sys.argv[1]))
assert doc['package']=='lifecycle-reviewer', doc
assert doc['scope']=='global', doc
assert 'codex' in doc.get('agents',[]), doc
" "$tmp/install.json" || fail "install JSON did not match"

# --- ph skill list discovers the install -----------------------------------
echo "==> ph skill list --json"
"$ph" skill list --home "$tmp" --project-root "$tmp" --json >"$tmp/list.json" 2>/dev/null
python3 -c "
import json,sys
docs=json.load(open(sys.argv[1]))
assert any(d['package']=='lifecycle-reviewer' and d['scope']=='global' for d in docs), docs
" "$tmp/list.json" || fail "list JSON missing lifecycle-reviewer"

# --- ph skill inspect returns at least one row -----------------------------
echo "==> ph skill inspect --json"
"$ph" skill inspect lifecycle-reviewer --home "$tmp" --project-root "$tmp" --json >"$tmp/inspect.json" 2>/dev/null
python3 -c "
import json,sys
docs=json.load(open(sys.argv[1]))
assert any(d['package']=='lifecycle-reviewer' for d in docs), docs
rec=[d for d in docs if d['package']=='lifecycle-reviewer'][0]
assert rec['isManagedByPromptHub'] is True, rec
assert rec['installedPaths'], rec
" "$tmp/inspect.json" || fail "inspect JSON did not match"

# --- ph skill where prints the on-disk path --------------------------------
echo "==> ph skill where"
where_out=$("$ph" skill where lifecycle-reviewer --home "$tmp" --project-root "$tmp")
echo "$where_out" | grep -q ".codex/skills/lifecycle-reviewer" \
  || fail "where did not print expected agent path: $where_out"

# Note: `ph skill update` requires an originating remote source; behavior is
# covered by updateSkillReportsNoRemoteSourceForLocalInstall in the unit
# tests. Re-installing from the exported package is its own valid path and
# is exercised separately by `ph skill reinstall` in PromptHubCLITests.

# --- ph skill uninstall removes the managed install ------------------------
echo "==> ph skill uninstall --scope global"
"$ph" skill uninstall lifecycle-reviewer \
  --home "$tmp" --project-root "$tmp" --scope global --json \
  >"$tmp/uninstall.json" 2>"$tmp/uninstall.err"

[[ ! -e "$tmp/.codex/skills/lifecycle-reviewer/SKILL.md" ]] \
  || fail "uninstall did not remove the managed SKILL.md"

"$ph" skill list --home "$tmp" --project-root "$tmp" --json >"$tmp/list-after.json" 2>/dev/null
python3 -c "
import json,sys
docs=json.load(open(sys.argv[1]))
assert not any(
    d['package']=='lifecycle-reviewer'
    and d['scope']=='global'
    and any('.codex/skills/lifecycle-reviewer' in path for path in d.get('installedPaths', []))
    for d in docs
), docs
" "$tmp/list-after.json" || fail "list still reports uninstalled skill"

echo "OK"
