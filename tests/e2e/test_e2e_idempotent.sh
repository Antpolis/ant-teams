#!/usr/bin/env bash
#
# test_e2e_idempotent.sh — SPEC-001 TEST-2.1 `test-e2e-idempotent`.
# Traceability: AC-T7-004 ← AC-SPEC-005 (idempotent rerun produces no changes)
# + TR-2.1 + FR-6.4.
#
# Runs init twice with identical inputs on repo-node-npm. The second run must:
#   - exit 0
#   - leave every generated artifact byte-for-byte identical to the state
#     established by the FIRST run (i.e. snapshot_after_run1 must equal
#     snapshot_after_run2)
#   - emit a "No changes"/"skipped"-style summary
#
# REVIEWER FINDING (PR #19 loop 1): the previous implementation hashed the
# same files twice AFTER run 2, which compared identical-time hashes and was
# therefore vacuous — a malicious run 2 that mutated, added, or deleted any
# artifact would still pass. This rewrite captures:
#   * snapshot AFTER run 1  (the state run 2 must preserve)
#   * snapshot AFTER run 2  (what actually happened)
# and asserts they are byte-identical. It also injects a TAMPER SENTINEL
# between the two captures to prove the snapshot mechanism itself detects
# mutations (non-vacuous self-test). The sentinel restores the tampered file
# before run 2 begins.
#
set -euo pipefail

source "$(dirname "$0")/lib/test_helpers.sh"

REPO_ROOT="$(e2e_repo_root "$0")"
INIT="$(e2e_init_script "$REPO_ROOT")"

e2e_begin "test-e2e-idempotent"

TMP="$(e2e_make_fixture_repo "$(e2e_fixtures_dir "$REPO_ROOT")/repo-node-npm")"
trap 'rm -rf "$TMP"' EXIT

# Scratch dir for tamper-restore backups. Lives under $TMP/.git so it is
# excluded from every e2e_snapshot_files call (which skips .git/) — this
# keeps the backup files themselves from contaminating the snapshot.
mkdir -p "$TMP/.git/idem-selftest"

COMMON_ARGS=( --noninteractive --project-dir "$TMP" --worktree-root "$TMP/wt" \
  --name node-demo --description "Node demo" --repo-role service \
  --github-owner antpolis --github-project-number 9 )

# --- Run 1 --------------------------------------------------------------------
# Logs live under $TMP/.git/ (excluded from e2e_snapshot_files) so the
# per-run log/err files themselves do NOT contaminate the run 1→2 snapshot
# comparison below.
set +e
bash "$INIT" "${COMMON_ARGS[@]}" >"$TMP/.git/idem-selftest/run1.log" 2>"$TMP/.git/idem-selftest/run1.err"
RC1=$?
set -e
assert_exit_zero "run 1 exit code" "$RC1"

# --- Capture baseline state AFTER run 1 (the contract run 2 must preserve) ----
# This is the meaningful "before" for an idempotency assertion: it is taken
# AFTER the first run produced the post-init state, so any drift on run 2 is
# detected. (The OLD test took both samples after run 2 → no drift detection.)
SNAP_AFTER_RUN1=$(e2e_snapshot_files "$TMP" | sha256sum | cut -d' ' -f1)
GH_MD5_AFTER_RUN1=$(md5sum "$TMP/.github-project.json" | cut -d' ' -f1)
AGENTS_MD5_AFTER_RUN1=$(md5sum "$TMP/AGENTS.md" | cut -d' ' -f1)

# --- Tamper sentinel — prove the snapshot is non-vacuous ----------------------
# Mutate AGENTS.md, re-snapshot, and assert the hash differs. Then restore
# the original bytes and assert the snapshot matches baseline. Together these
# two assertions prove (a) the helper actually observes file content (i.e.
# it is not returning a constant), and (b) restoration is byte-exact so the
# subsequent run-2 comparison is sound.
#
# Regression evidence this self-test provides: a future change that, say,
# makes e2e_snapshot_files silently swallow errors or return an empty stream
# (which `2>/dev/null` makes plausible) would make SNAP_AFTER_TAMPER equal
# SNAP_AFTER_RUN1, failing the first assertion below. The OLD vacuous test
# would still report a green build under the same regression.
cp -p "$TMP/AGENTS.md" "$TMP/.git/idem-selftest/AGENTS.md.orig"
printf '\n<!-- TAMPER SENTINEL — idempotency self-test, will be restored -->\n' \
  >>"$TMP/AGENTS.md"
SNAP_AFTER_TAMPER=$(e2e_snapshot_files "$TMP" | sha256sum | cut -d' ' -f1)
assert_neq "snapshot detects mutation (non-vacuous self-test)" \
  "$SNAP_AFTER_RUN1" "$SNAP_AFTER_TAMPER"
# Restore and re-assert equality so we KNOW run 2 begins from the baseline.
cp -p "$TMP/.git/idem-selftest/AGENTS.md.orig" "$TMP/AGENTS.md"
SNAP_AFTER_RESTORE=$(e2e_snapshot_files "$TMP" | sha256sum | cut -d' ' -f1)
assert_eq "snapshot matches baseline after restore" \
  "$SNAP_AFTER_RUN1" "$SNAP_AFTER_RESTORE"

# --- Run 2 --------------------------------------------------------------------
set +e
bash "$INIT" "${COMMON_ARGS[@]}" >"$TMP/.git/idem-selftest/run2.log" 2>"$TMP/.git/idem-selftest/run2.err"
RC2=$?
set -e
assert_exit_zero "run 2 exit code (idempotent)" "$RC2"

# --- Compare run 1 → run 2 state (real idempotency contract) ------------------
GH_MD5_AFTER_RUN2=$(md5sum "$TMP/.github-project.json" | cut -d' ' -f1)
AGENTS_MD5_AFTER_RUN2=$(md5sum "$TMP/AGENTS.md" | cut -d' ' -f1)
SNAP_AFTER_RUN2=$(e2e_snapshot_files "$TMP" | sha256sum | cut -d' ' -f1)

# AC-SPEC-005 / TR-2.1: every artifact (incl. .opencode/skills/*, opencode.json,
# .opencode/.gitignore) byte-identical between run 1 and run 2.
assert_eq ".github-project.json byte-identical across runs 1→2" \
  "$GH_MD5_AFTER_RUN1" "$GH_MD5_AFTER_RUN2"
assert_eq "AGENTS.md byte-identical across runs 1→2" \
  "$AGENTS_MD5_AFTER_RUN1" "$AGENTS_MD5_AFTER_RUN2"
assert_eq "full tree snapshot identical across runs 1→2" \
  "$SNAP_AFTER_RUN1" "$SNAP_AFTER_RUN2"

# Second-run output must signal "no changes" semantics (AC-SPEC-005 wording).
if grep -iEq 'no changes|skipped|already (matches|allows|contains)' \
  "$TMP/.git/idem-selftest/run2.log"; then
  check OK "run 2 reports no-changes / skipped"
else
  check FAIL "run 2 did not report no-changes / skipped"
fi

# Second-run summary must show 0 created (no new artifacts).
assert_file_contains "run 2 summary 0 created" \
  "$TMP/.git/idem-selftest/run2.log" \
  '\[summary\] Initialization complete. 0 created'

e2e_done
