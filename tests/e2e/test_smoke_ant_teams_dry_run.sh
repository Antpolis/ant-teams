#!/usr/bin/env bash
#
# test_smoke_ant_teams_dry_run.sh — SPEC-001 TEST-5.1 (representative smoke).
# Traceability: TEST-5.1 ("run the upgraded initializer against this repository
# (ant-teams) in dry-run mode. Verify the output would not damage the existing
# initialization") + AC-SPEC-009 (dry-run writes nothing).
#
# REVIEWER FINDING (PR #19 loop 1): the previous implementation materialised a
# `git archive HEAD` snapshot of ant-teams into a throwaway temp dir and ran
# --dry-run against THAT copy. Because `git archive HEAD` excludes untracked
# files, the smoke test silently excluded `.github-project.env` whenever it
# was untracked at HEAD (which it is today pending issue #11 self-init), so
# the test could pass with false confidence. This rewrite exercises the LIVE
# ant-teams checkout directly and independently proves zero mutation via:
#
#   1. `git status --porcelain` snapshot BEFORE and AFTER  — catches any
#      tracked-file modification OR any new untracked non-ignored file.
#   2. `git ls-files -z | xargs -0 sha256sum` of every TRACKED file BEFORE
#      and AFTER — catches byte-level modification of any committed file,
#      independent of git's mtime cache.
#   3. `git ls-files --others --exclude-standard` list BEFORE and AFTER —
#      catches any new untracked non-ignored file init might create.
#   4. Direct sha256 of every init-managed artifact (AGENTS.md if present,
#      .github-project.env if present, the entire templates/opencode/skills/ tree)
#      BEFORE and AFTER — catches mutations even when the path is untracked
#      or ignored (e.g. templates/opencode/.gitignore'd entries), where git status
#      would be silent.
#   5. sourceable-env validation of `.github-project.env` when present
#      (AC-SPEC-008): sourceable with canonical ANT_TEAM_* keys present.
#
# Safety: init is invoked with `--dry-run`, which the script guarantees writes
# nothing (OBS-2). The init helper's own TEMP_DIR is allocated under the OS
# tmpdir (NOT inside --project-dir), and the atomic-write primitives are
# short-circuited in dry-run, so no `.opencode/...` temp file is ever created
# inside the live checkout. The independent git/sha256 snapshots above are
# defense-in-depth: if a future regression broke dry-run's no-write promise,
# this test would catch it BEFORE the operator's working tree was contaminated.
#
# `--worktree-root` is set to a tmp path OUTSIDE the live checkout so that
# even the would-write messages reference a path the operator's tree never
# sees. The init script only uses it for path computation in dry-run.
#
# Regression evidence this rewrite provides (vs the OLD `git archive` test):
#   * OLD: dry-run mutating the untracked `.github-project.env` → MISSED
#     (git archive excludes untracked). NEW: caught by check #4 (direct hash).
#   * OLD: dry-run creating a new untracked artifact in the live checkout →
#     MISSED (test ran against a temp copy). NEW: caught by checks #1 and #3.
#   * OLD: dry-run modifying a tracked file (e.g. AGENTS.md post-#11) →
#     MISSED on the live checkout (temp copy had no working-tree state).
#     NEW: caught by checks #1, #2, and #4.
#
set -euo pipefail

source "$(dirname "$0")/lib/test_helpers.sh"

REPO_ROOT="$(e2e_repo_root "$0")"
INIT="$(e2e_init_script "$REPO_ROOT")"

e2e_begin "test-smoke-ant-teams-dry-run (TEST-5.1)"

# Bail cleanly if, for some reason, this is run outside a git checkout of
# ant-teams (e.g. extracted tarball). All downstream git assertions require a
# real work tree.
if ! ( cd "$REPO_ROOT" && git rev-parse --is-inside-work-tree >/dev/null 2>&1 ); then
  check FAIL "REPO_ROOT is not a git work tree; cannot run live smoke ($REPO_ROOT)"
  e2e_done
  exit 0
fi

# Sanity: the live ant-teams shape really is there. The smoke test's value
# depends on exercising the actual repo, so a missing source init tree would
# make the test trivially pass without exercising anything.
assert_exists "live checkout has templates/opencode/skills (source repo init tree)" \
  "$REPO_ROOT/templates/opencode/skills"
assert_exists "live checkout has init_project_docs.sh" \
  "$REPO_ROOT/templates/opencode/skills/project-initialization/scripts/init_project_docs.sh"

LOG=$(mktemp)
trap 'rm -f "$LOG" "$LOG.gh-validate"' EXIT

# Worktree-root points OUTSIDE the live checkout so the would-write path
# computation never references a directory the operator's tree hosts. Use a
# per-PID tmp path so concurrent test runs cannot collide.
WTROOT="$(mktemp -d -t ant-teams-smoke-wtroot.XXXXXX)"
trap 'rm -f "$LOG" "$LOG.gh-validate"; rm -rf "$WTROOT"' EXIT

# --- Capture BEFORE state from the LIVE checkout ------------------------------

# Each multi-line capture is reduced to a single sha256 so the per-assertion
# output stays readable AND the comparison is exact (any byte change in any
# line of the stream flips the resulting hash). The full stream is never
# stored at rest, only in-memory inside $().

# (1) Tracked-file hash stream (deterministic: git ls-files is sorted, sha256sum
#     output is `<hash>\t<path>`, then `sort` reorders to a stable total order,
#     and we reduce the whole stream to a single sha256).
TRACKED_HASH_BEFORE=$( ( cd "$REPO_ROOT" \
    && git ls-files -z | xargs -0 sha256sum 2>/dev/null ) | sort | sha256sum | cut -d' ' -f1 )

# (2) Untracked non-ignored file list (any new file init creates here would
#     show up as a list delta → hash delta).
UNTRACKED_LIST_BEFORE=$( cd "$REPO_ROOT" \
  && git ls-files --others --exclude-standard | sort | sha256sum | cut -d' ' -f1 )

# (3) Git status porcelain — catches tracked modifications + new untracked
#     non-ignored files in a single stream.
GIT_STATUS_BEFORE=$( cd "$REPO_ROOT" && git status --porcelain=v1 | sort | sha256sum | cut -d' ' -f1 )

# (4) Direct hashes of every init-managed artifact. These are checked
#     independently of git so that mutations to untracked/ignored init
#     artifacts are NOT silently missed. AGENTS.md may not exist yet
#     (issue #11 self-init pending); hash when present.
AGENTS_PATH="$REPO_ROOT/AGENTS.md"
GH_PATH="$REPO_ROOT/.github-project.env"
SKILLS_TREE_BEFORE=$( e2e_snapshot_files "$REPO_ROOT/templates/opencode/skills" \
  | sha256sum | cut -d' ' -f1 )
AGENTS_HASH_BEFORE=""
if [[ -f "$AGENTS_PATH" ]]; then
  AGENTS_HASH_BEFORE=$( sha256sum "$AGENTS_PATH" | cut -d' ' -f1 )
fi
GH_HASH_BEFORE=""
GH_ENV_VALID_BEFORE="(no .github-project.env)"
if [[ -f "$GH_PATH" ]]; then
  GH_HASH_BEFORE=$( sha256sum "$GH_PATH" | cut -d' ' -f1 )
fi

# (5) Env conformance pre-flight (AC-SPEC-008). When present, the committed
#     .github-project.env must source cleanly under `set -euo pipefail` and
#     carry the canonical ANT_TEAM_* keys (owner + Workflow State field +
#     option IDs). This is the "validate .github-project.env when present"
#     half of TEST-5.1: the prior implementation conditionally SKIPPED this
#     file, so a malformed config would not have failed the smoke.
if [[ -n "$GH_HASH_BEFORE" ]]; then
  if bash -c "set -euo pipefail; source '$GH_PATH'; test -n \"\${ANT_TEAM_GITHUB_OWNER:-}\" && test -n \"\${ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID:-}\" && test -n \"\${ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_READY_ID:-}\"" >/dev/null 2>&1; then
    check OK ".github-project.env sourceable with canonical keys (AC-SPEC-008)"
    GH_ENV_VALID_BEFORE="valid"
  else
    check FAIL ".github-project.env missing canonical ANT_TEAM_* keys"
    GH_ENV_VALID_BEFORE="invalid"
  fi
fi

# --- Run init --dry-run against the LIVE checkout -----------------------------
set +e
bash "$INIT" \
  --noninteractive \
  --dry-run \
  --project-dir "$REPO_ROOT" \
  --worktree-root "$WTROOT" \
  --name ant-teams-smoke \
  --description "Antpolis agentic delivery workflow source repository" \
  --repo-role tool \
  --github-owner Antpolis \
  --github-project-number 9 \
  >"$LOG" 2>&1
RC=$?
set -e

assert_exit_zero "ant-teams live dry-run exit code" "$RC"

# --- Capture AFTER state and assert no mutation -------------------------------

TRACKED_HASH_AFTER=$( ( cd "$REPO_ROOT" \
    && git ls-files -z | xargs -0 sha256sum 2>/dev/null ) | sort | sha256sum | cut -d' ' -f1 )
assert_eq "tracked file hashes unchanged (live checkout)" \
  "$TRACKED_HASH_BEFORE" "$TRACKED_HASH_AFTER"

UNTRACKED_LIST_AFTER=$( cd "$REPO_ROOT" \
  && git ls-files --others --exclude-standard | sort | sha256sum | cut -d' ' -f1 )
assert_eq "untracked non-ignored file list unchanged (live checkout)" \
  "$UNTRACKED_LIST_BEFORE" "$UNTRACKED_LIST_AFTER"

GIT_STATUS_AFTER=$( cd "$REPO_ROOT" && git status --porcelain=v1 | sort | sha256sum | cut -d' ' -f1 )
assert_eq "git status porcelain unchanged (live checkout)" \
  "$GIT_STATUS_BEFORE" "$GIT_STATUS_AFTER"

# Init-managed artifacts: byte-identical before/after, AND present (not
# silently deleted by a misrouted dry-run branch).
SKILLS_TREE_AFTER=$( e2e_snapshot_files "$REPO_ROOT/templates/opencode/skills" \
  | sha256sum | cut -d' ' -f1 )
assert_eq "templates/opencode/skills tree byte-identical (live checkout)" \
  "$SKILLS_TREE_BEFORE" "$SKILLS_TREE_AFTER"

if [[ -n "$AGENTS_HASH_BEFORE" ]]; then
  AGENTS_HASH_AFTER=$( sha256sum "$AGENTS_PATH" | cut -d' ' -f1 )
  assert_eq "AGENTS.md byte-identical (live checkout)" \
    "$AGENTS_HASH_BEFORE" "$AGENTS_HASH_AFTER"
else
  check OK "no AGENTS.md in live checkout (issue #11 self-init pending) — smoke scope is dry-run zero-change"
fi

if [[ -n "$GH_HASH_BEFORE" ]]; then
  GH_HASH_AFTER=$( sha256sum "$GH_PATH" | cut -d' ' -f1 )
  assert_eq ".github-project.env byte-identical (live checkout)" \
    "$GH_HASH_BEFORE" "$GH_HASH_AFTER"
  # Re-source the env post-run: a dry-run must not corrupt it even if a future
  # regression attempted a partial write.
  if [[ "$GH_ENV_VALID_BEFORE" == "valid" ]]; then
    if bash -c "set -euo pipefail; source '$GH_PATH'; test -n \"\${ANT_TEAM_GITHUB_OWNER:-}\"" >/dev/null 2>&1; then
      check OK ".github-project.env still sourceable after dry-run"
    else
      check FAIL ".github-project.env corrupted by dry-run"
    fi
  fi
else
  check OK "no .github-project.env in live checkout — smoke scope is dry-run zero-change"
fi

# Dry-run must emit would-write lines + dry-run summary (OBS-2).
assert_file_contains "would-write lines present" "$LOG" '\[would-write\]'
assert_file_contains "dry-run summary line" "$LOG" '\[summary\] Dry run complete'

# Sanity: the live checkout is the ant-teams source repo, so the dry-run must
# specifically reference an ant-teams-shaped would-write. The init source
# skills tree is already present, so would-write lines must NOT include a
# would-write of `init_project_docs.sh` (it's already there); they SHOULD
# reference AGENTS.md (which issue #11 will commit) and/or .github-project.env
# (untracked today) and/or .opencode/.gitignore. This is a smoke-grade
# sanity check, not an exact-shape assertion, so it stays loose.
if grep -qE '\[would-write\] (AGENTS\.md|\.github-project\.env|\.opencode/)' "$LOG"; then
  check OK "would-write lines reference init-managed ant-teams artifacts"
else
  check FAIL "would-write lines did not reference any init-managed ant-teams artifact"
fi

e2e_done
