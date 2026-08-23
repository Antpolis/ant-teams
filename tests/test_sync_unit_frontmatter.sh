#!/usr/bin/env bash
#
# test_sync_unit_frontmatter.sh — SPEC-002 TEST-1.2: command frontmatter parsing.
#
# Traceability:
#   - FR-4 command->SKILL.md transformation: FR-4.1 (frontmatter fields+order,
#     body preserved byte-for-byte, trailing newline), FR-4.2 (agent dropped),
#     FR-4.3 ($ARGUMENTS preserved verbatim), FR-4.4 (derived, not read back).
#   - ERR-1.1 malformed frontmatter (unclosed ---) => WARNING + default desc "".
#   - INT-2.2 description parsing (colons/quotes verbatim; missing desc => "").
#
# Strategy: controlled fixture repo with several command files exercising each
# frontmatter shape; temp HOME.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-1.2 command frontmatter parsing"

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
OUT="$(mktemp)"

gen_and_read() {
  # Run the sync then echo the generated <HOME>/.agents/skills/<name>/SKILL.md.
  local name="$1"
  sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
  cat "$HOME_DIR/.agents/skills/$name/SKILL.md"
}

# --- FR-4.1/4.2/4.3: valid frontmatter, agent dropped, $ARGUMENTS preserved ---
mkdir -p "$FIX/templates/opencode/commands"
cat > "$FIX/templates/opencode/commands/do-tasks.md" <<'CMD'
---
description: Continue or finish existing approved tasks.
agent: orchestrator
---

Drive the next approved task work. Args: $ARGUMENTS
CMD
OUT_VAL="$(gen_and_read do-tasks)"
# Field order (FR-4.1a): name, description, disable-model-invocation.
assert_file_contains_str "name field first" "$HOME_DIR/.agents/skills/do-tasks/SKILL.md" "name: do-tasks"
assert_file_contains_str "description copied verbatim" "$HOME_DIR/.agents/skills/do-tasks/SKILL.md" "description: Continue or finish existing approved tasks."
assert_file_contains_str "disable-model-invocation true" "$HOME_DIR/.agents/skills/do-tasks/SKILL.md" "disable-model-invocation: true"
# FR-4.2: agent field dropped.
assert_file_not_contains_str "agent field dropped" "$HOME_DIR/.agents/skills/do-tasks/SKILL.md" "agent:"
# FR-4.3: $ARGUMENTS preserved verbatim (not expanded).
assert_file_contains_str "\$ARGUMENTS preserved" "$HOME_DIR/.agents/skills/do-tasks/SKILL.md" 'Args: $ARGUMENTS'
# FR-4.1a: fields emitted in fixed order name -> description -> disable.
NAME_LN="$(grep -n '^name:' "$HOME_DIR/.agents/skills/do-tasks/SKILL.md" | head -1 | cut -d: -f1)"
DESC_LN="$(grep -n '^description:' "$HOME_DIR/.agents/skills/do-tasks/SKILL.md" | head -1 | cut -d: -f1)"
DMI_LN="$(grep -n '^disable-model-invocation:' "$HOME_DIR/.agents/skills/do-tasks/SKILL.md" | head -1 | cut -d: -f1)"
assert_gt "name before description" "$DESC_LN" "$NAME_LN"
assert_gt "description before disable" "$DMI_LN" "$DESC_LN"

# --- INT-2.2b: description with colon + quotes copied verbatim ---------------
rm -rf "$HOME_DIR/.agents"
mkdir -p "$FIX/templates/opencode/commands"
cat > "$FIX/templates/opencode/commands/plan-sprint.md" <<'CMD'
---
description: "Plan: a \"sprint\" with care"
agent: strategist
---

Body line.
CMD
gen_and_read plan-sprint >/dev/null
assert_file_contains_str "description with colon+quotes preserved" \
  "$HOME_DIR/.agents/skills/plan-sprint/SKILL.md" 'description: "Plan: a \"sprint\" with care"'

# --- INT-2.2c: missing description => empty string ---------------------------
rm -rf "$HOME_DIR/.agents"
cat > "$FIX/templates/opencode/commands/fix-bug.md" <<'CMD'
---
agent: builder
---

Fix the bug body.
CMD
gen_and_read fix-bug >/dev/null
assert_file_contains_str "missing description defaults empty" \
  "$HOME_DIR/.agents/skills/fix-bug/SKILL.md" 'description: '

# --- INT-2.2d: no frontmatter at all => body is whole file, desc "" ----------
rm -rf "$HOME_DIR/.agents"
# Remove all commands except one with no frontmatter.
rm -f "$FIX/templates/opencode/commands/"*.md
printf '%s\n' 'Just a body with no frontmatter at all.' > "$FIX/templates/opencode/commands/bare.md"
gen_and_read bare >/dev/null
assert_file_contains_str "no-frontmatter: name set" \
  "$HOME_DIR/.agents/skills/bare/SKILL.md" 'name: bare'
assert_file_contains_str "no-frontmatter: description empty" \
  "$HOME_DIR/.agents/skills/bare/SKILL.md" 'description: '
assert_file_contains_str "no-frontmatter: body preserved" \
  "$HOME_DIR/.agents/skills/bare/SKILL.md" 'Just a body with no frontmatter at all.'

# --- ERR-1.1: unclosed frontmatter => WARNING + default desc, body from L2 ----
rm -rf "$HOME_DIR/.agents"
rm -f "$FIX/templates/opencode/commands/"*.md
cat > "$FIX/templates/opencode/commands/broken.md" <<'CMD'
---
description: never closed
this is still body-ish
CMD
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_zero "unclosed frontmatter: exit 0 (ERR-1.1 non-fatal)" "$SYNC_RC"
assert_file_contains_str "unclosed frontmatter: WARNING emitted" "$OUT" "[WARNING]"
assert_file_contains_str "unclosed frontmatter: default empty description" \
  "$HOME_DIR/.agents/skills/broken/SKILL.md" 'description: '
assert_file_contains_str "unclosed frontmatter: name still set" \
  "$HOME_DIR/.agents/skills/broken/SKILL.md" 'name: broken'

# --- FR-4.1d: generated SKILL.md has a trailing newline ----------------------
rm -rf "$HOME_DIR/.agents"
rm -f "$FIX/templates/opencode/commands/"*.md
printf '%s' 'no trailing newline in source body' > "$FIX/templates/opencode/commands/trail.md"
gen_and_read trail >/dev/null
LAST_BYTE="$(( $(wc -c < "$HOME_DIR/.agents/skills/trail/SKILL.md") ))"
# Verify the file ends with a newline (FR-4.1d) by reading last char.
if [[ -n "$(tail -c1 "$HOME_DIR/.agents/skills/trail/SKILL.md" 2>/dev/null)" ]]; then
  check FAIL "trailing newline present (FR-4.1d)"
else
  check OK "trailing newline present (FR-4.1d)"
fi

rm -f "$OUT"
sync_done
