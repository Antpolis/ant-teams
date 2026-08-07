#!/usr/bin/env bash
#
# test_sync_int_partial_recovery.sh — SPEC-002 TEST-2.13: partial-run recovery.
#
# Traceability:
#   - ERR-5.1a a previous run that wrote files but never committed the manifest
#     leaves files in ~/.agents/skills/ with no manifest. The next run reclaims
#     directories whose name matches a current source entry: content matching
#     source => NOOP (reconciled); differing content => treated as a local
#     modification (preserved by default).
#   - ERR-5.1b a directory that does NOT match any current source entry is
#     treated as unmanaged (never touched).
#   - ERR-5.2 the sync never deletes files to clean up a partial run.
#   - DM-1.2 missing manifest => existing content treated as unmanaged except
#     for source-named dirs which are reclaimed.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.13 partial-run recovery"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

# Two source skills.
sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha\n'
sync_write_skill "$FIX" "beta"  $'---\nname: beta\ndescription: b\n---\n\nbeta original\n'
ALPHA_SRC="$FIX/.opencode/skills/alpha/SKILL.md"
BETA_SRC="$FIX/.opencode/skills/beta/SKILL.md"

# Simulate a crash AFTER file writes but BEFORE manifest commit:
#  - alpha on disk, content MATCHES source (recoverable as NOOP).
#  - beta on disk, content DIFFERS from source (recovered => treated modified).
#  - "stranger" dir matches no source entry (must remain unmanaged).
mkdir -p "$HOME_DIR/.agents/skills/alpha" "$HOME_DIR/.agents/skills/beta" "$HOME_DIR/.agents/skills/stranger"
cp "$ALPHA_SRC" "$HOME_DIR/.agents/skills/alpha/SKILL.md"
printf 'beta DIVERGED from source\n' > "$HOME_DIR/.agents/skills/beta/SKILL.md"
printf 'unrelated orphan content\n'  > "$HOME_DIR/.agents/skills/stranger/SKILL.md"
BETA_DISK="$(sync_sha256 "$HOME_DIR/.agents/skills/beta/SKILL.md")"
STRANGER_DISK="$(sync_sha256 "$HOME_DIR/.agents/skills/stranger/SKILL.md")"
assert_not_exists "no manifest before recovery (partial state)" "$MANIFEST"

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "recovery run exit 0" "$SYNC_RC"

# ERR-5.1a: alpha (matches source) reclaimed as NOOP.
assert_file_contains_str "alpha reclaimed (NOOP)" "$OUT" "[NOOP]"
assert_eq "alpha recorded as managed" "$(sync_manifest_has_entry "$MANIFEST" alpha)" "yes"

# ERR-5.1a: beta (diverges from source) reclaimed as locally-modified => preserved.
assert_file_contains_str "beta SKIP modified (recovered divergence)" "$OUT" "[SKIP modified]"
assert_eq "beta preserved content" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/beta/SKILL.md")" "$BETA_DISK"

# ERR-5.1b / ERR-5.2: stranger (no matching source) untouched, not deleted, not managed.
assert_exists "stranger not deleted (ERR-5.2)" "$HOME_DIR/.agents/skills/stranger/SKILL.md"
assert_eq "stranger content untouched" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/stranger/SKILL.md")" "$STRANGER_DISK"
assert_eq "stranger NOT in manifest" "$(sync_manifest_has_entry "$MANIFEST" stranger)" "no"

# Manifest now exists and records alpha + beta.
assert_eq "manifest valid after recovery" "$(sync_manifest_is_valid_json "$MANIFEST")" "yes"

rm -f "$OUT"
sync_done
