#!/usr/bin/env bash
#
# test_sync_unit_copilot_agents.sh — regression tests for sync_copilot_agents
# in init-company.sh after the source of truth moved from inline .agent
# objects in opencode.json to markdown files under templates/opencode/agents/.
#
# Coverage:
#   - Every templates/opencode/agents/<id>.md becomes ~/.copilot/agents/<id>.agent.md.
#   - Frontmatter is Copilot-compatible: name, description (from the source
#     frontmatter), and role-appropriate tools (reviewer is read-only).
#   - The source body is preserved after the frontmatter block.
#   - Stale managed .agent.md files (removed from source) are deleted, but
#     user-created .agent.md files are never touched.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-1.x copilot agents markdown-source conversion"

FIX="$(sync_make_fixture_repo_with_company)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT

# Build fixture agent markdown sources.
AGENTS_SRC="$FIX/templates/opencode/agents"
mkdir -p "$AGENTS_SRC" "$FIX/templates/scripts"

cat > "$AGENTS_SRC/valid-agent.md" <<'MD'
---
description: A normal agent.
mode: all
model: test/model
subagent: true
---

Do the thing.
MD

cat > "$AGENTS_SRC/reviewer.md" <<'MD'
---
description: Reviews changes.
mode: all
subagent: true
---

Review carefully.
MD

cat > "$AGENTS_SRC/describe-colon.md" <<'MD'
---
description: Uses: colons and "quotes"
mode: all
subagent: true
---

Body with: colons.
MD

SCRIPT="$FIX/scripts/init-company.sh"
OUT="$(mktemp)"
AGENTS_DIR="$HOME_DIR/.copilot/agents"

# Run init-company.sh with a temp target so it only touches our fixture.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR" --target-dir "$HOME_DIR/.config/opencode"
assert_exit_zero "init-company exit code" "$SYNC_RC"

# --- Conversion: each source .md becomes a Copilot .agent.md -----------------
for agent in valid-agent reviewer describe-colon; do
  assert_exists "Copilot agent generated ($agent)" "$AGENTS_DIR/$agent.agent.md"
done

# --- Frontmatter: name and description derived from the source ---------------
assert_file_contains_str "name derived from file stem" \
  "$AGENTS_DIR/valid-agent.agent.md" "name: valid-agent"
assert_file_contains_str "description carried from source frontmatter" \
  "$AGENTS_DIR/valid-agent.agent.md" "description: A normal agent."
assert_file_contains_str "description with YAML-significant characters is carried verbatim" \
  "$AGENTS_DIR/describe-colon.agent.md" 'description: Uses: colons and "quotes"'

# --- Tools: reviewer stays read-only, others get the full set ---------------
assert_file_contains_str "reviewer agent remains read-only" \
  "$AGENTS_DIR/reviewer.agent.md" "tools: [read, search, execute, agent, web]"
assert_file_contains_str "non-reviewer agent gets edit tools" \
  "$AGENTS_DIR/valid-agent.agent.md" "tools: [read, search, edit, execute, agent, web, todo]"

# --- Body preserved -----------------------------------------------------------
assert_file_contains_str "body preserved (valid-agent)" \
  "$AGENTS_DIR/valid-agent.agent.md" "Do the thing."

# --- Manifest written ---------------------------------------------------------
if [[ -f "$AGENTS_DIR/.managed-agents" ]]; then
  check OK "managed-agents manifest written"
else
  check FAIL "managed-agents manifest missing"
fi

# --- Stale cleanup: managed agents removed, user files untouched -------------
rm "$AGENTS_SRC/describe-colon.md"
printf 'user content\n' > "$AGENTS_DIR/user-agent.agent.md"

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR" --target-dir "$HOME_DIR/.config/opencode"
assert_exit_zero "second init-company exit code" "$SYNC_RC"

assert_not_exists "stale managed agent removed" "$AGENTS_DIR/describe-colon.agent.md"
assert_exists "user agent file untouched" "$AGENTS_DIR/user-agent.agent.md"
assert_exists "surviving agent still present" "$AGENTS_DIR/valid-agent.agent.md"

# --- Update-in-place: existing files keep user frontmatter fields -----------
mkdir -p "$AGENTS_DIR"
cat > "$AGENTS_DIR/valid-agent.agent.md" <<'MD'
---
description: Old description.
model: user/custom-model
tools: [read, web]
---

Old body that must be replaced.
MD

sync_capture "$OUT" "$SCRIPT" "$HOME_DIR" --target-dir "$HOME_DIR/.config/opencode"
assert_exit_zero "third init-company exit code" "$SYNC_RC"

assert_file_contains_str "update preserves user tools" \
  "$AGENTS_DIR/valid-agent.agent.md" "tools: [read, web]"
assert_file_contains_str "update preserves user model" \
  "$AGENTS_DIR/valid-agent.agent.md" "model: user/custom-model"
assert_file_contains_str "update refreshes description" \
  "$AGENTS_DIR/valid-agent.agent.md" "description: A normal agent."
assert_file_contains_str "update refreshes body" \
  "$AGENTS_DIR/valid-agent.agent.md" "Do the thing."
if grep -q "Old body" "$AGENTS_DIR/valid-agent.agent.md"; then
  check FAIL "update replaced old body"
else
  check OK "update replaced old body"
fi

rm -f "$OUT"
sync_done
