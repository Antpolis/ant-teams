#!/usr/bin/env bash
#
# test_sync_int_fresh_install.sh — SPEC-002 TEST-2.1: fresh install.
#
# Traceability:
#   - FR-2.1/.2 managed sync installs source skills + command-derived.
#   - FR-2.3/.4 nothing outside the recorded entries / nothing outside skills.
#   - FR-3.1/.2 manifest created at ~/.agents/skills/.manifest.json with ownership.
#   - FR-6.1a new entries installed without warning.
#   - SEC-5.1 unmanaged sibling content untouched.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.1 fresh install (no manifest)"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

# Two source skills + one command.
sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha\n'
sync_write_skill "$FIX" "beta"  $'---\nname: beta\ndescription: b\n---\n\nbeta\n'
sync_write_command "$FIX" "greet" \
  $'description: greet command\nagent: orchestrator' \
  $'Hello $ARGUMENTS\n'

# Pre-seed genuinely unmanaged sibling content.
mkdir -p "$HOME_DIR/.agents/skills/my-custom"
printf 'operator-owned\n' > "$HOME_DIR/.agents/skills/my-custom/SKILL.md"
MYHASH="$(sync_sha256 "$HOME_DIR/.agents/skills/my-custom/SKILL.md")"

# No manifest yet.
assert_not_exists "no manifest before install" "$MANIFEST"

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "fresh install exit 0" "$SYNC_RC"
assert_count      "fresh: alpha installed" "$OUT" "[INSTALL]" 3   # alpha + beta + greet
assert_file_contains_str "fresh: manifest created" "$MANIFEST" "managed_entries"
assert_eq "fresh: 3 managed entries" "$(sync_manifest_count_entries "$MANIFEST")" "3"
assert_exists "fresh: alpha SKILL.md" "$HOME_DIR/.agents/skills/alpha/SKILL.md"
assert_exists "fresh: beta SKILL.md"  "$HOME_DIR/.agents/skills/beta/SKILL.md"
assert_exists "fresh: greet derived"  "$HOME_DIR/.agents/skills/greet/SKILL.md"

# FR-2.4: nothing created outside ~/.agents/skills/.
assert_not_exists "fresh: nothing under ~/.config/opencode" "$HOME_DIR/.config/opencode"

# SEC-5.1: unmanaged sibling untouched (content identical).
assert_eq "fresh: unmanaged content untouched" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/my-custom/SKILL.md")" "$MYHASH"
assert_eq "fresh: unmanaged NOT in manifest" \
  "$(sync_manifest_has_entry "$MANIFEST" my-custom)" "no"

# No warnings about new installs (FR-6.1a).
assert_count "fresh: no SKIP modified" "$OUT" "[SKIP modified]" 0

rm -f "$OUT"
sync_done
