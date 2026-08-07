#!/usr/bin/env bash
#
# test_sync_int_unmanaged_collision.sh — SPEC-002 TEST-2.9: unmanaged name
# collision.
#
# Traceability:
#   - FR-11.4 / SEC-5.1 if a target entry name already exists under
#     ~/.agents/skills/ as unmanaged content (manifest present, entry not
#     recorded), the sync skips it with a WARNING and continues.
#   - FR-6.1d unrelated managed entries still sync normally.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.9 unmanaged name collision"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

# Two source skills: "taken" (will collide) and "free" (installs normally).
sync_write_skill "$FIX" "taken" $'---\nname: taken\ndescription: t\n---\n\ntaken\n'
sync_write_skill "$FIX" "free"  $'---\nname: free\ndescription: f\n---\n\nfree\n'

# Pre-seed an UNMANAGED directory at the "taken" target name + a manifest that
# records only "free" (so "taken" is genuinely unmanaged).
mkdir -p "$HOME_DIR/.agents/skills/taken"
printf 'operator-owned\n' > "$HOME_DIR/.agents/skills/taken/SKILL.md"
TAKEN_HASH="$(sync_sha256 "$HOME_DIR/.agents/skills/taken/SKILL.md")"
FREE_HASH="$(sync_sha256 "$FIX/.opencode/skills/free/SKILL.md")"
cat > "$MANIFEST" <<JSON
{
  "version": 1,
  "last_sync": "2026-08-01T00:00:00Z",
  "managed_entries": {
    "free": {
      "type": "source_skill",
      "source_path": ".opencode/skills/free/",
      "installed_at": "2026-08-01T00:00:00Z",
      "files": {
        ".opencode/skills/free/SKILL.md": { "hash": "$FREE_HASH", "target_path": "$HOME_DIR/.agents/skills/free/SKILL.md" }
      }
    }
  }
}
JSON

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "collision run exit 0" "$SYNC_RC"
assert_file_contains_str "taken: SKIP collision warning" "$OUT" "[SKIP collision]"
assert_file_contains_str "taken: collision reason named" "$OUT" "taken"
# Unmanaged "taken" content preserved (never overwritten/inspected).
assert_eq "taken content untouched" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/taken/SKILL.md")" "$TAKEN_HASH"
assert_eq "taken NOT in manifest" "$(sync_manifest_has_entry "$MANIFEST" taken)" "no"
# Sibling "free" still installed/NOOP.
assert_exists "free installed normally" "$HOME_DIR/.agents/skills/free/SKILL.md"
assert_eq "free IS in manifest" "$(sync_manifest_has_entry "$MANIFEST" free)" "yes"

rm -f "$OUT"
sync_done
