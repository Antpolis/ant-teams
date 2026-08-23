#!/usr/bin/env bash
#
# test_sync_int_command_transform.sh — SPEC-002 TEST-2.10: command-derived
# transformation correctness.
#
# Traceability:
#   - FR-4.1 frontmatter: name, description (verbatim), disable-model-invocation
#     true, in order; body byte-for-byte; trailing newline.
#   - FR-4.2 agent field dropped.
#   - FR-4.3 $ARGUMENTS preserved verbatim (not expanded).
#   - INT-2.2b description with colons/quotes preserved; missing desc => "".
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-2.10 command-derived transformation"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
OUT="$(mktemp)"

mkdir -p "$FIX/templates/opencode/commands"
cat > "$FIX/templates/opencode/commands/do-tasks.md" <<'CMD'
---
description: Continue or finish existing approved tasks.
agent: orchestrator
---

Drive the next approved task work. Arguments: $ARGUMENTS
Multiple body lines preserved.
CMD

cat > "$FIX/templates/opencode/commands/plan.md" <<'CMD'
---
description: "Plan: a \"sprint\" now"
agent: strategist
---

Plan body with $ARGUMENTS.
CMD

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "transform install exit 0" "$SYNC_RC"

DT="$HOME_DIR/.agents/skills/do-tasks/SKILL.md"
PL="$HOME_DIR/.agents/skills/plan/SKILL.md"
assert_exists "do-tasks derived exists" "$DT"
assert_exists "plan derived exists" "$PL"

# FR-4.1 fields + order (do-tasks).
assert_file_contains_str "name set to command filename" "$DT" "name: do-tasks"
assert_file_contains_str "description verbatim" "$DT" "description: Continue or finish existing approved tasks."
assert_file_contains_str "disable-model-invocation true" "$DT" "disable-model-invocation: true"
NAME_LN="$(grep -n '^name:' "$DT" | head -1 | cut -d: -f1)"
DESC_LN="$(grep -n '^description:' "$DT" | head -1 | cut -d: -f1)"
DMI_LN="$(grep -n '^disable-model-invocation:' "$DT" | head -1 | cut -d: -f1)"
assert_gt "order: name before description" "$DESC_LN" "$NAME_LN"
assert_gt "order: description before disable" "$DMI_LN" "$DESC_LN"

# FR-4.2 agent dropped in both.
assert_file_not_contains_str "agent dropped (do-tasks)" "$DT" "agent:"
assert_file_not_contains_str "agent dropped (plan)" "$PL" "agent:"

# FR-4.3 $ARGUMENTS preserved verbatim.
assert_file_contains_str "\$ARGUMENTS preserved (do-tasks)" "$DT" 'Arguments: $ARGUMENTS'
assert_file_contains_str "\$ARGUMENTS preserved (plan)" "$PL" 'body with $ARGUMENTS.'

# INT-2.2b description with colon + quotes preserved verbatim.
assert_file_contains_str "plan description colon+quotes preserved" "$PL" 'description: "Plan: a \"sprint\" now"'

# FR-4.1c body preserved byte-for-byte (multi-line).
assert_file_contains_str "body line 1 preserved" "$DT" "Drive the next approved task work."
assert_file_contains_str "body line 2 preserved" "$DT" "Multiple body lines preserved."

# FR-4.1d trailing newline present.
if [[ -n "$(tail -c1 "$DT" 2>/dev/null)" ]]; then
  check FAIL "trailing newline (do-tasks)"
else
  check OK "trailing newline (do-tasks)"
fi

rm -f "$OUT"
sync_done
