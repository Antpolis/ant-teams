#!/usr/bin/env bash
#
# tests/test_idempotency.sh — SPEC-001-T6 unit tests (issue #7).
#
# Migrated from tests/test_idempotency.js (SPEC-004-T4, issue #54).
# Assertion parity: 15/15 Node checks migrated 1:1; none weakened.
#
# Asserts the TR-2 idempotency contract and ERR-3.2 backup behavior. Drives
# `templates/scripts/init-project.sh` against throwaway target project
# directories.
#
# Coverage:
#   - AC-T6-006: idempotent rerun (no --force) → exit 0, "No changes needed",
#                no file modifications (traceable to AC-SPEC-005 / TR-2.1).
#   - AC-T6-007: --force rerun creates .bak of a GENUINELY-changed AGENTS.md;
#                the new AGENTS.md is structurally identical to a second
#                --force with the same inputs (traceable to TR-2.2).
#   - AC-T6-008: interrupt (simulated by removing AGENTS.md) leaves the repo
#                in a safe state; rerun detects the missing artifact and
#                regenerates it.
#   - TR-2.2:    two consecutive --force runs with identical inputs produce
#                byte-for-byte identical AGENTS.md (the issue body's exact
#                verification command).
#   - ERR-2.1:   atomic writes leave no partial files; a real run produces a
#                valid AGENTS.md whose line 1 is the generation comment.
#
# Run directly: `bash tests/test_idempotency.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/init_helpers.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/out.txt"
ERR="$TMP/err.txt"

# noninteractive PROJECT_DIR [EXTRA...] — print the required identity flags
# plus optional extras, one argument per line.
noninteractive() {
  local project_dir="$1"; shift
  printf '%s\n' \
    --noninteractive \
    --project-dir "$project_dir" \
    --worktree-root "$project_dir/wt" \
    --name test \
    --github-owner antpolis \
    --github-project-number 9 \
    "$@"
}

run_init() {
  local project_dir="$1"; shift
  local -a args=()
  mapfile -t args < <(noninteractive "$project_dir" "$@")
  init_run "$OUT" "$ERR" -- "${args[@]}"
}

# --- Pre-flight --------------------------------------------------------------

init_suite "preflight"

assert_exists "init-project.sh exists" "$INIT_SCRIPT"
bash -n "$INIT_SCRIPT" 2>"$ERR" && check OK "init-project.sh is syntactically valid" || check FAIL "init-project.sh is syntactically valid"

# --- AC-T6-006: idempotent rerun (no --force) --------------------------------

init_suite "AC-T6-006 idempotent rerun without --force"

tmp="$TMP/ac006a"
mkdir -p "$tmp/.git"
run_init "$tmp"
run_init "$tmp"
assert_exit_zero "AC-T6-006a: second run exits 0" "$INIT_RC"

tmp="$TMP/ac006b"
mkdir -p "$tmp/.git"
run_init "$tmp"
run_init "$tmp"
assert_out_contains "$OUT" 'already up to date|no changes needed|already matches' \
  "AC-T6-006b: second run emits idempotent no-change wording"

tmp="$TMP/ac006c"
mkdir -p "$tmp/.git"
run_init "$tmp"
cp "$tmp/.github-project.env" "$TMP/env.first"
run_init "$tmp"
if cmp -s "$TMP/env.first" "$tmp/.github-project.env"; then
  check OK "AC-T6-006c: .github-project.env is byte-for-byte identical across reruns"
else
  check FAIL "AC-T6-006c: .github-project.env changed on idempotent rerun"
fi

tmp="$TMP/ac006d"
mkdir -p "$tmp/.git"
run_init "$tmp"
cp "$tmp/AGENTS.md" "$TMP/agents.first"
run_init "$tmp"
if cmp -s "$TMP/agents.first" "$tmp/AGENTS.md"; then
  check OK "AC-T6-006d: AGENTS.md is byte-for-byte identical across reruns (no --force)"
else
  check FAIL "AC-T6-006d: AGENTS.md changed on idempotent rerun (no --force)"
fi

tmp="$TMP/ac006e"
mkdir -p "$tmp/.git"
run_init "$tmp"
run_init "$tmp"
bak_count="$(find "$tmp" -maxdepth 1 -name '*.bak*' | wc -l | tr -d ' ')"
assert_eq "AC-T6-006e: no new .bak files created on idempotent rerun" "$bak_count" "0"

# --- AC-T6-007 / TR-2.2: --force idempotency + .bak on genuine change --------

init_suite "AC-T6-007 --force idempotency + .bak"

tmp="$TMP/ac007a"
mkdir -p "$tmp/.git"
run_init "$tmp" --description "Original purpose text"
run_init "$tmp" --description "Changed purpose text" --force
bak_count="$(find "$tmp" -maxdepth 1 -name 'AGENTS.md.bak*' | wc -l | tr -d ' ')"
assert_eq "AC-T6-007a: --force on a GENUINELY changed AGENTS.md creates exactly one .bak" "$bak_count" "1"
assert_file_contains_str "AC-T6-007a: AGENTS.md updated to changed text" "$tmp/AGENTS.md" "Changed purpose text"

tmp="$TMP/ac007b"
mkdir -p "$tmp/.git"
run_init "$tmp" --force
cp "$tmp/AGENTS.md" "$TMP/agents.force.first"
run_init "$tmp" --force
if cmp -s "$TMP/agents.force.first" "$tmp/AGENTS.md"; then
  check OK "AC-T6-007b: TR-2.2 — two consecutive --force runs produce identical AGENTS.md"
else
  check FAIL "AC-T6-007b: AGENTS.md differs across --force reruns (TR-2.2 violation)"
fi

tmp="$TMP/ac007c"
mkdir -p "$tmp/.git"
run_init "$tmp" --description "Stable purpose" --force
baks_first="$(find "$tmp" -maxdepth 1 -name 'AGENTS.md.bak*' | wc -l | tr -d ' ')"
run_init "$tmp" --description "Stable purpose" --force
baks_second="$(find "$tmp" -maxdepth 1 -name 'AGENTS.md.bak*' | wc -l | tr -d ' ')"
assert_eq "AC-T6-007c: idempotent --force does NOT create a new .bak" "$baks_second" "$baks_first"

tmp="$TMP/ac007d"
mkdir -p "$tmp/.git"
run_init "$tmp" --description "Stable purpose" --force
run_init "$tmp" --description "Stable purpose" --force
assert_out_contains "$OUT" 'no changes needed|idempotent|already matches|already contains' \
  "AC-T6-007d: idempotent --force emits no-change wording (not a spurious write)"

# --- AC-T6-008: interruption safety (atomic write, rerun detects) ------------

init_suite "AC-T6-008 interruption safety"

tmp="$TMP/ac008a"
mkdir -p "$tmp/.git"
run_init "$tmp"
assert_exists "AC-T6-008a precondition: AGENTS.md exists" "$tmp/AGENTS.md"
rm -f "$tmp/AGENTS.md"
run_init "$tmp" --force
assert_exit_zero "AC-T6-008a: rerun after simulated interrupt exits 0" "$INIT_RC"
assert_exists "AC-T6-008a: AGENTS.md regenerated after simulated interrupt" "$tmp/AGENTS.md"
line1="$(head -1 "$tmp/AGENTS.md")"
if [[ "$line1" == '<!-- Generated by init-project'* ]]; then
  check OK "AC-T6-008a: regenerated line 1 is the generation comment"
else
  check FAIL "AC-T6-008a: line 1 not a generation comment: $line1"
fi

tmp="$TMP/ac008b"
mkdir -p "$tmp/.git"
run_init "$tmp"
assert_file_contains_str "AC-T6-008b: AGENTS.md ends with required final section (no truncation)" "$tmp/AGENTS.md" "## Local Configuration Files"
if [[ -n "$(tr -d '[:space:]' <"$tmp/AGENTS.md")" ]]; then
  check OK "AC-T6-008b: AGENTS.md is non-empty"
else
  check FAIL "AC-T6-008b: AGENTS.md is empty or whitespace-only"
fi

# --- ERR-2.3: temp cleanup ----------------------------------------------------

init_suite "ERR-2.3 temp cleanup"

tmp="$TMP/err23"
mkdir -p "$tmp/.git"
run_init "$tmp"
leaked="$(find "$tmp" -maxdepth 1 \( -name '.AGENTS.md.*' -o -name '.github-project.env.*' \) | wc -l | tr -d ' ')"
assert_eq "ERR-2.3: no leaked temp files in target dir after a normal run" "$leaked" "0"

tmp="$TMP/err23-merge"
mkdir -p "$tmp/.git"
run_init "$tmp" --description "first"
run_init "$tmp" --description "second" --force --merge
leaked="$(find "$tmp" -maxdepth 1 \( -name '.AGENTS.md.*' -o -name '.github-project.env.*' \) | wc -l | tr -d ' ')"
assert_eq "ERR-2.3: no leaked temp files after a --force --merge run" "$leaked" "0"

# --- Summary ------------------------------------------------------------------

init_done
