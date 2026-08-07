#!/usr/bin/env bash
#
# test_sync_int_unmanaged_protection.sh — SPEC-002 TEST-2.8: unmanaged content
# protection across all run modes.
#
# Traceability:
#   - FR-7.3 / SEC-5.1 unmanaged content is never read, hashed, compared, or
#     modified — only its existence may be checked for collision detection.
#   - FR-8.3 --force does not touch unmanaged content.
#   - FR-9.1 dry-run does not touch unmanaged content.
#   - AC-6.1 a file under ~/.agents/skills not in the manifest survives default,
#     --force, and --dry-run with no warning about it.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.8 unmanaged content protection"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha\n'

# Seed unmanaged sibling content (no manifest record).
mkdir -p "$HOME_DIR/.agents/skills/my-custom"
printf 'precious operator content\n' > "$HOME_DIR/.agents/skills/my-custom/SKILL.md"
PRECIOUS="$(sync_sha256 "$HOME_DIR/.agents/skills/my-custom/SKILL.md")"

run_mode() {
  local mode="$1"; shift
  sync_capture "$OUT" "$SCRIPT" "$HOME_DIR" "$@"
  assert_exit_zero "$mode exit 0" "$SYNC_RC"
  assert_eq "$mode: unmanaged content untouched" \
    "$(sync_sha256 "$HOME_DIR/.agents/skills/my-custom/SKILL.md")" "$PRECIOUS"
  assert_file_not_contains_str "$mode: no warning about unmanaged" "$OUT" "my-custom"
  assert_eq "$mode: my-custom NOT in manifest" \
    "$(sync_manifest_has_entry "$MANIFEST" my-custom)" "no"
}

run_mode "default"
run_mode "--force" --force
run_mode "--dry-run" --dry-run

rm -f "$OUT"
sync_done
