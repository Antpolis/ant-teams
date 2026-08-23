#!/usr/bin/env bash
#
# test_sync_unit_paths.sh — SPEC-002 TEST-1.4: path construction + traversal
# prevention and managed-subtree boundary enforcement.
#
# Traceability:
#   - SEC-1.1/SEC-1.2 reject `..` and absolute escapes; target joined under
#     the resolved managed base.
#   - SEC-1.3 every resolved target path must start with ~/.agents/skills/.
#   - FR-7.2 write attempt failing all three boundary checks => fatal exit 2,
#     nothing written to that path.
#   - SEC-2.2 a malicious manifest target_path cannot grant a write outside the
#     managed subtree (manifest is a record, not an authority).
#   - SEC-5.2 symlink in the managed ancestor chain => skip, no write into the
#     symlink target.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-1.4 path construction + traversal prevention"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

# --- SEC-1.3: every recorded target_path stays inside ~/.agents/skills/ ------
mkdir -p "$FIX/templates/opencode/skills/normal"
printf -- '---\nname: normal\ndescription: n\n---\n\nbody\n' > "$FIX/templates/opencode/skills/normal/SKILL.md"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "normal install exit 0" "$SYNC_RC"
TP="$(sync_manifest_target_path "$MANIFEST" normal "templates/opencode/skills/normal/SKILL.md")"
case "$TP" in
  "$HOME_DIR/.agents/skills/"*) check OK "target_path within managed subtree";;
  *) check FAIL "target_path within managed subtree (got $TP)";;
esac

# --- SEC-1.1 / FR-7.2: a filename containing '..' => fatal exit 2, no write ---
rm -rf "$HOME_DIR/.agents"
rm -rf "$FIX/templates/opencode/skills"
mkdir -p "$FIX/templates/opencode/skills/trav/sub..dir"
printf -- '---\nname: trav\ndescription: t\n---\n\nbody\n' > "$FIX/templates/opencode/skills/trav/SKILL.md"
printf 'evil\n' > "$FIX/templates/opencode/skills/trav/sub..dir/escape.txt"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_nonzero "traversal filename => non-zero exit" "$SYNC_RC"
assert_eq "traversal filename => exit 2 (boundary)" "$SYNC_RC" "2"
assert_file_contains_str "traversal: error message" "$OUT" "[ERROR]"
assert_file_contains_str "traversal: traversal detected reason" "$OUT" "traversal"
# The script processes earlier in-bounds files first, then dies on the bad path.
# Assert the escaping nested directory was NEVER created (the bad write did not
# happen), not that the whole entry dir is absent.
assert_not_exists "traversal: escaping subdir not created" "$HOME_DIR/.agents/skills/trav/sub..dir"

# --- SEC-2.2: malicious manifest target_path cannot cause an out-of-bounds write
rm -rf "$HOME_DIR/.agents"; rm -rf "$FIX/templates/opencode/skills"
mkdir -p "$FIX/templates/opencode/skills/alpha"
printf -- '---\nname: alpha\ndescription: a\n---\n\nalpha body\n' > "$FIX/templates/opencode/skills/alpha/SKILL.md"
ALPHA_SRC="$FIX/templates/opencode/skills/alpha/SKILL.md"
REAL_HASH="$(sync_sha256 "$ALPHA_SRC")"
# On-disk alpha content DIFFERS from manifest hash => classified "modified" =>
# preserved by default. The manifest carries an out-of-bounds target_path.
mkdir -p "$HOME_DIR/.agents/skills/alpha"
printf 'different-on-disk\n' > "$HOME_DIR/.agents/skills/alpha/SKILL.md"
OOB="$HOME_DIR/.agents/skills/../../../oob-target"
mkdir -p "$HOME_DIR/oob-target"
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
          "hash": "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef",
          "target_path": "$OOB"
        }
      }
    }
  }
}
JSON
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "malicious manifest: exit 0 (modified preserved)" "$SYNC_RC"
assert_count      "malicious manifest: alpha SKIP modified" "$OUT" "[SKIP modified]" 1
# The out-of-bounds target must NOT have received any new file from this run.
if [[ -e "$OOB/SKILL.md" ]]; then
  check FAIL "malicious target_path: nothing written out-of-bounds"
else
  check OK "malicious target_path: nothing written out-of-bounds"
fi

# --- SEC-5.2: symlink at managed entry dir => skip, no write into symlink target
rm -rf "$HOME_DIR/.agents"
rm -rf "$FIX/templates/opencode/skills"
mkdir -p "$FIX/templates/opencode/skills/slink"
printf -- '---\nname: slink\ndescription: s\n---\n\nslink body\n' > "$FIX/templates/opencode/skills/slink/SKILL.md"
mkdir -p "$HOME_DIR/.evil-slink-target"
# Place a symlink at the managed entry name pointing OUTSIDE the managed subtree.
ln -s "$HOME_DIR/.evil-slink-target" "$HOME_DIR/.agents"
mkdir -p "$HOME_DIR/.agents/skills"
ln -s "$HOME_DIR/.evil-slink-target" "$HOME_DIR/.agents/skills/slink"
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "symlink entry dir: exit 0 (skipped)" "$SYNC_RC"
assert_file_contains_str "symlink entry: SKIP collision emitted" "$OUT" "[SKIP collision]"
# Nothing was written through the symlink into the external target.
if [[ -e "$HOME_DIR/.evil-slink-target/SKILL.md" ]]; then
  check FAIL "symlink: nothing written into symlink target"
else
  check OK "symlink: nothing written into symlink target"
fi

rm -f "$OUT"
sync_done
