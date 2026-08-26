#!/usr/bin/env bash
#
# test_sync_unit_copilot_agents.sh — SPEC-004 behavioral parity regression for
# the jq migration of sync_copilot_agents in init-company.sh.
#
# Traceability (reviewer P1 finding, PR #60, review loop 1):
#   - P1a: only agents whose prompt is a JSON string are emitted (objects,
#     numbers, booleans, null, and missing prompt are silently skipped).
#   - P1b: prompts are trimmed of leading/trailing whitespace (matches the
#     prior Node implementation's agent.prompt.trim()).
#   - P1c: name and description are JSON-quoted (@json) so YAML-significant
#     characters (colons, double-quotes, newlines) cannot corrupt the
#     frontmatter block.
#
# Strategy: build a minimal opencode.json fixture with edge-case agent
# definitions, invoke init-company.sh with an overridden HOME/OPENCODE_CONFIG_DIR,
# then inspect the generated .agent.md files.
#
set -euo pipefail

source "$(dirname "$0")/lib/sync_helpers.sh"

sync_begin "TEST-1.x copilot agents jq migration parity"

FIX="$(sync_make_fixture_repo_with_company)"
HOME_DIR="$(sync_make_home)"
trap 'rm -rf "$FIX" "$HOME_DIR"' EXIT

# Build a fixture opencode.json with edge-case agent definitions.
mkdir -p "$FIX/templates/opencode" "$FIX/templates/scripts"
cat > "$FIX/templates/opencode/opencode.json" <<'JSON'
{
  "agent": {
    "valid-agent": {
      "description": "A normal agent.",
      "prompt": "Do the thing.\n"
    },
    "whitespace-agent": {
      "description": "Trim test.",
      "prompt": "  \n  trimmed prompt  \n  "
    },
    "yaml-special-agent": {
      "description": "Has: \"quotes\" and\ncolons",
      "prompt": "Run it."
    },
    "null-prompt-agent": {
      "description": "Should be skipped.",
      "prompt": null
    },
    "object-prompt-agent": {
      "description": "Should be skipped.",
      "prompt": {"nested": "object"}
    },
    "number-prompt-agent": {
      "description": "Should be skipped.",
      "prompt": 42
    },
    "bool-prompt-agent": {
      "description": "Should be skipped.",
      "prompt": true
    },
    "missing-prompt-agent": {
      "description": "Should be skipped."
    },
    "no-desc-agent": {
      "prompt": "Fallback description test."
    }
  }
}
JSON

SCRIPT="$FIX/scripts/init-company.sh"
OUT="$(mktemp)"
AGENTS_DIR="$HOME_DIR/.copilot/agents"

# Run init-company.sh with a temp target so it only touches our fixture.
sync_capture "$OUT" "$SCRIPT" "$HOME_DIR" --target-dir "$HOME_DIR/.config/opencode"
assert_exit_zero "init-company exit code" "$SYNC_RC"

# --- P1a: non-string prompts are silently skipped ---
for bad_agent in null-prompt-agent object-prompt-agent number-prompt-agent bool-prompt-agent missing-prompt-agent; do
  if [[ -f "$AGENTS_DIR/${bad_agent}.agent.md" ]]; then
    check FAIL "${bad_agent}.agent.md should NOT exist (non-string prompt)"
  else
    check OK "${bad_agent}.agent.md absent (non-string prompt skipped)"
  fi
done

# --- P1a: valid string prompts ARE emitted ---
for good_agent in valid-agent whitespace-agent yaml-special-agent no-desc-agent; do
  if [[ -f "$AGENTS_DIR/${good_agent}.agent.md" ]]; then
    check OK "${good_agent}.agent.md exists (string prompt)"
  else
    check FAIL "${good_agent}.agent.md should exist (string prompt)"
  fi
done

# --- P1b: prompt whitespace is trimmed ---
if [[ -f "$AGENTS_DIR/whitespace-agent.agent.md" ]]; then
  # The prompt is the first non-empty line after the second "---" (closing frontmatter fence).
  prompt_body="$(awk '/^---$/{c++; next} c==2 && NF{print; exit}' "$AGENTS_DIR/whitespace-agent.agent.md")"
  if [[ "$prompt_body" == "trimmed prompt" ]]; then
    check OK "whitespace-agent prompt trimmed correctly"
  else
    check FAIL "whitespace-agent prompt NOT trimmed (got: '$prompt_body')"
  fi
else
  check FAIL "whitespace-agent.agent.md missing (cannot check trim)"
fi

# --- P1c: YAML-significant characters in description are JSON-quoted ---
if [[ -f "$AGENTS_DIR/yaml-special-agent.agent.md" ]]; then
  desc_line="$(grep '^description:' "$AGENTS_DIR/yaml-special-agent.agent.md")"
  # The description should be JSON-quoted: "Has: \"quotes\" and\ncolons"
  # @json produces a JSON string with escaped quotes and \n for newlines.
  if printf '%s' "$desc_line" | grep -qF '"Has:'; then
    check OK "yaml-special-agent description is JSON-quoted (starts with quote)"
  else
    check FAIL "yaml-special-agent description NOT JSON-quoted (got: '$desc_line')"
  fi
else
  check FAIL "yaml-special-agent.agent.md missing (cannot check quoting)"
fi

# --- P1c: name is also JSON-quoted (though simple names are safe, the contract requires it) ---
if [[ -f "$AGENTS_DIR/valid-agent.agent.md" ]]; then
  name_line="$(grep '^name:' "$AGENTS_DIR/valid-agent.agent.md")"
  if printf '%s' "$name_line" | grep -qF '"valid-agent"'; then
    check OK "valid-agent name is JSON-quoted"
  else
    check FAIL "valid-agent name NOT JSON-quoted (got: '$name_line')"
  fi
else
  check FAIL "valid-agent.agent.md missing (cannot check name quoting)"
fi

# --- P1c: fallback description (no description provided) uses default and is JSON-quoted ---
if [[ -f "$AGENTS_DIR/no-desc-agent.agent.md" ]]; then
  desc_line="$(grep '^description:' "$AGENTS_DIR/no-desc-agent.agent.md")"
  if printf '%s' "$desc_line" | grep -qF '"Use when acting as the no-desc-agent role."'; then
    check OK "no-desc-agent fallback description is JSON-quoted"
  else
    check FAIL "no-desc-agent fallback description NOT JSON-quoted (got: '$desc_line')"
  fi
else
  check FAIL "no-desc-agent.agent.md missing (cannot check fallback)"
fi

rm -f "$OUT"
sync_done
