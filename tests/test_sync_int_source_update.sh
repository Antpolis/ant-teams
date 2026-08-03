#!/usr/bin/env bash
#
# test_sync_int_source_update.sh — SPEC-002 TEST-2.3: source update.
#
# Traceability:
#   - FR-6.1b unchanged managed entry updated from source when source changes
#     (target not locally modified).
#   - FR-6.1a unchanged entries (unchanged source) install without warning.
#   - OBS-1.1 [UPDATE] emitted for changed entries; [NOOP] for unchanged.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.3 source update"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha v1\n'
sync_write_skill "$FIX" "beta"  $'---\nname: beta\ndescription: b\n---\n\nbeta\n'

# Run 1: install both.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 1 exit 0" "$SYNC_RC"
ALPHA1="$(sync_sha256 "$HOME_DIR/.agents/skills/alpha/SKILL.md")"

# Mutate source alpha; leave beta unchanged.
sync_write_skill "$FIX" "alpha" $'---\nname: alpha\ndescription: a\n---\n\nalpha v2 CHANGED\n'

# Run 2: alpha should [UPDATE], beta should [NOOP].
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "run 2 exit 0" "$SYNC_RC"
assert_file_contains_str "run 2: alpha UPDATE" "$OUT" "[UPDATE] alpha"
assert_count               "run 2: exactly one UPDATE" "$OUT" "[UPDATE]" 1
assert_count               "run 2: beta NOOP" "$OUT" "[NOOP]" 1

# Installed alpha content reflects the NEW source (hash differs from v1).
ALPHA2="$(sync_sha256 "$HOME_DIR/.agents/skills/alpha/SKILL.md")"
assert_neq "alpha content changed after update" "$ALPHA2" "$ALPHA1"
ALPHA_SRC="$(sync_sha256 "$FIX/.opencode/skills/alpha/SKILL.md")"
assert_eq "alpha installed == source v2" "$ALPHA2" "$ALPHA_SRC"

# Manifest hash for alpha reflects the new source content.
assert_eq "manifest alpha hash updated" \
  "$(sync_manifest_file_hash "$MANIFEST" alpha ".opencode/skills/alpha/SKILL.md")" "$ALPHA_SRC"

rm -f "$OUT"
sync_done
