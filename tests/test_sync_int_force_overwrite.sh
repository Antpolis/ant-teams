#!/usr/bin/env bash
#
# test_sync_int_force_overwrite.sh — SPEC-002 TEST-2.6: --force overwrite.
#
# Traceability:
#   - FR-8.1 --force overwrites locally modified managed entries with current
#     source content; [FORCE overwrite] notice emitted to stderr.
#   - FR-8.3 --force does not touch unmanaged content.
#   - FR-8.4 manifest updated to reflect new content hashes after force.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.6 force overwrite"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha original\n'

# Run 1: install.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 1 exit 0" "$SYNC_RC"

# Locally modify alpha; also stage unmanaged sibling to prove force leaves it alone.
printf 'alpha LOCAL EDIT\n' > "$HOME_DIR/.agents/skills/alpha/SKILL.md"
mkdir -p "$HOME_DIR/.agents/skills/unmanaged"
printf 'keep me\n' > "$HOME_DIR/.agents/skills/unmanaged/SKILL.md"
UNMANAGED_HASH="$(sync_sha256 "$HOME_DIR/.agents/skills/unmanaged/SKILL.md")"

# Run 2 with --force: alpha overwritten from source, notice emitted.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR" --force
assert_exit_zero "run 2 --force exit 0" "$SYNC_RC"
assert_file_contains_str "force: [FORCE overwrite] notice" "$OUT" "[FORCE overwrite]"
assert_file_not_contains_str "force: local edit gone after overwrite" \
  "$HOME_DIR/.agents/skills/alpha/SKILL.md" "LOCAL EDIT"

# FR-8.4: manifest hash now reflects source content.
ALPHA_SRC="$(sync_sha256 "$FIX/templates/opencode/skills/alpha/SKILL.md")"
assert_eq "force: installed alpha == source" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/alpha/SKILL.md")" "$ALPHA_SRC"
assert_eq "force: manifest alpha hash == source" \
  "$(sync_manifest_file_hash "$MANIFEST" alpha "templates/opencode/skills/alpha/SKILL.md")" "$ALPHA_SRC"

# FR-8.3: unmanaged content untouched by force.
assert_eq "force: unmanaged untouched" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/unmanaged/SKILL.md")" "$UNMANAGED_HASH"

rm -f "$OUT"
sync_done
