#!/usr/bin/env bash
#
# tests/test_dryrun.sh — SPEC-001-T6 unit tests (issue #7).
#
# Migrated from tests/test_dryrun.js (SPEC-004-T4, issue #54).
# Assertion parity: all 15 Node checks migrated; none weakened.
# Stale-assertion classification (the single pre-migration failure):
#   AC-T6-004 asserted "when node is absent from PATH, exit 1 with [error]
#   naming >=18". That contract belonged to the Node-based engine and was
#   retired by SPEC-004-T3 (#53, Done): the engine is now Bash + jq and MUST
#   run without node. The migrated harness asserts the inverted — stronger —
#   node-free contract: a full init run SUCCEEDS with every node binary
#   stripped from PATH.
#
# Asserts the OBS-2 dry-run contract (true no-write) and the ERR-1 pre-flight
# validation contract. Drives `templates/scripts/init-project.sh` against
# throwaway target project directories.
#
# Coverage:
#   - AC-T6-002: --dry-run produces [would-write] lines and ZERO file changes
#                (traceable to AC-SPEC-009 / OBS-2.1).
#   - AC-T6-003: init on a non-git directory exits 1 with [error] (ERR-1.1).
#   - AC-T6-004: node-free contract — init succeeds with node absent from
#                PATH (SPEC-004-T3). (Skipped when node cannot be hidden.)
#   - OBS-2.1:   no file is created or modified under --dry-run. The target
#                dir retains only its pre-run contents (.git marker).
#   - OBS-1.1:   dry-run emits [would-write] (not [writing]) for every
#                artifact that a real run would create.
#   - OBS-1.2:   the trailing [summary] reports would-write / skipped /
#                warnings counts.
#   - ERR-1.1:   nonexistent target dir and non-git target dir each exit 1
#                with a specific [error] message before any file is written.
#   - OBS-3.1:   required-sibling-missing error wording (source-level check).
#
# Run directly: `bash tests/test_dryrun.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/init_helpers.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/out.txt"
ERR="$TMP/err.txt"

run_dryrun() {
  local tmp="$1"; shift
  init_run "$OUT" "$ERR" -- \
    --noninteractive \
    --project-dir "$tmp" \
    --worktree-root "$tmp/wt" \
    --name test \
    --github-owner antpolis \
    --github-project-number 9 \
    "$@"
}

# --- Pre-flight -----------------------------------------------------------------

init_suite "preflight"

assert_exists "init-project.sh exists" "$INIT_SCRIPT"
bash -n "$INIT_SCRIPT" 2>"$ERR" && check OK "init-project.sh is syntactically valid" || check FAIL "init-project.sh is syntactically valid"

# --- AC-T6-002: --dry-run produces [would-write] and zero file changes ------------

init_suite "AC-T6-002 dry-run writes nothing"

tmp="$TMP/ac002a"
mkdir -p "$tmp/.git"
run_dryrun "$tmp" --dry-run
assert_exit_zero "AC-T6-002a: --dry-run exits 0" "$INIT_RC"

tmp="$TMP/ac002b"
mkdir -p "$tmp/.git"
run_dryrun "$tmp" --dry-run
assert_out_contains "$OUT" '\[would-write\]' "AC-T6-002b: emits [would-write] lines"
assert_out_not_contains_str "$OUT" '[writing]' "AC-T6-002b: dry-run must not emit [writing]"

tmp="$TMP/ac002c"
mkdir -p "$tmp/.git"
run_dryrun "$tmp" --dry-run
assert_exit_zero "AC-T6-002c: --dry-run exits 0" "$INIT_RC"
entries="$(find "$tmp" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort | tr '\n' ' ')"
assert_eq "AC-T6-002c: only the .git marker remains (no AGENTS.md/.opencode/env/docs)" \
  "$entries" ".git "

tmp="$TMP/ac002d"
mkdir -p "$tmp/.git"
run_dryrun "$tmp" --dry-run
assert_exit_zero "AC-T6-002d: --dry-run exits 0" "$INIT_RC"
assert_not_exists "AC-T6-002d: --dry-run does NOT create the worktree-root dir" "$tmp/wt"

tmp="$TMP/ac002e"
mkdir -p "$tmp/.git"
run_dryrun "$tmp" --dry-run
assert_exit_zero "AC-T6-002e: --dry-run exits 0" "$INIT_RC"
assert_not_exists "AC-T6-002e: .opencode/ must not exist" "$tmp/.opencode"
assert_not_exists "AC-T6-002e: .github-project.env must not exist" "$tmp/.github-project.env"
assert_not_exists "AC-T6-002e: AGENTS.md must not exist" "$tmp/AGENTS.md"

tmp="$TMP/ac002f"
mkdir -p "$tmp/.git"
run_dryrun "$tmp"
list_dir_entries() { find "$1" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort; }
list_dir_entries "$tmp" > "$TMP/ac002f.before"
run_dryrun "$tmp" --force --dry-run
assert_exit_zero "AC-T6-002f: dry-run --force exits 0" "$INIT_RC"
list_dir_entries "$tmp" > "$TMP/ac002f.after"
if cmp -s "$TMP/ac002f.before" "$TMP/ac002f.after"; then
  check OK "AC-T6-002f: dry-run --force on an initialized repo adds no new files"
else
  check FAIL "AC-T6-002f: dry-run --force changed the dir"
fi
bak_count="$(find "$tmp" -maxdepth 1 -name 'AGENTS.md.bak*' | wc -l | tr -d ' ')"
assert_eq "AC-T6-002f: dry-run --force must not create .bak files" "$bak_count" "0"

# --- OBS-1.2: summary line reports counts -------------------------------------------

init_suite "OBS-1.2 summary line"

tmp="$TMP/obs12"
mkdir -p "$tmp/.git"
run_dryrun "$tmp" --dry-run
assert_exit_zero "OBS-1.2 (dry-run): exits 0" "$INIT_RC"
assert_out_contains "$OUT" '^\[summary\] Dry run complete\. [0-9]+ would-write; [0-9]+ skipped; [0-9]+ warning\(s\)\.$' \
  "OBS-1.2: dry-run summary reports would-write + skipped + warnings counts"

tmp="$TMP/obs12-real"
mkdir -p "$tmp/.git"
run_dryrun "$tmp"
assert_exit_zero "OBS-1.2 (real): exits 0" "$INIT_RC"
assert_out_contains "$OUT" '^\[summary\] Initialization complete\. [0-9]+ created; [0-9]+ merged/updated; [0-9]+ skipped; [0-9]+ warning\(s\)\.$' \
  "OBS-1.2: real-run summary reports created + merged + skipped + warnings"

# --- AC-T6-003: non-git directory exits 1 ---------------------------------------------

init_suite "AC-T6-003 non-git directory"

tmp="$TMP/t6-nogit"
mkdir -p "$tmp"
run_dryrun "$tmp"
assert_exit_nonzero "AC-T6-003: init on non-git dir exits non-zero" "$INIT_RC"
assert_out_contains "$ERR" '\[error\]' "AC-T6-003: [error] on stderr"
assert_out_contains "$ERR" 'not a git repository' "AC-T6-003: 'not a git repository' wording"

tmp="$TMP/t6-nogit-clean"
mkdir -p "$tmp"
run_dryrun "$tmp"
entries="$(find "$tmp" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
assert_eq "AC-T6-003: non-git failure writes nothing" "$entries" "0"

# --- ERR-1.1: nonexistent target dir ------------------------------------------------------

init_suite "ERR-1.1 nonexistent target"

init_run "$OUT" "$ERR" -- \
  --noninteractive \
  --project-dir "$TMP/does-not-exist-target" \
  --worktree-root "$TMP/does-not-exist-wt" \
  --name test \
  --github-owner antpolis \
  --github-project-number 9
assert_exit_nonzero "ERR-1.1: nonexistent target dir exits non-zero" "$INIT_RC"
assert_out_contains "$ERR" 'does not exist' "ERR-1.1: 'does not exist' wording"

# --- AC-T6-004: node-free contract (SPEC-004-T3) --------------------------------------------

init_suite "AC-T6-004 node-free contract"

# Strip every PATH directory containing a `node` binary. Skip cleanly when
# node cannot be hidden on this host (same guard as the Node original).
if command -v node >/dev/null 2>&1; then
  filtered_path=""
  IFS=':' read -r -a path_dirs <<< "${PATH:-}"
  for d in "${path_dirs[@]}"; do
    [[ -n "$d" && ! -e "$d/node" ]] && filtered_path="$filtered_path$d:"
  done
  filtered_path="${filtered_path%:}"
  if [[ "$filtered_path" == "$PATH" || -z "$filtered_path" ]]; then
    check OK "AC-T6-004: (skipped: could not hide node on this host)"
  else
    tmp="$TMP/ac004-nodefree"
    mkdir -p "$tmp/.git"
    init_run "$OUT" "$ERR" "PATH=$filtered_path" -- \
      --noninteractive \
      --project-dir "$tmp" \
      --worktree-root "$tmp/wt" \
      --name test \
      --github-owner antpolis \
      --github-project-number 9
    assert_exit_zero "AC-T6-004: init succeeds with node absent from PATH (node-free engine)" "$INIT_RC"
    assert_exists "AC-T6-004: AGENTS.md produced without node" "$tmp/AGENTS.md"
  fi
else
  check OK "AC-T6-004: (node not present on host; node-free contract trivially holds)"
fi

# --- OBS-3.1: source repo path included in error -----------------------------------------------

init_suite "OBS-3.1 source repo path in error"

assert_file_contains "OBS-3.1: required-sibling-missing error includes the resolved path wording" \
  "$INIT_SCRIPT" 'Required skill not found in the sibling skills root:'
assert_file_contains "OBS-3.1: OBS-3.1 reference present in script" "$INIT_SCRIPT" 'OBS-3\.1'

# --- Summary --------------------------------------------------------------------------------------

init_done
