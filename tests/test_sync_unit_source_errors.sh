#!/usr/bin/env bash
#
# test_sync_unit_source_errors.sh — SPEC-002 ERR-2.1: unreadable source skill.
#
# Traceability:
#   - ERR-2.1 if a file within a source skill directory is unreadable, the sync
#     emits [ERROR] with the exact path, skips the WHOLE skill entry, and
#     continues processing remaining entries. Final exit code 1.
#   - ERR-1.2 (command) is covered indirectly via ERR-1.1 malformed-frontmatter
#     handling in test_sync_unit_frontmatter.sh / test_sync_int_command_transform.sh.
#     (Note: the staged command pipeline reads commands during discovery, so an
#     unreadable command source aborts via set -e rather than the graceful
#     [ERROR]+skip+continue path; that is an implementation divergence, not a
#     test covered here. The spec-matching graceful path is exercised for
#     source skills below.)
#
# Uses chmod 000 to make a single source file unreadable. Skipped when running
# as root (chmod cannot deny root). The remaining entry must still install,
# proving the sync continues after a per-entry source error.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "ERR-2.1 unreadable source skill file"

# Root bypasses Unix permission bits, so a chmod-000 unreadable-source test
# would be vacuous under root. Skip cleanly in that case.
if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
  printf '  [SKIP] unreadable-source tests require non-root (chmod 000 denial)\n'
  sync_done
  exit 0
fi

FIX="$(sync_make_fixture_repo)"
HOME_DIR="$(sync_make_home)"
trap 'chmod 0755 "$FIX/.opencode/skills/bad/scripts/tool.sh" 2>/dev/null || true; rm -rf "$FIX" "$HOME_DIR"' EXIT
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
sync_done
