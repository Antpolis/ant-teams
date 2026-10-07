#!/usr/bin/env bash
#
# tests/test_project_env_runtime.sh — env-only project config contract (2026-08).
#
# Migrated from tests/test_project_env_runtime.js (SPEC-004-T4, issue #54).
# Assertion parity: all 13 Node checks migrated 1:1; none weakened.
# Stale-setup classification: the Node original seeded every init invocation
# with `--skip-inspection`, a flag retired by SPEC-005-T1 (the inspection
# engine was removed). All 12 pre-migration failures were caused by that flag
# alone; the assertions themselves were already current and are migrated
# unchanged.
#
# Locks the founder-confirmed env-only configuration contract into executable
# checks. `.github-project.json` no longer exists as a config artifact:
# `.github-project.env` (ANT_TEAM_* exports) is the SOLE committed project
# config source, seeded and updated DIRECTLY by project initialization (no
# standalone generator). There is NO JSON import/removal path — a stray
# `.github-project.json` is ignored (never read, never removed).
#
#   ENV-1   fresh init seeds the full canonical env key set; no JSON is written
#   ENV-2   founder env values are preserved; only missing keys are filled
#   ENV-3   a stray .github-project.json is ignored (not imported, not removed)
#   ENV-4   ANT_TEAM_DOCS_PROJECT_NAME defaults to the git repo basename
#   ENV-5   founder projectName override is preserved by init
#   ENV-6   shell-hostile founder values survive a strict source round-trip
#   ENV-7   idempotent rerun leaves the env byte-identical and mtime unchanged
#   ENV-8   --dry-run reports [would-write] and writes/deletes nothing
#   ENV-9   gh_project_helper resolves from the env alone (no JSON parse)
#   ENV-10  do-task worktree helpers read ANT_TEAM_WORKTREE_ROOT from the env
#   ENV-11  AGENTS.md Local Configuration Files lists .github-project.env
#   ENV-12  ANT_TEAM_DOCS_PROJECT_PATH resolves as VAULT_PATH/02-Architecture-Landscape/projects/NAME
#           (founder-set concrete value preserved verbatim; no template key emitted)
#
# No network access. Isolated temp fixtures only — never the real vault or
# the real user HOME.
#
# Run directly: `bash tests/test_project_env_runtime.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/init_helpers.sh"

HELPER="$INIT_REPO_ROOT/templates/opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/out.txt"
ERR="$TMP/err.txt"

# Canonical state option keys (mirrored in init + skills + docs constants).
CANONICAL_STATE_KEYS=(
  OPEN BACKLOG NEED_ATTENTIONS READY IN_PROGRESS
  IN_REVIEW READY_TO_MERGE BLOCKED DONE
)

# init_args [EXTRA...] — print the standard noninteractive invocation for a
# target dir (positional arg 1) plus extras, one argument per line.
init_args() {
  local tmp="$1"; shift
  printf '%s\n' \
    --noninteractive \
    --project-dir "$tmp" \
    --worktree-root "$tmp/wt" \
    --name demo-name \
    --github-owner antpolis \
    --github-project-number 1 \
    "$@"
}

# run_init PROJECT_DIR [EXTRA...] — run the engine with the standard args.
run_init() {
  local tmp="$1"; shift
  local -a args=()
  mapfile -t args < <(init_args "$tmp" "$@")
  init_run "$OUT" "$ERR" -- "${args[@]}"
}

# env_var DIR VARNAME — strict-source the env and echo one variable. A dirty
# source (non-zero subshell exit) is reported as a FAIL and the (partial)
# value is still returned so the enclosing comparison also fails.
env_var() {
  local val
  val="$(init_source_env_var "$1" "$2")" || true
  if (( INIT_RC != 0 )); then
    check FAIL ".github-project.env sources cleanly ($2)"
  fi
  printf '%s' "$val"
}

# shq VALUE — single-quote a value so any shell metacharacter survives.
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }

# --- ENV-1: fresh init seeds the canonical env key set, no JSON ---------------

init_suite "ENV-1 fresh init seeds canonical env"

tmp="$TMP/env1"
mkdir -p "$tmp/.git"
run_init "$tmp"
assert_exit_zero "ENV-1: init exits 0" "$INIT_RC"
assert_exists "ENV-1: .github-project.env created" "$tmp/.github-project.env"
assert_not_exists "ENV-1: no .github-project.json written" "$tmp/.github-project.json"

required=(
  ANT_TEAM_GITHUB_OWNER
  ANT_TEAM_GITHUB_OWNER_TYPE
  ANT_TEAM_GITHUB_REPO
  ANT_TEAM_GITHUB_PROJECT_NUMBER
  ANT_TEAM_GITHUB_PROJECT_ID
  ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID
  ANT_TEAM_WORKTREE_ROOT
  ANT_TEAM_DOCS_PROJECT_NAME
)
for name in "${required[@]}"; do
  assert_file_contains_str "ENV-1: seeds $name" "$tmp/.github-project.env" "export $name="
done
for key in "${CANONICAL_STATE_KEYS[@]}"; do
  assert_file_contains_str "ENV-1: seeds workflow state option $key" "$tmp/.github-project.env" \
    "export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_${key}_ID="
done
# Every non-comment line is an export (sourceable contract).
bad_lines="$(grep -Ev '^(#.*)?$' "$tmp/.github-project.env" | grep -cvE '^export ANT_TEAM_[A-Z0-9_]+=' || true)"
assert_eq "ENV-1: every non-comment line is an ANT_TEAM_* export" "$bad_lines" "0"
assert_eq "ENV-1: operator flag value recorded" "$(env_var "$tmp" ANT_TEAM_GITHUB_OWNER)" "antpolis"

# --- ENV-2: founder values preserved -------------------------------------------

init_suite "ENV-2 founder values preserved"

tmp="$TMP/env2"
mkdir -p "$tmp/.git"
cat > "$tmp/.github-project.env" <<'ENV'
# founder-owned env
export ANT_TEAM_GITHUB_OWNER='founder-owner'
export ANT_TEAM_DOCS_PROJECT_NAME='founder-name'
ENV
run_init "$tmp"
assert_exit_zero "ENV-2: init exits 0" "$INIT_RC"
assert_file_contains_str "ENV-2: founder owner preserved verbatim" "$tmp/.github-project.env" "export ANT_TEAM_GITHUB_OWNER='founder-owner'"
assert_file_contains_str "ENV-2: founder project name preserved verbatim" "$tmp/.github-project.env" "export ANT_TEAM_DOCS_PROJECT_NAME='founder-name'"
assert_file_contains_str "ENV-2: missing key PROJECT_NUMBER filled" "$tmp/.github-project.env" "export ANT_TEAM_GITHUB_PROJECT_NUMBER="
assert_file_contains_str "ENV-2: missing key WORKTREE_ROOT filled" "$tmp/.github-project.env" "export ANT_TEAM_WORKTREE_ROOT="
assert_eq "ENV-2: founder owner survives sourcing" "$(env_var "$tmp" ANT_TEAM_GITHUB_OWNER)" "founder-owner"
assert_eq "ENV-2: founder project name survives sourcing" "$(env_var "$tmp" ANT_TEAM_DOCS_PROJECT_NAME)" "founder-name"

# --- ENV-3: stray .github-project.json ignored ----------------------------------

init_suite "ENV-3 stray JSON ignored"

tmp="$TMP/env3"
mkdir -p "$tmp/.git"
printf '{ "owner": "json-owner", "project": { "number": 9, "id": "PVT_JSON" } }' > "$tmp/.github-project.json"
run_init "$tmp"
assert_exit_zero "ENV-3: init exits 0" "$INIT_RC"
assert_exists "ENV-3: stray JSON left in place (no removal path)" "$tmp/.github-project.json"
assert_eq "ENV-3: flag owner wins" "$(env_var "$tmp" ANT_TEAM_GITHUB_OWNER)" "antpolis"
assert_file_not_contains_str "ENV-3: JSON owner not imported" "$tmp/.github-project.env" "json-owner"
assert_file_not_contains_str "ENV-3: JSON project id not imported" "$tmp/.github-project.env" "PVT_JSON"
assert_eq "ENV-3: flag project number wins" "$(env_var "$tmp" ANT_TEAM_GITHUB_PROJECT_NUMBER)" "1"

# --- ENV-4: project name defaults to the git repo basename ------------------------

init_suite "ENV-4 project name defaults to repo basename"

tmp="$TMP/env4"
mkdir -p "$tmp/.git"
run_init "$tmp"
assert_exit_zero "ENV-4: init exits 0" "$INIT_RC"
assert_eq "ENV-4: project name is the repo basename, not --name" \
  "$(env_var "$tmp" ANT_TEAM_DOCS_PROJECT_NAME)" "$(basename "$tmp")"

# --- ENV-5: founder project name preserved -----------------------------------------

init_suite "ENV-5 founder project name override"

tmp="$TMP/env5"
mkdir -p "$tmp/.git"
printf "export ANT_TEAM_DOCS_PROJECT_NAME='founder-chosen'\n" > "$tmp/.github-project.env"
run_init "$tmp" --force
assert_exit_zero "ENV-5: init --force exits 0" "$INIT_RC"
assert_eq "ENV-5: founder project name preserved" "$(env_var "$tmp" ANT_TEAM_DOCS_PROJECT_NAME)" "founder-chosen"

# --- ENV-6: shell-hostile founder values round-trip ---------------------------------

init_suite "ENV-6 shell-hostile values round-trip"

tmp="$TMP/env6"
mkdir -p "$tmp/.git"
hostile_owner="od'day \$(rm -rf /) \`id\` \\evil"
hostile_repo='owner/repo with spaces'
{
  printf '# founder-owned env\n'
  printf 'export ANT_TEAM_GITHUB_OWNER=%s\n' "$(shq "$hostile_owner")"
  printf 'export ANT_TEAM_GITHUB_REPO=%s\n' "$(shq "$hostile_repo")"
} > "$tmp/.github-project.env"
run_init "$tmp"
assert_exit_zero "ENV-6: init exits 0" "$INIT_RC"
assert_eq "ENV-6: single-quoted owner survives byte-for-byte" "$(env_var "$tmp" ANT_TEAM_GITHUB_OWNER)" "$hostile_owner"
assert_eq "ENV-6: spaced repo value survives" "$(env_var "$tmp" ANT_TEAM_GITHUB_REPO)" "$hostile_repo"

# --- ENV-7: idempotent rerun -----------------------------------------------------------

init_suite "ENV-7 idempotent rerun"

tmp="$TMP/env7"
mkdir -p "$tmp/.git"
run_init "$tmp"
assert_exit_zero "ENV-7: first init exits 0" "$INIT_RC"
cp "$tmp/.github-project.env" "$TMP/env7.before"
mtime_before="$(stat -c %Y "$tmp/.github-project.env")"
run_init "$tmp"
assert_exit_zero "ENV-7: rerun exits 0" "$INIT_RC"
assert_out_contains "$OUT" '\.github-project\.env already up to date' \
  "ENV-7: rerun reports the env already up to date"
if cmp -s "$TMP/env7.before" "$tmp/.github-project.env"; then
  check OK "ENV-7: env byte-identical on rerun"
else
  check FAIL "ENV-7: env changed on rerun"
fi
mtime_after="$(stat -c %Y "$tmp/.github-project.env")"
assert_eq "ENV-7: env not rewritten on rerun (mtime unchanged)" "$mtime_after" "$mtime_before"

# --- ENV-8: dry-run writes/deletes nothing ----------------------------------------------

init_suite "ENV-8 dry-run"

tmp="$TMP/env8"
mkdir -p "$tmp/.git"
run_init "$tmp" --dry-run
assert_exit_zero "ENV-8: dry-run exits 0" "$INIT_RC"
assert_out_contains "$OUT" '\[would-write\] \.github-project\.env' \
  "ENV-8: dry-run reports the env would-write"
assert_not_exists "ENV-8: dry-run writes nothing" "$tmp/.github-project.env"
assert_not_exists "ENV-8: dry-run creates no JSON" "$tmp/.github-project.json"

# --- ENV-9: gh_project_helper resolves from the env alone --------------------------------

init_suite "ENV-9 helper resolves from the env alone"

tmp="$TMP/env9"
mkdir -p "$tmp/.git"
printf "export ANT_TEAM_GITHUB_OWNER='env-owner'\nexport ANT_TEAM_GITHUB_PROJECT_NUMBER='7'\n" > "$tmp/.github-project.env"
bin="$TMP/env9-bin"
mkdir -p "$bin"
gh_log="$bin/gh-calls.log"
cat > "$bin/gh" <<GH
#!/usr/bin/env bash
printf 'ARGS:' >> '$gh_log'; printf ' [%s]' "\$@" >> '$gh_log'; echo '{"fields":[]}'
GH
chmod 0755 "$bin/gh"
init_run_cmd "$OUT" "$ERR" "$tmp" "PATH=$bin:$PATH" -- bash "$HELPER" list-statuses
# No env option pins -> remote field-list fallback; the stub board returns no
# Workflow State options, which must be a LOUD failure (founder-direct
# 2026-09-05) instead of a silent empty success.
assert_exit_nonzero "ENV-9: unresolvable statuses exit non-zero" "$INIT_RC"
assert_out_contains "$ERR" 'Could not resolve any Workflow State option' \
  "ENV-9: unresolvable board reported loudly"
calls="$(cat "$gh_log")"
if [[ "$calls" == *'[env-owner]'* ]]; then
  check OK "ENV-9: owner comes from the env"
else
  check FAIL "ENV-9: owner must come from the env, got: $calls"
fi
if [[ "$calls" == *'[7]'* ]]; then
  check OK "ENV-9: project number comes from the env"
else
  check FAIL "ENV-9: project number must come from the env, got: $calls"
fi

# --- ENV-10: do-task worktree helpers source the env ----------------------------------------

init_suite "ENV-10 worktree helpers read the env"

for s in \
  'templates/opencode/skills/do-task/scripts/create_task_worktree.sh' \
  'templates/opencode/skills/do-task/scripts/cleanup_task_worktree.sh'; do
  assert_file_contains_str "ENV-10: $s sources .github-project.env" "$INIT_REPO_ROOT/$s" '.github-project.env'
  assert_file_contains_str "ENV-10: $s reads ANT_TEAM_WORKTREE_ROOT" "$INIT_REPO_ROOT/$s" 'ANT_TEAM_WORKTREE_ROOT'
  assert_file_not_contains_str "ENV-10: $s has no .github-project.json fallback" "$INIT_REPO_ROOT/$s" '.github-project.json'
done
# Behavioral: a founder-set worktree root survives init and reaches consumers.
tmp="$TMP/env10"
mkdir -p "$tmp/.git"
printf "export ANT_TEAM_WORKTREE_ROOT='/from/env'\n" > "$tmp/.github-project.env"
run_init "$tmp"
assert_exit_zero "ENV-10: init exits 0" "$INIT_RC"
assert_eq "ENV-10: founder worktree root preserved" "$(env_var "$tmp" ANT_TEAM_WORKTREE_ROOT)" "/from/env"

# --- ENV-11: AGENTS.md lists the env -----------------------------------------------------------

init_suite "ENV-11 AGENTS.md lists the env"

tmp="$TMP/env11"
mkdir -p "$tmp/.git"
run_init "$tmp"
assert_exit_zero "ENV-11: init exits 0" "$INIT_RC"
assert_file_contains_str "ENV-11: AGENTS.md Local Configuration Files lists .github-project.env" "$tmp/AGENTS.md" '`.github-project.env`'
assert_file_not_contains_str "ENV-11: AGENTS.md has no .github-project.json config reference" "$tmp/AGENTS.md" '.github-project.json'

# --- ENV-12: concrete project path derivation ----------------------------------------------------

init_suite "ENV-12 project path derivation"

tmp="$TMP/env12a"
mkdir -p "$tmp/.git"
{
  printf "export ANT_TEAM_DOCS_VAULT_PATH='/vault/root'\n"
  printf "export ANT_TEAM_DOCS_PROJECT_NAME='my-proj'\n"
} > "$tmp/.github-project.env"
run_init "$tmp"
assert_exit_zero "ENV-12a: init exits 0" "$INIT_RC"
assert_eq "ENV-12a: project path derives as VAULT/02-Architecture-Landscape/projects/NAME" \
  "$(env_var "$tmp" ANT_TEAM_DOCS_PROJECT_PATH)" \
  '/vault/root/02-Architecture-Landscape/projects/my-proj'
assert_file_not_contains_str "ENV-12a: no template key emitted" "$tmp/.github-project.env" 'ANT_TEAM_DOCS_PROJECT_PATH_TEMPLATE'

tmp="$TMP/env12b"
mkdir -p "$tmp/.git"
{
  printf "export ANT_TEAM_DOCS_VAULT_PATH='/vault/root'\n"
  printf "export ANT_TEAM_DOCS_PROJECT_NAME='my-proj'\n"
  printf "export ANT_TEAM_DOCS_PROJECT_PATH='/custom/elsewhere/proj'\n"
} > "$tmp/.github-project.env"
run_init "$tmp" --force
assert_exit_zero "ENV-12b: init --force exits 0" "$INIT_RC"
assert_eq "ENV-12b: founder-set concrete path preserved verbatim" \
  "$(env_var "$tmp" ANT_TEAM_DOCS_PROJECT_PATH)" \
  '/custom/elsewhere/proj'

# --- Summary ----------------------------------------------------------------------------------------

init_done
