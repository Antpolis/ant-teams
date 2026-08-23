#!/usr/bin/env bash
#
# test_sync_unit_collision.sh — SPEC-002 TEST-1.6: collision detection.
#
# Traceability:
#   - FR-11.1 source skill and command-derived with same name => source wins,
#     command-derived skipped with [SKIP collision] WARNING (exit 0).
#   - FR-11.4 unmanaged entry occupying a target name (manifest present, entry
#     not recorded) => skip with warning; sibling entries still install.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-1.6 collision detection"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
OUT="$(mktemp)"

# --- FR-11.1: source skill wins over command-derived with the same name ------
mkdir -p "$FIX/templates/opencode/skills/collide"
printf -- '---\nname: collide\ndescription: SOURCE-SKILL\n---\n\nsource skill body\n' \
  > "$FIX/templates/opencode/skills/collide/SKILL.md"
mkdir -p "$FIX/templates/opencode/commands"
cat > "$FIX/templates/opencode/commands/collide.md" <<'CMD'
---
description: COMMAND-DERIVED
agent: x
---

command body
CMD
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "name collision: exit 0" "$SYNC_RC"
assert_file_contains_str "collision: SKIP warning emitted" "$OUT" "[SKIP collision]"
# The installed SKILL.md must be the SOURCE skill version, not the command output.
assert_file_contains_str "source skill won the name" \
  "$HOME_DIR/.agents/skills/collide/SKILL.md" "SOURCE-SKILL"
assert_file_not_contains_str "command-derived did NOT win" \
  "$HOME_DIR/.agents/skills/collide/SKILL.md" "COMMAND-DERIVED"

# --- FR-11.4: unmanaged entry name collision (manifest present) --------------
rm -rf "$HOME_DIR/.agents"; rm -rf "$FIX/templates/opencode/skills"; rm -f "$FIX/templates/opencode/commands/"*.md
mkdir -p "$FIX/templates/opencode/skills/occupy" "$FIX/templates/opencode/skills/free"
printf -- '---\nname: occupy\ndescription: o\n---\n\no\n' > "$FIX/templates/opencode/skills/occupy/SKILL.md"
printf -- '---\nname: free\ndescription: f\n---\n\nf\n'   > "$FIX/templates/opencode/skills/free/SKILL.md"
# Pre-seed the managed target with an UNMANAGED occupy dir + a valid manifest
# that records only "free" (so "occupy" is genuinely unmanaged from the sync's
# viewpoint).
mkdir -p "$HOME_DIR/.agents/skills/occupy"
printf 'do-not-clobber-me\n' > "$HOME_DIR/.agents/skills/occupy/SKILL.md"
FREE_HASH="$(sync_sha256 "$FIX/templates/opencode/skills/free/SKILL.md")"
cat > "$HOME_DIR/.agents/skills/.manifest.json" <<JSON
{
  "version": 1,
  "last_sync": "2026-08-01T00:00:00Z",
  "managed_entries": {
    "free": {
      "type": "source_skill",
      "source_path": "templates/opencode/skills/free/",
      "installed_at": "2026-08-01T00:00:00Z",
      "files": {
        "templates/opencode/skills/free/SKILL.md": {
          "hash": "$FREE_HASH",
          "target_path": "$HOME_DIR/.agents/skills/free/SKILL.md"
        }
      }
    }
  }
}
JSON
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "unmanaged collision: exit 0" "$SYNC_RC"
assert_file_contains_str "unmanaged occupy: SKIP collision" "$OUT" "[SKIP collision] occupy"
# Unmanaged content untouched.
assert_file_contains_str "unmanaged occupy content preserved" \
  "$HOME_DIR/.agents/skills/occupy/SKILL.md" "do-not-clobber-me"
# Sibling "free" still installs/NOOPs normally.
assert_exists "sibling free installed" "$HOME_DIR/.agents/skills/free/SKILL.md"

rm -f "$OUT"
sync_done
