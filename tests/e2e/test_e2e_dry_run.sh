#!/usr/bin/env bash
#
# test_e2e_dry_run.sh — SPEC-001 TEST-2.1 `test-e2e-dry-run` + TEST-5 contract.
# Traceability: AC-T7-006 ← AC-SPEC-009 (dry-run writes nothing) + OBS-2.1.
#
# Runs init with --dry-run on repo-node-npm. Expected:
#   - exit 0
#   - [would-write] lines present
#   - ZERO files created or modified (verified by content snapshot diff)
#
set -euo pipefail

source "$(dirname "$0")/lib/test_helpers.sh"

REPO_ROOT="$(e2e_repo_root "$0")"
INIT="$(e2e_init_script "$REPO_ROOT")"

e2e_begin "test-e2e-dry-run"

TMP="$(e2e_make_fixture_repo "$(e2e_fixtures_dir "$REPO_ROOT")/repo-node-npm")"
trap 'rm -rf "$TMP"' EXIT

# Snapshot BEFORE (exclude .git marker and our log file which we will write
# inside TMP — use a separate log location outside the snapshot scope).
LOG=$(mktemp)
trap 'rm -rf "$TMP" "$LOG"' EXIT
BEFORE=$(e2e_snapshot_files "$TMP" | sha256sum | cut -d' ' -f1)

set +e
bash "$INIT" \
  --noninteractive \
  --dry-run \
  --project-dir "$TMP" \
  --worktree-root "$TMP/wt" \
  --name drydemo \
  --description "Dry run demo" \
  --repo-role service \
  --github-owner antpolis \
  --github-project-number 9 \
  >"$LOG" 2>&1
RC=$?
set -e

assert_exit_zero "dry-run exit code" "$RC"

# OBS-2.1: zero file changes. Re-snapshot and compare hashes.
AFTER=$(e2e_snapshot_files "$TMP" | sha256sum | cut -d' ' -f1)
assert_eq "zero file changes (snapshot identical)" "$BEFORE" "$AFTER"

# OBS-2.1: no AGENTS.md / skills / config written.
assert_not_exists "no AGENTS.md written" "$TMP/AGENTS.md"
assert_not_exists "no skills copied" "$TMP/.opencode/skills"
assert_not_exists "no .github-project.json created" "$TMP/.github-project.json"

# OBS-2: [would-write] lines present and a dry-run summary emitted.
assert_file_contains "would-write lines present" "$LOG" '\[would-write\]'
assert_file_contains "dry-run summary line" "$LOG" '\[summary\] Dry run complete'

# Sanity: a NON-dry run with the same flags WOULD write AGENTS.md (proves the
# dry-run actually suppressed a real write rather than the inputs being inert).
set +e
bash "$INIT" \
  --noninteractive \
  --project-dir "$TMP" \
  --worktree-root "$TMP/wt" \
  --name drydemo \
  --description "Dry run demo" \
  --repo-role service \
  --github-owner antpolis \
  --github-project-number 9 \
  >"$TMP/realrun.log" 2>&1
RC_REAL=$?
set -e
assert_exit_zero "control: real (non-dry) run exit code" "$RC_REAL"
assert_exists "control: real run wrote AGENTS.md" "$TMP/AGENTS.md"

e2e_done
