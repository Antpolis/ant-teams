#!/usr/bin/env bash
#
# test_sync_unit_source_errors.sh — SPEC-002 unreadable source error handling.
#
# Traceability:
#   - ERR-2.1 if a file within a source skill directory is unreadable, the sync
#     emits [ERROR] with the exact path, skips the WHOLE skill entry, and
#     continues processing remaining entries. Final exit code 1.
#   - ERR-1.2 if a source command file is unreadable, the sync emits [ERROR]
#     with the exact path, skips that command entry, continues processing the
#     remaining command entries, and exits 1. (A guard in the command staging
#     loop reports the file gracefully instead of aborting inside
#     generate_command_skill under `set -e`.)
#
# Both scenarios use chmod 000 to make a single source file unreadable. Skipped
# when running as root (chmod cannot deny root). The remaining entry must still
# install in each case, proving the sync continues after a per-entry source error.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "ERR-2.1 + ERR-1.2 unreadable source error handling"

# Root bypasses Unix permission bits, so a chmod-000 unreadable-source test
# would be vacuous under root. Skip cleanly in that case.
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  printf '  [SKIP] unreadable-source tests require non-root (chmod 000 denial)\n'
  sync_done
  exit 0
fi

# All temp dirs are initialized up front so the EXIT trap is safe under
# `set -u` even on the early-exit paths above (root skip) or a mid-test failure.
FIX="" HOME_DIR="" FIX2="" HOME_DIR2=""
trap 'rm -rf "$FIX" "$FIX2" "$HOME_DIR" "$HOME_DIR2" 2>/dev/null || true' EXIT

# ----------------------------------------------------------------------------
# ERR-2.1: unreadable file inside a source skill -> skip whole skill, continue.
# ----------------------------------------------------------------------------
FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
SCRIPT="$FIX/scripts/sync-managed-skills.sh"
OUT="$(mktemp)"

# One unreadable file inside the "bad" skill; a "good" sibling must still install.
mkdir -p "$FIX/.opencode/skills/bad/scripts" "$FIX/.opencode/skills/good"
printf -- '---\nname: bad\ndescription: b\n---\n\nbad\n'  > "$FIX/.opencode/skills/bad/SKILL.md"
printf 'legit but unreadable\n'                            > "$FIX/.opencode/skills/bad/scripts/tool.sh"
chmod 000 "$FIX/.opencode/skills/bad/scripts/tool.sh"
printf -- '---\nname: good\ndescription: g\n---\n\ngood\n' > "$FIX/.opencode/skills/good/SKILL.md"

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR"
assert_exit_nonzero "unreadable skill: non-zero exit" "$SYNC_RC"
assert_eq "unreadable skill: exit 1 (ERR-2.1)" "$SYNC_RC" "1"
assert_file_contains_str "unreadable skill: [ERROR] emitted" "$OUT" "[ERROR]"
assert_file_contains_str "unreadable skill: path named" "$OUT" "tool.sh"
# The bad skill must NOT be installed (whole entry skipped).
assert_not_exists "bad skill not installed" "$HOME_DIR/.agents/skills/bad"
# The good sibling must still install (sync continues after the per-entry error).
assert_exists "good sibling installed despite error" "$HOME_DIR/.agents/skills/good/SKILL.md"

rm -f "$OUT"

# ----------------------------------------------------------------------------
# ERR-1.2: unreadable source command file -> skip that command, continue.
# The command staging loop reads each source command via generate_command_skill;
# an unreadable source must be reported with [ERROR] + skip + continue (and a
# final exit 1 via HAD_SOURCE_ERROR) instead of aborting the whole script under
# `set -e`. The sibling good command must still install.
# ----------------------------------------------------------------------------
FIX2="$(sync_make_fixture_repo)"
HOME_DIR2="$(sync_make_home)"
SCRIPT2="$FIX2/scripts/sync-managed-skills.sh"
OUT2="$(mktemp)"

printf -- '---\ndescription: bad\n---\n\nbad body\n'   > "$FIX2/.opencode/commands/badcmd.md"
printf -- '---\ndescription: good\n---\n\ngood body\n' > "$FIX2/.opencode/commands/goodcmd.md"
chmod 000 "$FIX2/.opencode/commands/badcmd.md"

sync_capture "$OUT2" "$SCRIPT2" "$HOME_DIR2"
assert_exit_nonzero "unreadable command: non-zero exit" "$SYNC_RC"
assert_eq "unreadable command: exit 1 (ERR-1.2)" "$SYNC_RC" "1"
assert_file_contains_str "unreadable command: [ERROR] emitted" "$OUT2" "[ERROR]"
assert_file_contains_str "unreadable command: path named" "$OUT2" "badcmd.md"
# The bad command must NOT be installed as a derived skill (entry skipped).
assert_not_exists "bad command not installed" "$HOME_DIR2/.agents/skills/badcmd"
# The good command must still install (sync continues after the staging skip).
assert_exists "good command installed despite error" "$HOME_DIR2/.agents/skills/goodcmd/SKILL.md"

rm -f "$OUT2"
sync_done
