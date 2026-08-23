#!/usr/bin/env bash
#
# test_sync_int_boundary_enforcement.sh — SPEC-002 TEST-2.12: boundary
# enforcement.
#
# Traceability:
#   - FR-7.1/.2 every write target must be (a) already a managed entry,
#     (b) a new source entry, or (c) an updated managed entry; else fatal exit 2
#     with nothing written to that path.
#   - SEC-1.3 resolved target path must start with ~/.agents/skills/.
#   - SEC-2.2 a malicious manifest target_path cannot grant a write outside the
#     managed subtree (manifest is a record, not an authority).
#
# The script computes target paths from entry name + subpath (never from the
# manifest's stored target_path, per SEC-2.1). So the active boundary rejection
# (exit 2) is exercised via a source filename containing '..', and the
# manifest-trust boundary is exercised via a malicious target_path that must
# NOT cause any out-of-bounds write.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.12 boundary enforcement"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

# --- FR-7.2 / SEC-1.1: filename with '..' => exit 2, no write ---------------
mkdir -p "$FIX/templates/opencode/skills/bad/sub..escape"
printf -- '---\nname: bad\ndescription: b\n---\n\nbad\n' > "$FIX/templates/opencode/skills/bad/SKILL.md"
printf 'escape\n' > "$FIX/templates/opencode/skills/bad/sub..escape/file.txt"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_eq "boundary violation exit 2" "$SYNC_RC" "2"
assert_file_contains_str "boundary: error message" "$OUT" "[ERROR]"
assert_file_contains_str "boundary: traversal detected reason" "$OUT" "traversal"
# Earlier in-bounds files may be written before the bad path is reached; the
# guarantee (FR-7.2) is that the escaping path itself is never written.
assert_not_exists "boundary: escaping subdir not created" "$HOME_DIR/.agents/skills/bad/sub..escape"

# --- SEC-2.2: malicious manifest target_path => no out-of-bounds write -------
rm -rf "$HOME_DIR/.agents"; rm -rf "$FIX/templates/opencode/skills"
mkdir -p "$FIX/templates/opencode/skills/alpha"
printf -- '---\nname: alpha\ndescription: a\n---\n\nalpha\n' > "$FIX/templates/opencode/skills/alpha/SKILL.md"
# On-disk alpha differs from source => "modified" => default run preserves it
# and carries the (malicious) manifest_target forward, but NEVER writes to it.
mkdir -p "$HOME_DIR/.agents/skills/alpha"
printf 'local\n' > "$HOME_DIR/.agents/skills/alpha/SKILL.md"
OOB_DIR="$HOME_DIR/oob-target"
mkdir -p "$OOB_DIR"
cat > "$MANIFEST" <<JSON
{
  "version": 1,
  "last_sync": "2026-08-01T00:00:00Z",
  "managed_entries": {
    "alpha": {
      "type": "source_skill",
      "source_path": "templates/opencode/skills/alpha/",
      "installed_at": "2026-08-01T00:00:00Z",
      "files": {
        "templates/opencode/skills/alpha/SKILL.md": {
          "hash": "0000000000000000000000000000000000000000000000000000000000000000",
          "target_path": "$OOB_DIR/escape.md"
        }
      }
    }
  }
}
JSON
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "malicious manifest: exit 0 (modified preserved)" "$SYNC_RC"
assert_count      "malicious manifest: SKIP modified (no write attempted)" "$OUT" "[SKIP modified]" 1
assert_not_exists "malicious manifest: nothing written out-of-bounds" "$OOB_DIR/escape.md"

rm -f "$OUT"
sync_done
