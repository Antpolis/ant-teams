#!/usr/bin/env bash
#
# test_e2e_force.sh — SPEC-001 TEST-2.1 `test-e2e-force`.
# Traceability: FR-5.5 (--force overwrites; .bak backup) + ERR-3.2 (backup
# before overwrite) + TR-2.2 (--force idempotency at content level). Also
# doubles as the "rollback"-shape safety check: the previous AGENTS.md is
# recoverable via the .bak.<timestamp> file.
#
set -euo pipefail

source "$(dirname "$0")/lib/test_helpers.sh"

REPO_ROOT="$(e2e_repo_root "$0")"
INIT="$(e2e_init_script "$REPO_ROOT")"

e2e_begin "test-e2e-force"

TMP="$(e2e_make_fixture_repo "$(e2e_fixtures_dir "$REPO_ROOT")/repo-node-npm")"
trap 'rm -rf "$TMP"' EXIT

# Run 1: produce an initial AGENTS.md.
set +e
bash "$INIT" --noninteractive --project-dir "$TMP" --worktree-root "$TMP/wt" \
  --name forcedemo --description "Original description" --repo-role service \
  --github-owner antpolis --github-project-number 9 \
  >"$TMP/run1.log" 2>&1
RC1=$?
set -e
assert_exit_zero "run 1 exit code" "$RC1"
assert_exists "AGENTS.md from run 1" "$TMP/AGENTS.md"

AGENTS_BEFORE=$(md5sum "$TMP/AGENTS.md" | cut -d' ' -f1)

# Run 2: --force with a CHANGED description must back up + regenerate.
set +e
bash "$INIT" --noninteractive --force --project-dir "$TMP" --worktree-root "$TMP/wt" \
  --name forcedemo --description "Changed description" --repo-role service \
  --github-owner antpolis --github-project-number 9 \
  >"$TMP/run2.log" 2>&1
RC2=$?
set -e
assert_exit_zero "--force run exit code" "$RC2"

# ERR-3.2: a .bak.<timestamp> backup of the previous AGENTS.md was created.
BAKS=$(find "$TMP" -maxdepth 1 -name 'AGENTS.md.bak.*' 2>/dev/null | wc -l | tr -d ' ')
assert_neq "exactly one .bak created" "$BAKS" "0"
assert_eq "exactly one .bak (not many)" "$BAKS" "1"

# The backup matches the pre-force AGENTS.md (rollback recoverability).
BAK_FILE=$(find "$TMP" -maxdepth 1 -name 'AGENTS.md.bak.*' | head -1)
BAK_MD5=$(md5sum "$BAK_FILE" | cut -d' ' -f1)
assert_eq ".bak matches pre-force AGENTS.md" "$BAK_MD5" "$AGENTS_BEFORE"

# Regenerated AGENTS.md carries the changed content.
assert_file_contains "AGENTS.md regenerated with changed description" \
  "$TMP/AGENTS.md" 'Changed description'

# Force-output log mentions backup + overwrite per OBS-1.
assert_file_contains "force log mentions backup" "$TMP/run2.log" 'backup'
assert_file_contains "force log mentions overwrite" "$TMP/run2.log" 'overwritten'

# Run 3: --force again with the SAME inputs (TR-2.2 content-level idempotency).
# Must NOT create a second .bak and NOT rewrite AGENTS.md.
AGENTS_BEFORE_RUN3=$(md5sum "$TMP/AGENTS.md" | cut -d' ' -f1)
set +e
bash "$INIT" --noninteractive --force --project-dir "$TMP" --worktree-root "$TMP/wt" \
  --name forcedemo --description "Changed description" --repo-role service \
  --github-owner antpolis --github-project-number 9 \
  >"$TMP/run3.log" 2>&1
RC3=$?
set -e
assert_exit_zero "--force idempotent rerun exit code" "$RC3"
BAKS_AFTER=$(find "$TMP" -maxdepth 1 -name 'AGENTS.md.bak.*' 2>/dev/null | wc -l | tr -d ' ')
assert_eq "no new .bak on idempotent --force (TR-2.2)" "$BAKS_AFTER" "$BAKS"
AGENTS_AFTER_RUN3=$(md5sum "$TMP/AGENTS.md" | cut -d' ' -f1)
assert_eq "AGENTS.md unchanged on idempotent --force" "$AGENTS_BEFORE_RUN3" "$AGENTS_AFTER_RUN3"

e2e_done
