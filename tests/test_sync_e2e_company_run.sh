#!/usr/bin/env bash
#
# test_sync_e2e_company_run.sh — SPEC-002 TEST-3.1: real sync-company.sh run.
#
# Traceability:
#   - FR-1.1/.2 a default sync-company.sh run installs .opencode/ into
#     ~/.config/opencode (full-replace + provider merge) AND does not weaken
#     the canonical install.
#   - FR-2.1/.2 the managed sync populates ~/.agents/skills with all source
#     skills + command-derived skills.
#   - FR-12.2 sync-company invokes sync-managed-skills after the canonical
#     install; exit code reflects the worst outcome (here 0).
#   - AC-1.1 / AC-2.1 exactly 34 managed entries (26 source + 8 command-derived,
#     0 name collisions in the real source tree); unmanaged content untouched.
#
# Runs the REAL repo scripts against a temp HOME so neither the real
# ~/.config/opencode nor ~/.agents/skills is touched.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-3.1 real sync-company.sh run"

HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$HOME_DIR"' EXIT
OUT="$(mktemp)"
MANIFEST="$HOME_DIR/.agents/skills/.manifest.json"

# Seed unmanaged sibling content to prove it survives the real run.
mkdir -p "$HOME_DIR/.agents/skills/my-custom-skill"
printf 'operator-owned\n' > "$HOME_DIR/.agents/skills/my-custom-skill/SKILL.md"
MYHASH="$(sync_sha256 "$HOME_DIR/.agents/skills/my-custom-skill/SKILL.md")"

# Count REAL source inventory for an exact assertion.
REAL_SKILLS="$(sync_count_dirs "$SYNC_REAL_OPENCODE/skills")"
REAL_CMDS="$(find "$SYNC_REAL_OPENCODE/commands" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l | tr -d ' ')"
EXPECTED_TOTAL=$(( REAL_SKILLS + REAL_CMDS ))

sync_capture "$OUT" "$SYNC_REAL_COMPANY" "$HOME_DIR"
assert_exit_zero "sync-company.sh exit 0" "$SYNC_RC"

# FR-1: canonical install target populated.
assert_exists "canonical opencode.json installed" "$HOME_DIR/.config/opencode/opencode.json"
assert_exists "canonical skills dir installed" "$HOME_DIR/.config/opencode/skills"
assert_exists "canonical commands dir installed" "$HOME_DIR/.config/opencode/commands"
assert_file_contains_str "sync-company reports canonical sync" "$OUT" "Synced"

# FR-2 / AC-2.1: managed skills populated with the expected entry count.
# Raw dir count includes any unmanaged sibling (my-custom-skill), so the exact
# managed count is verified via the manifest; the dir count is a lower bound.
assert_ge "managed dir count >= skills + commands" \
  "$(sync_count_dirs "$HOME_DIR/.agents/skills")" "$EXPECTED_TOTAL"
assert_eq "manifest records 34 managed entries" \
  "$(sync_manifest_count_entries "$MANIFEST")" "$EXPECTED_TOTAL"
assert_eq "expected total is 34 (26+8)" "$EXPECTED_TOTAL" "34"
assert_eq "manifest present" "$(sync_manifest_is_valid_json "$MANIFEST")" "yes"

# A representative source skill and a command-derived skill are present.
assert_exists "source skill installed (agent-communication-log)" \
  "$HOME_DIR/.agents/skills/agent-communication-log/SKILL.md"
assert_exists "command-derived installed (do-tasks)" \
  "$HOME_DIR/.agents/skills/do-tasks/SKILL.md"

# SEC-5.1: unmanaged content untouched.
assert_eq "unmanaged content untouched" \
  "$(sync_sha256 "$HOME_DIR/.agents/skills/my-custom-skill/SKILL.md")" "$MYHASH"

rm -f "$OUT"
sync_done
