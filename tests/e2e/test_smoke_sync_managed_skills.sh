#!/usr/bin/env bash
#
# test_smoke_sync_managed_skills.sh — SPEC-002-T1 regression smoke for the
# three PR #26 review findings (issue #22, review loop 2).
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
