#!/usr/bin/env bash
#
# test_migration_legacy_fields.sh — SPEC-001 TEST-3.1 (focused).
# Traceability: AC-SPEC-004 + AC-SPEC-008 + ARCH-003 backward-compatibility
# contract ("Legacy-initialized repo → upgraded init" row).
#
# Focus: every legacy field in .github-project.json survives the upgrade
# verbatim, and the .opencode/opencode.json the fixture ships keeps its
# pre-existing permission entries (FR-6.2). This complements
# test_e2e_legacy_migrate.sh, which checks the broader agent.md/AGENTS.md
# coexistence; here we drill into the additive-only preservation guarantee.
#
set -euo pipefail

source "$(dirname "$0")/lib/test_helpers.sh"

REPO_ROOT="$(e2e_repo_root "$0")"
INIT="$(e2e_init_script "$REPO_ROOT")"

e2e_begin "test-migration-legacy-fields (TEST-3.1)"

TMP="$(e2e_make_fixture_repo "$(e2e_fixtures_dir "$REPO_ROOT")/repo-legacy-init")"
trap 'rm -rf "$TMP"' EXIT

# The legacy fixture ships .opencode/opencode.json with a pre-existing
# `agent` entry that must survive (FR-6.2 "never remove ... agent definitions").
OC_BEFORE=$(cat "$TMP/.opencode/opencode.json")
assert_exists "legacy opencode.json present" "$TMP/.opencode/opencode.json"

set +e
bash "$INIT" \
  --noninteractive \
  --project-dir "$TMP" \
  --worktree-root "$TMP/wt" \
  --name legacy-fields \
  --description "Legacy fields migration" \
  --repo-role service \
  --github-owner antpolis \
  --github-project-number 9 \
  >"$TMP/stdout.log" 2>"$TMP/stderr.log"
RC=$?
set -e

assert_exit_zero "legacy migration exit code" "$RC"

# --- TEST-3.1: every legacy .github-project.json field survives ---------------
# The legacy fixture's values (from tests/fixtures/repo-legacy-init) are the
# source of truth; assert each is present verbatim after the upgrade.
assert_file_contains "owner=antpolis kept"          "$TMP/.github-project.json" '"owner": "antpolis"'
assert_file_contains "owner_type=org kept"          "$TMP/.github-project.json" '"owner_type": "org"'
assert_file_contains "repo=antpolis/legacy-demo"    "$TMP/.github-project.json" '"antpolis/legacy-demo"'
assert_file_contains "project.number=1 kept"        "$TMP/.github-project.json" '"number": 1'
assert_file_contains "fields.status=PVTSSF_LEGACY"  "$TMP/.github-project.json" '"PVTSSF_LEGACY"'
assert_file_contains "status_options.todo kept"     "$TMP/.github-project.json" '"f75ad846"'
assert_file_contains "status_options.in-progress"   "$TMP/.github-project.json" '"61e4505c"'
assert_file_contains "status_options.in-review"     "$TMP/.github-project.json" '"abcdef12"'
assert_file_contains "status_options.done"          "$TMP/.github-project.json" '"1234abcd"'

# New DM-1 fields are ADDITIVE (ARCH-003 guarantee 2: strict additivity).
assert_file_contains "worktreeRoot added"           "$TMP/.github-project.json" '"worktreeRoot"'
assert_file_contains "identity block added"         "$TMP/.github-project.json" '"identity"'
assert_file_contains "boundaries block added"       "$TMP/.github-project.json" '"boundaries"'
assert_file_contains "initMeta block added"         "$TMP/.github-project.json" '"initMeta"'

# Result is valid JSON (AC-SPEC-008).
if node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$TMP/.github-project.json" >/dev/null 2>&1; then
  check OK "post-migration .github-project.json valid JSON"
else
  check FAIL "post-migration .github-project.json invalid JSON"
fi

# --- FR-6.2: existing .opencode/opencode.json entries preserved ---------------
# Legacy fixture shipped `"agent": "builder"`. The init must NOT remove it.
assert_file_contains "opencode.json keeps legacy 'agent' entry" \
  "$TMP/.opencode/opencode.json" '"agent"'
# And it must have gained the worktree external_directory entry (ARCH-003 Artifact 4).
assert_file_contains "opencode.json gained external_directory" \
  "$TMP/.opencode/opencode.json" '"external_directory"'

e2e_done
