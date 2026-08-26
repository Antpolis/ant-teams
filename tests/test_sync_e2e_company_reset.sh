#!/usr/bin/env bash
#
# test_sync_e2e_company_reset.sh — init-company.sh --reset e2e + default-force.
#
# Traceability (2026-08-25 founder-direct tech-lead plan amending SPEC-002
# FR-12.2 / CLI-2.1):
#   - RESET-1 --reset moves EXACTLY the three installed trees — the canonical
#     OpenCode target (~/.config/opencode), ~/.agents/skills, and
#     ~/.agents/scripts — to <path>.bak.<UTC timestamp> directories before the
#     reinstall; one shared timestamp correlates the three backups.
#   - RESET-2 the run after --reset is a from-scratch reinstall: canonical
#     config and the full managed inventory are reinstalled from source, with
#     no carry-over of pre-reset live-tree content.
#   - RESET-3 everything OUTSIDE the three installed trees is untouched
#     (~/.agents itself, ~/.copilot/agents, arbitrary HOME files).
#   - FORCE-DEFAULT a normal no-flag init-company.sh run overwrites a locally
#     modified managed entry ([FORCE overwrite]) — the plan's unconditional
#     --force forwarding to scripts/sync-managed-skills.sh.
#
# Runs the REAL repo init-company.sh against a temp HOME so neither the real
# ~/.config/opencode nor ~/.agents is touched.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "--reset e2e: backup + fresh reinstall; default force"

HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$HOME_DIR"' EXIT
OUT="$(mktemp)"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"
CONFIG="$HOME_DIR/.config/opencode/opencode.json"

# Count <parent>/<base>.bak.* directories directly under parent (0 if none).
count_baks() {
  local parent="$1" base="$2"
  if [[ ! -d "$parent" ]]; then printf '0'; return; fi
  find "$parent" -mindepth 1 -maxdepth 1 -name "$base.bak.*" -type d 2>/dev/null | wc -l | tr -d ' '
}

# --- Seed the three installed trees + neighbors that must NOT move -----------
mkdir -p "$HOME_DIR/.config/opencode" "$HOME_DIR/.agents/skills/sentinel-skill" \
         "$HOME_DIR/.agents/scripts" "$HOME_DIR/.copilot/agents"
printf '{"sentinel":"config"}\n' > "$CONFIG"
printf 'sentinel skill\n' > "$HOME_DIR/.agents/skills/sentinel-skill/SKILL.md"
printf 'sentinel script\n' > "$HOME_DIR/.agents/scripts/sentinel.sh"
printf 'kept\n' > "$HOME_DIR/.agents/keep.txt"
printf 'kept\n' > "$HOME_DIR/.copilot/agents/keep.agent.md"
CFG_SENTINEL="$(sync_sha256 "$CONFIG")"

# --- RESET-1: --reset moves exactly the three trees to .bak.<UTC> ------------
sync_capture "$OUT" "$SYNC_REAL_COMPANY" "$HOME_DIR" --reset
assert_exit_zero "init-company --reset exit 0" "$SYNC_RC"

assert_eq "exactly one opencode backup" "$(count_baks "$HOME_DIR/.config" opencode)" "1"
assert_eq "exactly one skills backup" "$(count_baks "$HOME_DIR/.agents" skills)" "1"
assert_eq "exactly one scripts backup" "$(count_baks "$HOME_DIR/.agents" scripts)" "1"

# The backup suffix is a UTC timestamp shared by all three backups.
BAK_TS=""
for d in "$HOME_DIR/.config"/opencode.bak.*; do
  if [[ -d "$d" ]]; then BAK_TS="${d##*.bak.}"; fi
done
if [[ "$BAK_TS" =~ ^[0-9]{8}T[0-9]{6}Z$ ]]; then
  check OK "backup suffix is a UTC timestamp ($BAK_TS)"
else
  check FAIL "backup suffix is a UTC timestamp (got: $BAK_TS)"
fi
assert_eq "skills backup shares the run timestamp" \
  "$(basename "$(find "$HOME_DIR/.agents" -maxdepth 1 -name 'skills.bak.*' -type d)")" "skills.bak.$BAK_TS"
assert_eq "scripts backup shares the run timestamp" \
  "$(basename "$(find "$HOME_DIR/.agents" -maxdepth 1 -name 'scripts.bak.*' -type d)")" "scripts.bak.$BAK_TS"

# Pre-reset content is preserved inside the backups.
assert_exists "config backup present" "$HOME_DIR/.config/opencode.bak.$BAK_TS/opencode.json"
assert_eq "config backup keeps pre-reset content" \
  "$(sync_sha256 "$HOME_DIR/.config/opencode.bak.$BAK_TS/opencode.json")" "$CFG_SENTINEL"
assert_exists "skills backup keeps sentinel" "$HOME_DIR/.agents/skills.bak.$BAK_TS/sentinel-skill/SKILL.md"
assert_exists "scripts backup keeps sentinel" "$HOME_DIR/.agents/scripts.bak.$BAK_TS/sentinel.sh"
assert_file_contains_str "--reset reports each move" "$OUT" "Reset: moved"

# --- RESET-2: from-scratch reinstall -----------------------------------------
assert_exists "canonical config reinstalled" "$CONFIG"
assert_neq "reinstalled config is fresh (sentinel gone)" "$(sync_sha256 "$CONFIG")" "$CFG_SENTINEL"
assert_not_exists "canonical skills dir still not installed" "$HOME_DIR/.config/opencode/skills"
assert_exists "managed skill reinstalled (agent-communication-log)" \
  "$HOME_DIR/.agents/skills/agent-communication-log/SKILL.md"
assert_exists "command-derived skill reinstalled (do-tasks)" \
  "$HOME_DIR/.agents/skills/do-tasks/SKILL.md"
assert_exists "team scripts reinstalled" "$HOME_DIR/.agents/scripts/validate-agents-md.sh"
assert_not_exists "sentinel skill gone from live tree" "$HOME_DIR/.agents/skills/sentinel-skill"
assert_not_exists "sentinel script gone from live tree" "$HOME_DIR/.agents/scripts/sentinel.sh"

# The reset tree carries NO unmanaged siblings, so the managed dir count is
# exact: every source skill + command-derived entry, nothing else.
REAL_SKILLS="$(find "$SYNC_REAL_OPENCODE/skills" -mindepth 2 -maxdepth 2 -type f -name SKILL.md | wc -l | tr -d ' ')"
REAL_CMDS="$(find "$SYNC_REAL_OPENCODE/commands" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')"
EXPECTED_TOTAL=$(( REAL_SKILLS + REAL_CMDS ))
assert_eq "live skills dir has exactly the managed inventory" \
  "$(sync_count_dirs "$HOME_DIR/.agents/skills")" "$EXPECTED_TOTAL"
assert_eq "manifest rebuilt with full inventory" \
  "$(sync_manifest_count_entries "$MANIFEST")" "$EXPECTED_TOTAL"

# --- RESET-3: nothing outside the three installed trees moves ----------------
assert_exists "~/.copilot/agents untouched by reset" "$HOME_DIR/.copilot/agents/keep.agent.md"
assert_exists "~/.agents itself not moved" "$HOME_DIR/.agents/keep.txt"
assert_eq "no ~/.copilot backup" "$(count_baks "$HOME_DIR/.copilot" agents)" "0"
assert_eq "no ~/.agents backup (only its two subtrees moved)" \
  "$(count_baks "$HOME_DIR" .agents)" "0"

# --- FORCE-DEFAULT: a no-flag run force-overwrites a modified managed entry ---
TARGET="$HOME_DIR/.agents/skills/documentation-standard/SKILL.md"
SRC="$SYNC_REAL_OPENCODE/skills/documentation-standard/SKILL.md"
printf '\n# local operator edit\n' >> "$TARGET"
assert_neq "local edit changed the managed file" "$(sync_sha256 "$TARGET")" "$(sync_sha256 "$SRC")"
sync_capture "$OUT" "$SYNC_REAL_COMPANY" "$HOME_DIR"
assert_exit_zero "second (no-flag) run exit 0" "$SYNC_RC"
assert_file_contains_str "default run force-overwrites modified entry" "$OUT" "[FORCE overwrite]"
assert_eq "modified entry restored to source" "$(sync_sha256 "$TARGET")" "$(sync_sha256 "$SRC")"
# Unmanaged content is still never touched by the forced company run.
assert_exists "unmanaged ~/.agents file survives the forced run" "$HOME_DIR/.agents/keep.txt"

rm -f "$OUT"
sync_done
