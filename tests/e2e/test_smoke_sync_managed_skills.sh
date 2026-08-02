#!/usr/bin/env bash
#
# test_smoke_sync_managed_skills.sh — SPEC-002-T1 regression smoke for the
# PR #26 review findings (issue #22, review loops 2 and 3).
#
# Standalone (not wired into run_e2e_tests.sh, which is SPEC-001-T7 scoped).
# Formal cross-cutting coverage is owned by issue #24 (SPEC-002-T3); this
# script is the interim regression net for the fixes below so they do not
# silently regress before #24 lands.
#
# Covered regressions:
#   F1  Manifest-missing recovery (DM-1.2 / ERR-5.1a): deleting .manifest.json
#       and re-running reclaims existing source-named directories (NOOP) and
#       rewrites a fresh manifest, instead of skipping them all as collisions.
#   F2  Unmanaged regular file at a managed target name (FR-11.4 / SEC-5.1):
#       warn + skip the entry with exit 0, instead of aborting with exit 5
#       ("mkdir: File exists").
#   F3  Permission preservation on update (SEC-3.2): updating an existing
#       managed file preserves the operator's prior mode under a security
#       floor (strip group/other write + special bits); fresh install and
#       --force still apply source-derived mode (SEC-3.1).
#   F4  Non-directory ancestor inside the managed write path (FR-11.4 /
#       SEC-5.1, review loop 3): a regular file at an INTERMEDIATE managed
#       path (e.g., .../<entry>/scripts turned into a file) makes the later
#       mkdir abort. Any non-directory ancestor anywhere in the write path
#       must warn + skip per file (exit 0), and clearing the block must
#       restore normal install.
#
# All runs use a temp HOME and a temp repo copy (for source-mutation tests) so
# the operator's real ~/.agents/skills and the real source tree are untouched.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SYNC="$REPO_ROOT/scripts/sync-managed-skills.sh"

if [[ ! -x "$SYNC" ]]; then
  echo "FATAL: sync script not found at $SYNC" >&2
  exit 1
fi

PASS=0
FAIL=0
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t smsmoke)"
cleanup() { rm -rf "$WORK" 2>/dev/null || true; }
trap cleanup EXIT

# Portable octal mode of a file (e.g. "755", "644").
mode_of() {
  local f="$1"
  if stat -c %a "$f" 2>/dev/null; then return 0; fi
  stat -f %Lp "$f" 2>/dev/null
}

assert_eq() {  # <label> <actual> <expected>
  if [[ "$2" == "$3" ]]; then
    printf '  [PASS] %s: %s\n' "$1" "$2"; PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s: got %s, expected %s\n' "$1" "$2" "$3" >&2
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {  # <label> <file> <substring>
  if grep -qF "$3" "$2"; then
    printf '  [PASS] %s: present\n' "$1"; PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s: %s not found in output\n' "$1" "$3" >&2
    FAIL=$((FAIL + 1))
  fi
}

assert_count_line() {  # <label> <output-file> <substring> <expected-count>
  local got
  got="$(grep -cF "$3" "$2" || true)"
  assert_eq "$1" "$got" "$4"
}

assert_ge() {  # <label> <actual> <min>
  if (( $2 >= $3 )); then
    printf '  [PASS] %s: %s >= %s\n' "$1" "$2" "$3"; PASS=$((PASS + 1))
  else
    printf '  [FAIL] %s: got %s, expected >= %s\n' "$1" "$2" "$3" >&2
    FAIL=$((FAIL + 1))
  fi
}

echo "========================================================="
echo "SPEC-002-T1 regression smoke (PR #26 review findings)"
echo "========================================================="

# ---------------------------------------------------------------------------
# F1 — manifest-missing recovery.
# ---------------------------------------------------------------------------
echo
echo "--- F1: manifest-missing recovery ---"
HOME1="$WORK/h1"; mkdir -p "$HOME1"
export HOME="$HOME1"
OUT="$WORK/f1.out"
"$SYNC" >"$OUT" 2>&1 || { echo "F1 fresh install failed (exit $?)"; cat "$OUT"; FAIL=$((FAIL + 1)); }
assert_count_line "F1 fresh install collisions" "$OUT" "[SKIP collision]" 0
assert_contains    "F1 fresh manifest written"  "$HOME1/.agents/skills/.manifest.json" "managed_entries"

# Delete the manifest, re-run: existing dirs must be reclaimed, not skipped.
rm -f "$HOME1/.agents/skills/.manifest.json"
# Pre-seed a truly unmanaged dir whose name does NOT match any source entry.
mkdir -p "$HOME1/.agents/skills/my-custom-skill"
echo "operator content" > "$HOME1/.agents/skills/my-custom-skill/keep.md"
"$SYNC" >"$OUT" 2>&1
rc=$?
assert_eq "F1 recovery exit code" "$rc" 0
assert_count_line "F1 recovery collisions (expect 0)" "$OUT" "[SKIP collision]" 0
assert_count_line "F1 recovery NOOPs (expect 34)"    "$OUT" "[NOOP]" 34
assert_contains    "F1 recovery manifest rewritten" "$HOME1/.agents/skills/.manifest.json" "managed_entries"
assert_eq "F1 unmanaged content preserved" \
  "$(cat "$HOME1/.agents/skills/my-custom-skill/keep.md" 2>/dev/null || echo MISSING)" \
  "operator content"

# Recovery with a locally-modified managed file: preserved by default, force overwrites.
rm -f "$HOME1/.agents/skills/.manifest.json"
md="$HOME1/.agents/skills/documentation-standard/SKILL.md"
echo "local edit" >> "$md"
"$SYNC" >"$OUT" 2>&1
rc=$?
assert_eq "F1 modified-recovery exit code" "$rc" 0
assert_count_line "F1 modified preserved (expect 1)" "$OUT" "[SKIP modified]" 1
assert_eq "F1 modified content preserved" \
  "$(tail -n1 "$md")" "local edit"
# --force restores it from source.
"$SYNC" --force >"$OUT" 2>&1
rc=$?
assert_eq "F1 force exit code" "$rc" 0
assert_count_line "F1 force overwrite (expect >=1)" "$OUT" "[FORCE overwrite]" 1
# "local edit" must be gone after force restores the file from source.
if grep -qF "local edit" "$md"; then
  printf '  [FAIL] F1 force content restored: local edit still present\n' >&2; FAIL=$((FAIL + 1))
else
  printf '  [PASS] F1 force content restored: local edit gone\n'; PASS=$((PASS + 1))
fi

# ---------------------------------------------------------------------------
# F2 — unmanaged regular file at a managed target name.
# ---------------------------------------------------------------------------
echo
echo "--- F2: unmanaged regular file collision (skip, not abort) ---"
HOME2="$WORK/h2"; mkdir -p "$HOME2/.agents/skills"
export HOME="$HOME2"
# Pre-create a regular file at a real source entry name.
echo "do-not-clobber" > "$HOME2/.agents/skills/documentation-standard"
OUT="$WORK/f2.out"
"$SYNC" >"$OUT" 2>&1
rc=$?
assert_eq "F2 exit code (expect 0, was 5 before fix)" "$rc" 0
assert_count_line "F2 skip-collision for documentation-standard" "$OUT" "[SKIP collision]" 1
assert_eq "F2 unmanaged file untouched" \
  "$(cat "$HOME2/.agents/skills/documentation-standard")" "do-not-clobber"
# documentation-standard must NOT be recorded as managed (collision skip).
_manifest="$HOME2/.agents/skills/.manifest.json"
if node -e 'const m=require(process.argv[1]); console.log(m.managed_entries["documentation-standard"]?"present":"absent")' \
     "$_manifest" 2>/dev/null | grep -q present; then
  printf '  [FAIL] F2 documentation-standard should not be in manifest\n' >&2; FAIL=$((FAIL + 1))
else
  printf '  [PASS] F2 documentation-standard not in manifest\n'; PASS=$((PASS + 1))
fi
# A sibling entry must still install normally (collision is per-entry, not fatal).
if [[ -f "$HOME2/.agents/skills/agent-communication-log/SKILL.md" ]]; then
  printf '  [PASS] F2 sibling entry installed\n'; PASS=$((PASS + 1))
else
  printf '  [FAIL] F2 sibling entry (agent-communication-log) not installed\n' >&2; FAIL=$((FAIL + 1))
fi

# ---------------------------------------------------------------------------
# F3 — permission preservation on update (SEC-3.2), source-derived on fresh/force.
# ---------------------------------------------------------------------------
echo
echo "--- F3: permission preservation on update ---"
# Temp repo copy so we can mutate source to drive the UPDATE path.
TREPO="$WORK/repo"; mkdir -p "$TREPO/scripts" "$TREPO/.opencode"
cp "$SYNC" "$TREPO/scripts/sync-managed-skills.sh"
cp -R "$REPO_ROOT/.opencode/skills"   "$TREPO/.opencode/skills"
cp -R "$REPO_ROOT/.opencode/commands" "$TREPO/.opencode/commands"
TSCRIPT="$TREPO/scripts/sync-managed-skills.sh"
chmod +x "$TSCRIPT"

HOME3="$WORK/h3"; mkdir -p "$HOME3"
export HOME="$HOME3"
OUT="$WORK/f3.out"
"$TSCRIPT" >"$OUT" 2>&1 || { echo "F3 fresh install failed"; cat "$OUT"; FAIL=$((FAIL + 1)); }

src_sh="$TREPO/.opencode/skills/project-initialization/scripts/init_project_docs.sh"
src_md="$TREPO/.opencode/skills/documentation-standard/SKILL.md"
tgt_sh="$HOME3/.agents/skills/project-initialization/scripts/init_project_docs.sh"
tgt_md="$HOME3/.agents/skills/documentation-standard/SKILL.md"

# Fresh install must apply source-derived mode (SEC-3.1): .sh -> 755, .md -> 644.
assert_eq "F3 fresh .sh mode (0755)" "$(mode_of "$tgt_sh")" "755"
assert_eq "F3 fresh .md mode (0644)" "$(mode_of "$tgt_md")" "644"

# 3a: UPDATE preserves operator mode under the security floor.
#     Tighten .sh to 0600 (preserved), loosen .md to 0666 (floored to 0644).
chmod 0600 "$tgt_sh"
chmod 0666 "$tgt_md"
# Change SOURCE content (not target) so source_hash != manifest_hash (UPDATE path).
printf '# smoke update marker\n' >> "$src_sh"
printf '<!-- smoke update marker -->\n' >> "$src_md"
"$TSCRIPT" >"$OUT" 2>&1
rc=$?
assert_eq "F3 update exit code" "$rc" 0
assert_count_line "F3 update writes (>=2)" "$OUT" "[UPDATE]" 2
assert_eq "F3 update .sh preserved (0600)" "$(mode_of "$tgt_sh")" "600"
assert_eq "F3 update .md floored (0644)"   "$(mode_of "$tgt_md")" "644"
assert_contains "F3 update .sh content applied" "$tgt_sh" "smoke update marker"
assert_contains "F3 update .md content applied" "$tgt_md" "smoke update marker"

# 3b: --force applies source-derived mode (SEC-3.1) to a modified managed file.
# After 3a the .sh is mode 0600 (owner rw); overwrite its content to make it
# locally modified, then --force must restore source content AND src_mode 0755.
echo "manual junk override" > "$tgt_sh"   # locally modify (current != manifest)
"$TSCRIPT" --force >"$OUT" 2>&1
rc=$?
assert_eq "F3 force exit code" "$rc" 0
assert_count_line "F3 force overwrite (.sh)" "$OUT" "[FORCE overwrite]" 1
assert_eq "F3 force .sh mode (0755)" "$(mode_of "$tgt_sh")" "755"
# Content restored from source (still contains the smoke marker we appended).
assert_contains "F3 force .sh content restored" "$tgt_sh" "smoke update marker"

# ---------------------------------------------------------------------------
# F4 — non-directory ancestor inside the managed write path (nested collision).
#     Review loop 3 blocker: F2 only covered a top-level entry name. A regular
#     file at an INTERMEDIATE managed path (e.g., .../project-initialization/scripts
#     turned into a file) made write_target_file's `mkdir -p` abort with exit 5.
#     Any non-directory ancestor anywhere in the write path must warn+skip.
# ---------------------------------------------------------------------------
echo
echo "--- F4: nested non-directory ancestor in write path ---"
HOME4="$WORK/h4"; mkdir -p "$HOME4"
export HOME="$HOME4"
OUT="$WORK/f4.out"
ERR="$WORK/f4.err"
"$SYNC" >"$OUT" 2>"$ERR" || { echo "F4 fresh install failed (exit $?)"; cat "$ERR"; FAIL=$((FAIL + 1)); }
assert_count_line "F4 fresh install collisions" "$ERR" "[SKIP collision]" 0

# Number of source files that live under project-initialization/scripts/. Every
# one of them must be skipped once that intermediate dir is replaced by a file.
blocked_subdir_rel="project-initialization/scripts"
expected_skips="$(find "$REPO_ROOT/.opencode/skills/$blocked_subdir_rel" -type f 2>/dev/null | wc -l | tr -d ' ')"
assert_ge "F4 source has files under blocked subdir" "$expected_skips" 1

# Replace the intermediate directory with a regular file (the reviewer repro).
block_path="$HOME4/.agents/skills/$blocked_subdir_rel"
rm -rf "$block_path"
printf 'blocked-content\n' > "$block_path"

# Re-run: must exit 0 (was 5 before fix) and skip every blocked file.
"$SYNC" >"$OUT" 2>"$ERR"
rc=$?
assert_eq "F4 nested-collision exit code (expect 0, was 5 before fix)" "$rc" 0
assert_eq "F4 nested skip-collision count (== source files under blocked dir)" \
  "$(grep -cF "[SKIP collision]" "$ERR" || true)" "$expected_skips"
# The skip messages must reference the nested files, not the entry name alone.
assert_ge "F4 nested skip lines name the blocked subpaths" \
  "$(grep -cF "[SKIP collision] project-initialization/scripts/" "$ERR" || true)" 1
# The blocking regular file itself is unmanaged content -> must be untouched.
assert_eq "F4 blocking file untouched" \
  "$(cat "$block_path")" "blocked-content"
# A top-level file in the SAME entry must still reconcile (NOOP), proving the
# entry was not wholesale-aborted by the deeper collision.
if [[ -f "$HOME4/.agents/skills/project-initialization/SKILL.md" ]]; then
  printf '  [PASS] F4 sibling top-level file still present\n'; PASS=$((PASS + 1))
else
  printf '  [FAIL] F4 sibling top-level SKILL.md missing\n' >&2; FAIL=$((FAIL + 1))
fi
# A different entry entirely must still install normally.
if [[ -f "$HOME4/.agents/skills/documentation-standard/SKILL.md" ]]; then
  printf '  [PASS] F4 unrelated entry installed\n'; PASS=$((PASS + 1))
else
  printf '  [FAIL] F4 unrelated entry (documentation-standard) missing\n' >&2; FAIL=$((FAIL + 1))
fi
# Manifest must still be valid and record the partly-managed entry.
if node -e 'const m=require(process.argv[1]); if(!m.managed_entries["project-initialization"]) process.exit(1)' \
     "$HOME4/.agents/skills/.manifest.json" 2>/dev/null; then
  printf '  [PASS] F4 manifest still records project-initialization\n'; PASS=$((PASS + 1))
else
  printf '  [FAIL] F4 manifest lost project-initialization entry\n' >&2; FAIL=$((FAIL + 1))
fi

# Idempotency of the skip: re-running with the block still in place stays exit 0
# with the same skip count (no cascade, no abort on the second pass).
"$SYNC" >"$OUT" 2>"$ERR"
rc=$?
assert_eq "F4 second-run exit code" "$rc" 0
assert_eq "F4 second-run skip-collision count (stable)" \
  "$(grep -cF "[SKIP collision]" "$ERR" || true)" "$expected_skips"
assert_eq "F4 second-run blocking file still untouched" \
  "$(cat "$block_path")" "blocked-content"

# Recovery: once the operator clears the block, the previously-skipped files
# install via the normal path (no manual intervention beyond removing the block).
rm -f "$block_path"
"$SYNC" >"$OUT" 2>"$ERR"
rc=$?
assert_eq "F4 post-clear exit code" "$rc" 0
assert_ge "F4 post-clear installs the previously-blocked files" \
  "$(grep -cF "[INSTALL]" "$OUT" || true)" "$expected_skips"
# And one more run is fully idempotent (no collisions, no installs).
"$SYNC" >"$OUT" 2>"$ERR"
rc=$?
assert_eq "F4 post-clear idempotent exit code" "$rc" 0
assert_eq "F4 post-clear idempotent collisions" \
  "$(grep -cF "[SKIP collision]" "$ERR" || true)" 0

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
echo "========================================================="
printf 'Regression smoke: %d passed, %d failed\n' "$PASS" "$FAIL"
echo "========================================================="
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
