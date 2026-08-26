#!/usr/bin/env bash
#
# test_sync_unit_mapping.sh — SPEC-002 TEST-1.5: source-to-target path mapping.
#
# Traceability:
#   - DM-3.1 source_skill templates/opencode/skills/<name>/<sub> -> ~/.agents/skills/<name>/<sub>. (command-derived entries still record the literal `.opencode/commands/<name>.md` key — the engine contract.)
#   - DM-3.2 command_derived .opencode/commands/<name>.md -> ~/.agents/skills/<name>/SKILL.md.
#   - DM-3.3 command-derived dir contains ONLY SKILL.md (no other files).
#   - FR-2.2a source skills copied in full (subdirs preserved).
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-1.5 source-to-target path mapping"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

# Source skill with nested subdirs + multiple files.
mkdir -p "$FIX/templates/opencode/skills/multi/scripts" "$FIX/templates/opencode/skills/multi/references"
printf -- '---\nname: multi\ndescription: m\n---\n\nmulti\n' > "$FIX/templates/opencode/skills/multi/SKILL.md"
printf '#!/usr/bin/env bash\necho hi\n'        > "$FIX/templates/opencode/skills/multi/scripts/run.sh"
printf 'reference text\n'                       > "$FIX/templates/opencode/skills/multi/references/ref.md"

# Command-derived skill.
mkdir -p "$FIX/templates/opencode/commands"
cat > "$FIX/templates/opencode/commands/do-tasks.md" <<'CMD'
---
description: do things
agent: orchestrator
---

Body for do-tasks.
CMD

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "mapping fixture install exit 0" "$SYNC_RC"

# --- DM-3.1: source_skill files map to <name>/<subpath> ----------------------
assert_exists "source SKILL.md mapped" "$HOME_DIR/.agents/skills/multi/SKILL.md"
assert_exists "nested scripts/run.sh mapped" "$HOME_DIR/.agents/skills/multi/scripts/run.sh"
assert_exists "nested references/ref.md mapped" "$HOME_DIR/.agents/skills/multi/references/ref.md"
# Content fidelity.
assert_file_contains_str "nested run.sh content preserved" \
  "$HOME_DIR/.agents/skills/multi/scripts/run.sh" 'echo hi'

# Manifest file keys are repository-relative source paths (DM-3.1).
assert_eq "manifest has multi SKILL.md key" \
  "$(sync_manifest_file_hash "$MANIFEST" multi "templates/opencode/skills/multi/SKILL.md" >/dev/null && echo present)" "present"

# --- DM-3.2 / DM-3.3: command-derived -> <name>/SKILL.md only ----------------
assert_exists "command-derived SKILL.md" "$HOME_DIR/.agents/skills/do-tasks/SKILL.md"
assert_file_contains_str "command-derived: only SKILL.md present" \
  "$HOME_DIR/.agents/skills/do-tasks/SKILL.md" 'name: do-tasks'
# The command-derived directory must contain exactly one file (SKILL.md).
CDIR_COUNT="$(find "$HOME_DIR/.agents/skills/do-tasks" -type f 2>/dev/null | wc -l | tr -d ' ')"
assert_eq "command-derived dir has exactly 1 file" "$CDIR_COUNT" "1"
# Manifest records the command under its source_path and a single SKILL.md file.
assert_eq "command-derived manifest type" \
  "$(sync_manifest_entry_type "$MANIFEST" do-tasks)" "command_derived"
assert_eq "command-derived manifest source_path" \
  "$(jq -r '.managed_entries["do-tasks"].source_path' "$MANIFEST" 2>/dev/null)" \
  ".opencode/commands/do-tasks.md"

rm -f "$OUT"
sync_done
