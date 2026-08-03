#!/usr/bin/env bash
#
# test_sync_unit_manifest.sh — SPEC-002 TEST-1.1: manifest read/write/validation.
#
# Traceability:
#   - FR-3 (Manifest Ownership): FR-3.1 path, FR-3.2 fields, FR-3.3 write guard,
#     FR-3.4 schema = DM-2.
#   - DM-2 manifest schema (version, managed_entries, per-file hash+target_path).
#   - DM-4.1 atomic write (temp+rename; manifest is the last write).
#   - DM-4.2 / ERR-3.1 corrupt-JSON recovery (move to .corrupt.<ts>, proceed empty).
#   - ERR-3.2 valid-JSON-but-missing-required-keys treated as corrupt.
#   - DM-1.1 manifest location ~/.agents/skills/.manifest.json.
#
# Strategy: controlled fixture repo (real script copied in) + temp HOME so the
# real ~/.agents/skills is never touched.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-1.1 manifest read/write/validation"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"

# A single source skill with known content.
sync_write_skill "$FIX" "alpha" \
$'---\nname: alpha\ndescription: Alpha skill\n---\n\nAlpha body.\n'
ALPHA_SRC="$FIX/.opencode/skills/alpha/SKILL.md"
ALPHA_HASH="$(sync_sha256 "$ALPHA_SRC")"

OUT="$(mktemp)"

# --- DM-1.1: manifest lives at ~/.agents/skills/.manifest.json ----------------
# Fresh run (no manifest): installs the skill and WRITES a manifest there.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero     "fresh install exit 0" "$SYNC_RC"
assert_file_contains_str "manifest at canonical path" "$MANIFEST" "managed_entries"
assert_eq "manifest records 1 entry" \
  "$(sync_manifest_count_entries "$MANIFEST")" "1"
assert_eq "manifest entry type source_skill" \
  "$(sync_manifest_entry_type "$MANIFEST" alpha)" "source_skill"
assert_eq "manifest entry hash matches source" \
  "$(sync_manifest_file_hash "$MANIFEST" alpha ".opencode/skills/alpha/SKILL.md")" "$ALPHA_HASH"
assert_file_contains_str "manifest target_path under managed subtree" "$MANIFEST" "/.agents/skills/alpha/SKILL.md"

# --- FR-3 / DM-4.2: valid manifest read => NOOP on idempotent re-run ---------
# Pre-write a VALID manifest recording alpha with the correct hash; the sync
# must read it and treat alpha as unchanged ([NOOP]).
rm -rf "$HOME_DIR/.agents"
mkdir -p "$HOME_DIR/.agents/skills/alpha"
cp "$ALPHA_SRC" "$HOME_DIR/.agents/skills/alpha/SKILL.md"
cat > "$MANIFEST" <<JSON
{
  "version": 1,
  "source_repo": "$FIX",
  "last_sync": "2026-08-01T00:00:00Z",
  "managed_entries": {
    "alpha": {
      "type": "source_skill",
      "source_path": ".opencode/skills/alpha/",
      "installed_at": "2026-08-01T00:00:00Z",
      "files": {
        ".opencode/skills/alpha/SKILL.md": {
          "hash": "$ALPHA_HASH",
          "target_path": "$HOME_DIR/.agents/skills/alpha/SKILL.md"
        }
      }
    }
  }
}
JSON
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "valid manifest: idempotent run exit 0" "$SYNC_RC"
assert_count      "valid manifest: alpha treated as NOOP" "$OUT" "[NOOP]" 1
assert_count      "valid manifest: no installs" "$OUT" "[INSTALL]" 0

# --- ERR-3.1: corrupt JSON manifest recovered --------------------------------
rm -rf "$HOME_DIR/.agents"
mkdir -p "$HOME_DIR/.agents/skills"
printf '{ this is not valid json {{{\n' > "$MANIFEST"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "corrupt-JSON manifest: exit 0 (recovered)" "$SYNC_RC"
assert_file_contains_str "corrupt recovery warning emitted" "$OUT" "[WARNING]"
assert_file_contains_str "corrupt manifest moved aside" "$OUT" ".corrupt."
# A .corrupt.<ts> sibling now exists.
CORRUPT_COUNT="$(find "$HOME_DIR/.agents/skills" -maxdepth 1 -name '.manifest.json.corrupt.*' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "exactly one .corrupt.<ts> file created" "$CORRUPT_COUNT" "1"
# A fresh valid manifest was written.
assert_eq "fresh manifest written after recovery" \
  "$(sync_manifest_is_valid_json "$MANIFEST")" "yes"
assert_eq "alpha installed after recovery" \
  "$(sync_manifest_has_entry "$MANIFEST" alpha)" "yes"

# --- ERR-3.2: valid JSON but missing required keys => treated as corrupt ------
rm -rf "$HOME_DIR/.agents"
mkdir -p "$HOME_DIR/.agents/skills"
printf '{"note": "no version, no managed_entries"}\n' > "$MANIFEST"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "missing-keys manifest: exit 0 (recovered)" "$SYNC_RC"
assert_file_contains_str "missing-keys treated as corrupt" "$OUT" ".corrupt."
CORRUPT_COUNT2="$(find "$HOME_DIR/.agents/skills" -maxdepth 1 -name '.manifest.json.corrupt.*' 2>/dev/null | wc -l | tr -d ' ')"
assert_ge "corrupt aside file created for missing-keys" "$CORRUPT_COUNT2" "1"
assert_eq "fresh manifest written after missing-keys recovery" \
  "$(sync_manifest_is_valid_json "$MANIFEST")" "yes"

# --- ERR-3.2 variant: wrong version integer => corrupt -----------------------
rm -rf "$HOME_DIR/.agents"
mkdir -p "$HOME_DIR/.agents/skills"
printf '{"version": 99, "managed_entries": {}}\n' > "$MANIFEST"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "wrong-version manifest: exit 0 (recovered)" "$SYNC_RC"
assert_file_contains_str "wrong-version treated as corrupt" "$OUT" ".corrupt."

# --- DM-4.1: manifest is the last write (atomic temp+rename) -----------------
# After a clean run the manifest is valid JSON and is the newest file written
# under the managed subtree (no partial/.tmp leftover).
rm -rf "$HOME_DIR/.agents"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "clean run exit 0" "$SYNC_RC"
LEFTOVER_TMP="$(find "$HOME_DIR/.agents/skills" -maxdepth 1 -name '.manifest.json.tmp' 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "no leftover .manifest.json.tmp" "$LEFTOVER_TMP" "0"
assert_eq "manifest valid JSON after clean run" \
  "$(sync_manifest_is_valid_json "$MANIFEST")" "yes"

rm -f "$OUT"
sync_done
