#!/usr/bin/env bash
#
# test_migration_old_script.sh — SPEC-001 TEST-3.2 (focused) + AC-T7-007.
# Traceability: AC-T7-007 ← TEST-3.2 + ARCH-003 backward-compatibility matrix
# ("Already-upgraded repo → run old init" row) + SPEC-001 compatibility matrix.
#
# Scenario: take a legacy-initialized repo, upgrade it with the new init, then
# run the OLD `setup_project_docs.sh` against the upgraded tree. The old script
# must NOT damage any new artifact:
#   - .github-project.json (full DM-1 schema) preserved verbatim
#   - AGENTS.md (new) preserved verbatim
#   - .opencode/skills/ (3 required skills) preserved
#   - legacy agent.md preserved (old script skips existing)
#
# This is the rollback-safety / legacy-coexistence test: an operator who runs
# the old script after upgrade does not lose any new-init artifact.
#
set -euo pipefail

source "$(dirname "$0")/lib/test_helpers.sh"

REPO_ROOT="$(e2e_repo_root "$0")"
INIT="$(e2e_init_script "$REPO_ROOT")"
SETUP="$(e2e_setup_script "$REPO_ROOT")"

e2e_begin "test-migration-old-script (TEST-3.2)"

TMP="$(e2e_make_fixture_repo "$(e2e_fixtures_dir "$REPO_ROOT")/repo-legacy-init")"
trap 'rm -rf "$TMP"' EXIT

# 1. Upgrade the legacy repo with the new init (creates AGENTS.md, full schema,
#    copies skills, preserves agent.md). Use --migrate-agent-md so agent.md is
#    carried forward as the legacy coexistence artifact.
set +e
bash "$INIT" --noninteractive --migrate-agent-md \
  --project-dir "$TMP" --worktree-root "$TMP/wt" \
  --name legacy-coexist --description "Legacy coexistence" --repo-role service \
  --github-owner antpolis --github-project-number 9 \
  >"$TMP/upgrade.log" 2>&1
RC_UP=$?
set -e
assert_exit_zero "new init on legacy repo exit code" "$RC_UP"

# Snapshot the upgraded artifacts BEFORE running the old script.
GH_BEFORE=$(md5sum "$TMP/.github-project.json" | cut -d' ' -f1)
AGENTS_BEFORE=$(md5sum "$TMP/AGENTS.md" | cut -d' ' -f1)
AGENT_MD_BEFORE=$(md5sum "$TMP/agent.md" | cut -d' ' -f1)
SKILLS_HASH=$(e2e_snapshot_files "$TMP/.opencode/skills" | sha256sum | cut -d' ' -f1)

# 2. Run the OLD setup_project_docs.sh against the upgraded tree. It runs with
#    CWD = target dir (its contract uses relative paths like `docs/`, agent.md).
set +e
( cd "$TMP" && bash "$SETUP" docs >"$TMP/oldscript.log" 2>&1 )
RC_OLD=$?
set -e
assert_exit_zero "old setup_project_docs.sh exit code" "$RC_OLD"

# 3. TEST-3.2: new artifacts undamaged.
# .github-project.json: old script must skip it (it does — `copy_if_missing`).
GH_AFTER=$(md5sum "$TMP/.github-project.json" | cut -d' ' -f1)
assert_eq ".github-project.json undamaged by old script" "$GH_BEFORE" "$GH_AFTER"
# And the DM-1 schema additions are still present (not regressed to placeholder).
assert_file_contains "worktreeRoot survives old script" "$TMP/.github-project.json" '"worktreeRoot"'
assert_file_contains "identity survives old script" "$TMP/.github-project.json" '"identity"'

# AGENTS.md: old script never touches it (it only creates lowercase agent.md).
AGENTS_AFTER=$(md5sum "$TMP/AGENTS.md" | cut -d' ' -f1)
assert_eq "AGENTS.md undamaged by old script" "$AGENTS_BEFORE" "$AGENTS_AFTER"

# agent.md: old script skips because it exists (copy_if_missing). Byte-identical.
AGENT_MD_AFTER=$(md5sum "$TMP/agent.md" | cut -d' ' -f1)
assert_eq "legacy agent.md undamaged by old script" "$AGENT_MD_BEFORE" "$AGENT_MD_AFTER"

# Skills tree: old script does not touch .opencode/skills/.
SKILLS_HASH_AFTER=$(e2e_snapshot_files "$TMP/.opencode/skills" | sha256sum | cut -d' ' -f1)
assert_eq ".opencode/skills undamaged by old script" "$SKILLS_HASH" "$SKILLS_HASH_AFTER"
assert_eq "still exactly 3 skills after old script" "$(e2e_count_skill_dirs "$TMP")" "3"

# The old script should have logged that it skipped .github-project.json
# (its contract prints "Exists  .github-project.json").
assert_file_contains "old script logged skip of existing .github-project.json" \
  "$TMP/oldscript.log" 'Exists'

e2e_done
