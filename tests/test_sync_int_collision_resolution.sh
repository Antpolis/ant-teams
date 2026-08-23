#!/usr/bin/env bash
#
# test_sync_int_collision_resolution.sh — SPEC-002 TEST-2.11: collision
# resolution (source skill vs command-derived with the same name).
#
# Traceability:
#   - FR-11.1 source skill takes precedence; command-derived skipped with a
#     WARNING ([SKIP collision]).
#   - AC-10.1 the installed SKILL.md matches the SOURCE skill, not the derived.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.11 collision resolution (source wins)"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
OUT="$(mktemp)"

# Source skill AND command both named "shared".
mkdir -p "$FIX/templates/opencode/skills/shared"
printf -- '---\nname: shared\ndescription: SOURCE\n---\n\nthis is the SOURCE skill\n' \
  > "$FIX/templates/opencode/skills/shared/SKILL.md"
mkdir -p "$FIX/templates/opencode/commands"
cat > "$FIX/templates/opencode/commands/shared.md" <<'CMD'
---
description: DERIVED
agent: orchestrator
---

this is the COMMAND body
CMD

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "collision run exit 0" "$SYNC_RC"
assert_file_contains_str "collision: SKIP warning" "$OUT" "[SKIP collision]"
# Installed content is the SOURCE skill, not the command-derived output.
assert_file_contains_str "installed = source skill" \
  "$HOME_DIR/.agents/skills/shared/SKILL.md" "this is the SOURCE skill"
assert_file_not_contains_str "command body NOT installed" \
  "$HOME_DIR/.agents/skills/shared/SKILL.md" "this is the COMMAND body"
# Exactly one managed entry named "shared", type source_skill.
assert_eq "shared recorded as source_skill" \
  "$(sync_manifest_entry_type "$MANIFEST" shared)" "source_skill"
assert_count "collision: exactly one SKIP collision" "$OUT" "[SKIP collision]" 1

rm -f "$OUT"
sync_done
