#!/usr/bin/env bash
#
# test_smoke_ant_teams_dry_run.sh — SPEC-001 TEST-5.1 (representative smoke).
# Traceability: TEST-5.1 ("run the upgraded initializer against this repository
# (ant-teams) in dry-run mode. Verify the output would not damage the existing
# initialization") + AC-SPEC-009 (dry-run writes nothing).
#
# SAFETY (issue #8 guardrail): the smoke test MUST use --dry-run and MUST NEVER
# modify the real ant-teams working tree. We materialize a clean copy of the
# repo's tracked files via `git archive HEAD` into a throwaway mktemp -d, add a
# .git marker (ERR-1.1), and run --dry-run there. This is faithful to "against
# this repository" (real shape, real artifacts) while keeping the operator's
# checkout untouched.
#
# ant-teams is not yet self-initialized (AGENTS.md is added by issue #11), so a
# dry-run here will report [would-write] for the missing artifacts. The smoke
# contract is simply: exit 0 AND zero file changes AND no damage to the existing
# .github-project.json / .opencode/skills/.
#
set -euo pipefail

source "$(dirname "$0")/lib/test_helpers.sh"

REPO_ROOT="$(e2e_repo_root "$0")"
INIT="$(e2e_init_script "$REPO_ROOT")"

e2e_begin "test-smoke-ant-teams-dry-run (TEST-5.1)"

# Bail out cleanly if, for some reason, this is run outside a git checkout of
# ant-teams (e.g. extracted tarball). `git archive` requires a real repo.
if ! ( cd "$REPO_ROOT" && git rev-parse --is-inside-work-tree >/dev/null 2>&1 ); then
  check FAIL "REPO_ROOT is not a git work tree; cannot git archive ($REPO_ROOT)"
  e2e_done
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# Materialize tracked files only (no .git, no untracked, no working-tree dirt).
( cd "$REPO_ROOT" && git archive HEAD | tar -x -C "$TMP" )
mkdir -p "$TMP/.git"

# Sanity: the real ant-teams shape made it into the copy. ant-teams at b2ff793
# is the SOURCE repo for the init pipeline, so its committed "existing
# initialization" is the `.opencode/skills/` source tree (no AGENTS.md and no
# committed .github-project.json yet — those land with issue #11 self-init).
# We assert the tracked source skills tree is present and let the snapshot
# diff prove the dry-run writes nothing.
assert_exists "snapshot has .opencode/skills (source repo init tree)" "$TMP/.opencode/skills"
assert_exists "snapshot has init_project_docs.sh" \
  "$TMP/.opencode/skills/project-initialization/scripts/init_project_docs.sh"

# Snapshot existing init artifacts BEFORE dry-run so we can prove undamaged.
SKILLS_BEFORE=$(e2e_snapshot_files "$TMP/.opencode/skills" | sha256sum | cut -d' ' -f1)
TREE_BEFORE=$(e2e_snapshot_files "$TMP" | sha256sum | cut -d' ' -f1)
# .github-project.json may or may not be present in the snapshot (it is an
# untracked working-tree file pending issue #11 self-init). Only hash it if
# present so the "undamaged" assertion is meaningful when it exists.
GH_BEFORE=""
if [[ -f "$TMP/.github-project.json" ]]; then
  GH_BEFORE=$(md5sum "$TMP/.github-project.json" | cut -d' ' -f1)
fi

LOG=$(mktemp)
trap 'rm -rf "$TMP" "$LOG"' EXIT

set +e
bash "$INIT" \
  --noninteractive \
  --dry-run \
  --project-dir "$TMP" \
  --worktree-root "$TMP/wt" \
  --name ant-teams-smoke \
  --description "Antpolis agentic delivery workflow source repository" \
  --repo-role tool \
  --github-owner Antpolis \
  --github-project-number 9 \
  >"$LOG" 2>&1
RC=$?
set -e

assert_exit_zero "ant-teams dry-run exit code" "$RC"

# AC-SPEC-009 / OBS-2.1: zero file changes.
TREE_AFTER=$(e2e_snapshot_files "$TMP" | sha256sum | cut -d' ' -f1)
assert_eq "ant-teams tree unchanged after dry-run" "$TREE_BEFORE" "$TREE_AFTER"

# Existing init artifacts specifically undamaged.
if [[ -n "$GH_BEFORE" ]]; then
  GH_AFTER=$(md5sum "$TMP/.github-project.json" | cut -d' ' -f1)
  assert_eq "ant-teams .github-project.json undamaged" "$GH_BEFORE" "$GH_AFTER"
else
  check OK "ant-teams has no committed .github-project.json yet (issue #11); skipped"
fi
SKILLS_AFTER=$(e2e_snapshot_files "$TMP/.opencode/skills" | sha256sum | cut -d' ' -f1)
assert_eq "ant-teams .opencode/skills undamaged" "$SKILLS_BEFORE" "$SKILLS_AFTER"

# Dry-run must emit would-write lines + dry-run summary (OBS-2).
assert_file_contains "would-write lines present" "$LOG" '\[would-write\]'
assert_file_contains "dry-run summary line" "$LOG" '\[summary\] Dry run complete'

e2e_done
