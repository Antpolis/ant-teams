#!/usr/bin/env bash
#
# test_e2e_noninteractive_missing.sh — SPEC-001 TEST-2.1
# `test-e2e-noninteractive-missing`. Traceability: AC-T7-003 ← AC-SPEC-010
# (missing noninteractive flags produce a clear error) + FR-4.3 + ERR-4.1.
#
# Drives the script with --noninteractive minus --github-owner. Expected:
# exit code 1; stderr names the missing flag; NO file is created or modified.
#
set -euo pipefail

source "$(dirname "$0")/lib/test_helpers.sh"

REPO_ROOT="$(e2e_repo_root "$0")"
INIT="$(e2e_init_script "$REPO_ROOT")"

e2e_begin "test-e2e-noninteractive-missing"

TMP="$(e2e_make_fixture_repo "$(e2e_fixtures_dir "$REPO_ROOT")/repo-node-npm")"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/stdout.log"; ERR="$TMP/stderr.log"
# Intentionally omit --github-owner while passing --name + --github-project-number.
set +e
bash "$INIT" \
  --noninteractive \
  --project-dir "$TMP" \
  --name node-demo \
  --github-project-number 9 \
  >"$OUT" 2>"$ERR"
RC=$?
set -e

# AC-T7-003 / AC-SPEC-010: exit 1.
assert_exit_nonzero "missing flag exits non-zero" "$RC"

# ERR-4.1: stderr names the missing flag.
assert_file_contains "stderr names missing --github-owner" "$ERR" '\[error\]'
assert_file_contains "stderr lists github-owner" "$ERR" 'github-owner'

# No files created (FR-4.3: "no files are created"). Snapshot the dir: only the
# original fixture content (+ .git marker + our log files) must be present.
assert_not_exists "no AGENTS.md written" "$TMP/AGENTS.md"
assert_not_exists "no .opencode/skills written" "$TMP/.opencode/skills"
# .github-project.json must NOT have been created by the failed run (the fixture
# copy for repo-node-npm does not ship one).
assert_not_exists "no .github-project.json written" "$TMP/.github-project.json"

e2e_done
