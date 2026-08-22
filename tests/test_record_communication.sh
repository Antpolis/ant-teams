#!/usr/bin/env bash
#
# test_record_communication.sh — behavioral tests for scripts/record-communication.sh.
#
# Covers the record/list MVP contract:
#   - record creates one event file at
#     $ANT_TEAM_DOCS_PROJECT_PATH/agent-communication/issues/issue-<n>/ or
#     milestones/<slug>/ named YYYY-MM-DD-<from>-<title-slug>-<status>.md
#   - the event uses the APPROVED central-vault template format: required
#     frontmatter keys, scope tag, and the Communication Event body structure
#   - values are substituted literally (no regex mangling of & / \ $)
#   - existing event files are never overwritten (exit 2)
#   - invalid input, missing ./.github-project.env, and a missing approved
#     template each fail with a clear message (exit 1)
#   - Obsidian-only writes: nothing outside agent-communication/ changes,
#     role memory (agent-memory/) is untouched, and the script source never
#     calls the GitHub CLI (no GitHub comment writes)
#
# All fixtures live in a temp vault + temp project root; the real vault is
# never touched. Standalone: `set -euo pipefail`, mktemp + trap cleanup.
# Run directly: `bash tests/test_record_communication.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RECORDER="$REPO_ROOT/scripts/record-communication.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok()   { PASS=$((PASS + 1)); printf '  ok   - %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL - %s\n' "$1" >&2; }

assert_exit_code()  { if [[ "$2" == "$3" ]]; then ok "$1: exit $2"; else fail "$1: expected exit $3 got $2"; fi; }
assert_contains()   { if grep -qF -- "$3" "$2" 2>/dev/null; then ok "$1: substring present"; else fail "$1: substring MISSING ($3)"; fi; }
assert_not_contains() { if grep -qF -- "$3" "$2" 2>/dev/null; then fail "$1: unexpected substring ($3)"; else ok "$1: substring absent"; fi; }
assert_exists()     { if [[ -e "$2" ]]; then ok "$1 exists"; else fail "$1 missing ($2)"; fi; }
assert_str_contains() { if grep -qF -- "$3" <<<"$2"; then ok "$1: substring present"; else fail "$1: substring MISSING ($3)"; fi; }
assert_str_not_matches() { if grep -qE -- "$3" <<<"$2"; then fail "$1: unexpected match ($3)"; else ok "$1: no match"; fi; }

# Approved template fixture — mirrors the central-vault template at
# 01-Architecture-Meta/Templates/Agent Communication Template.md.
write_approved_template() {
  local dir="$1"
  mkdir -p "$dir/01-Architecture-Meta/Templates"
  cat > "$dir/01-Architecture-Meta/Templates/Agent Communication Template.md" <<'TPL'
---
doc_type: agent-communication
project:
issue:
milestone:
from_role:
to_role:
communication_type:
status: open
date: "{{date:YYYY-MM-DD}}"
github_issue:
github_pr:
tags:
  - agent-communication
---

# Communication Event: {{title}}

Role:
Target Role:
State:
Spec / Milestone:
Task / Issue:
Branch / PR:

Summary:

- <!-- What happened, decided, or changed. -->

Evidence:

- <!-- Tests, commands, screenshots, links, or PR references. -->

Open Findings / Risks:

- <!-- Finding, or none. -->

Blockers / Defer Decisions:

- <!-- Blocker, defer decision, or none. -->

Next Action:

- <!-- What the next role should do; state the exact action or question. -->
TPL
}

make_project() {
  # make_project NAME — temp project root with .github-project.env pointing at
  # a temp vault; echoes the project root path.
  local name="$1"
  local project="$TMP/$name"
  local vault="$TMP/$name-vault"
  mkdir -p "$project" "$vault/02-Architecture-Landscape/projects/demo" "$vault/02-Architecture-Landscape/projects/demo/agent-memory"
  write_approved_template "$vault"
  printf 'pre-existing role memory\n' > "$vault/02-Architecture-Landscape/projects/demo/agent-memory/builder-memory.md"
  cat > "$project/.github-project.env" <<ENV
export ANT_TEAM_GITHUB_REPO='Antpolis/ant-teams'
export ANT_TEAM_DOCS_VAULT_PATH='$vault'
export ANT_TEAM_DOCS_PROJECT_NAME='ant-teams'
export ANT_TEAM_DOCS_PROJECT_PATH='$vault/02-Architecture-Landscape/projects/demo'
ENV
  printf '%s' "$project"
}

vault_of() { printf '%s' "$TMP/$1-vault"; }

record() {
  # record PROJROOT [args...] — run the recorder from the project root.
  local project="$1"; shift
  ( cd "$project" && bash "$RECORDER" "$@" )
}

tree_snapshot() {
  find "$1" -type f -exec sha256sum {} + 2>/dev/null | sort
}

echo "=== record-communication.sh: static invariants ==="

GH_SOURCE="$(cat "$RECORDER")"
# gh at command position (line start, or after ; & | ( ) — covers $(gh ...) and
# backtick forms), while plain mentions such as "never calls gh," do not match.
assert_str_not_matches "source never calls gh" "$GH_SOURCE" '(^|[;&|(])[[:space:]]*gh[[:space:]]'
assert_contains "source documents Obsidian-only writes" "$RECORDER" "Obsidian-only writes"

echo "=== record: issue event from the approved template ==="

PROJ="$(make_project p1)"
VAULT="$(vault_of p1)"
PROJ_PATH="$VAULT/02-Architecture-Landscape/projects/demo"
BEFORE="$(tree_snapshot "$VAULT")"

OUT="$(record "$PROJ" record --issue 123 --from builder --to reviewer --type handoff \
  --title "Implementation handoff" --pr 45 --state "In Review" \
  --summary 'A & b / c \ d $x done' 2>"$TMP/rec1.err")" || REC_RC=$?
assert_exit_code "record exits 0" "${REC_RC:-0}" "0"

EVENT="$PROJ_PATH/agent-communication/issues/issue-123/$(date +%Y-%m-%d)-builder-implementation-handoff-open.md"
assert_exists "event file at convention path" "$EVENT"

# Frontmatter: every convention key, filled from flags/env.
for pair in \
  "doc_type: agent-communication" \
  "project: ant-teams" \
  "issue: 123" \
  "from_role: builder" \
  "to_role: reviewer" \
  "communication_type: handoff" \
  "status: open" \
  "github_issue: https://github.com/Antpolis/ant-teams/issues/123" \
  "github_pr: https://github.com/Antpolis/ant-teams/pull/45" \
  "- agent-communication" \
  "- issue/123"; do
  assert_contains "frontmatter [$pair]" "$EVENT" "$pair"
done
assert_contains "date is ISO today" "$EVENT" "date: $(date +%Y-%m-%d)"

# Body structure: the Communication Event field lines and sections.
for line in "Role: builder" "Target Role: reviewer" "State: In Review" "Task / Issue: #123" \
  "Branch / PR: https://github.com/Antpolis/ant-teams/pull/45" "Summary:" "Evidence:" \
  "Open Findings / Risks:" "Blockers / Defer Decisions:" "Next Action:"; do
  assert_contains "body [$line]" "$EVENT" "$line"
done
assert_contains "summary bullet literal substitution" "$EVENT" "- A & b / c \ d \$x done"

# Obsidian-only writes: nothing outside agent-communication/ changed and role
# memory is untouched.
AFTER="$(tree_snapshot "$VAULT")"
UNCHANGED="$(diff <(printf '%s\n' "$BEFORE") <(printf '%s\n' "$AFTER" | grep -v 'agent-communication/') || true)"
if [[ -z "$UNCHANGED" ]]; then
  ok "vault unchanged outside agent-communication/"
else
  fail "unexpected vault changes outside agent-communication/: $UNCHANGED"
fi
assert_contains "role memory untouched (content intact)" \
  "$PROJ_PATH/agent-memory/builder-memory.md" "pre-existing role memory"
MEM_COUNT="$(find "$PROJ_PATH/agent-memory" -type f | wc -l | tr -d ' ')"
if [[ "$MEM_COUNT" == "1" ]]; then ok "no new agent-memory files"; else fail "agent-memory gained files ($MEM_COUNT)"; fi
EVENT_COUNT="$(find "$PROJ_PATH/agent-communication" -type f | wc -l | tr -d ' ')"
if [[ "$EVENT_COUNT" == "1" ]]; then ok "exactly one event file written"; else fail "expected 1 event file, found $EVENT_COUNT"; fi

echo "=== record: milestone event, closed status, PR URL passthrough ==="

record "$PROJ" record --milestone "SPEC-003" --from tech-lead --to builder --type decision \
  --title "Guardrails set" --status closed --pr "https://github.com/Antpolis/ant-teams/pull/99" \
  --summary "Scope and guardrails approved." >/dev/null 2>&1
MEVENT="$PROJ_PATH/agent-communication/milestones/spec-003/$(date +%Y-%m-%d)-tech-lead-guardrails-set-closed.md"
assert_exists "milestone event at convention path" "$MEVENT"
assert_contains "milestone frontmatter slug" "$MEVENT" "milestone: spec-003"
assert_contains "milestone scope tag" "$MEVENT" "- milestone/spec-003"
assert_contains "closed status" "$MEVENT" "status: closed"
assert_contains "PR URL passthrough" "$MEVENT" "Branch / PR: https://github.com/Antpolis/ant-teams/pull/99"
assert_contains "milestone body fill" "$MEVENT" "Spec / Milestone: spec-003"

echo "=== record: never overwrites (exit 2) ==="

set +e
DUP_OUT="$(record "$PROJ" record --issue 123 --from builder --to reviewer --type handoff \
  --title "Implementation handoff" 2>&1)"; DUP_RC=$?
set -e
assert_exit_code "duplicate event refused" "$DUP_RC" "2"
assert_str_contains "duplicate names the existing file" "$DUP_OUT" "already exists"

echo "=== record: input validation (exit 1) ==="

set +e
V1="$(record "$PROJ" record --issue 123 --from builder --to reviewer --type handoff --title 'one two three four five six' 2>&1)"; R1=$?
V2="$(record "$PROJ" record --issue 123 --from builder --to reviewer --type handoff --title t --status maybe 2>&1)"; R2=$?
V3="$(record "$PROJ" record --issue abc --from builder --to reviewer --type handoff --title t 2>&1)"; R3=$?
V4="$(record "$PROJ" record --issue 5 --milestone slug --from builder --to reviewer --type handoff --title t 2>&1)"; R4=$?
V5="$(record "$PROJ" record --issue 123 --to reviewer --type handoff --title t 2>&1)"; R5=$?
V6="$(cd "$PROJ" && bash "$RECORDER" record --issue 123 --from builder --to reviewer --type handoff --title 2>&1)"; R6=$?
set -e
assert_exit_code "title over five words refused" "$R1" "1"
assert_str_contains "title word-count message" "$V1" "five words or fewer"
assert_exit_code "bad status refused" "$R2" "1"
assert_exit_code "non-numeric issue refused" "$R3" "1"
assert_exit_code "issue+milestone mutual exclusion" "$R4" "1"
assert_exit_code "missing --from refused" "$R5" "1"
assert_str_contains "--from required message" "$V5" "--from is required"
assert_exit_code "missing flag value refused" "$R6" "1"
assert_str_contains "missing value message" "$V6" "missing value for --title"

echo "=== record: missing environment (exit 1) ==="

BARE="$TMP/bare-project"
mkdir -p "$BARE"
set +e
ENV_OUT="$(cd "$BARE" && bash "$RECORDER" record --issue 1 --from a --to b --type handoff --title t 2>&1)"; ENV_RC=$?
set -e
assert_exit_code "missing .github-project.env refused" "$ENV_RC" "1"
assert_str_contains "missing env message names the file" "$ENV_OUT" ".github-project.env"

echo "=== record: missing approved template (exit 1) ==="

NOTPL="$(make_project p2)"
rm "$(vault_of p2)/01-Architecture-Meta/Templates/Agent Communication Template.md"
set +e
TPL_OUT="$(record "$NOTPL" record --issue 7 --from builder --to reviewer --type handoff --title t 2>&1)"; TPL_RC=$?
set -e
assert_exit_code "missing template refused" "$TPL_RC" "1"
assert_str_contains "missing template names the path" "$TPL_OUT" "Agent Communication Template"
assert_str_contains "missing template does not invent format" "$TPL_OUT" "do not invent the format"

echo "=== list: issue, milestone, and all ==="

LIST_OUT="$(record "$PROJ" list --issue 123)"
assert_str_contains "list --issue shows event" "$LIST_OUT" "builder -> reviewer"
assert_str_contains "list --issue shows type and status" "$LIST_OUT" "handoff  open"
assert_str_contains "list --issue shows date" "$LIST_OUT" "$(date +%Y-%m-%d)"
LIST_M="$(record "$PROJ" list --milestone spec-003)"
assert_str_contains "list --milestone shows event" "$LIST_M" "tech-lead -> builder"
assert_str_contains "list --milestone shows closed status" "$LIST_M" "closed"
LIST_A="$(record "$PROJ" list --all)"
assert_str_contains "list --all includes issue event" "$LIST_A" "issue-123"
assert_str_contains "list --all includes milestone event" "$LIST_A" "spec-003"
EMPTY_OUT="$(record "$PROJ" list --issue 999 2>&1)" && EMPTY_RC=0 || EMPTY_RC=$?
assert_exit_code "list with no events exits 0" "$EMPTY_RC" "0"
assert_str_contains "list with no events says so" "$EMPTY_OUT" "No communication events recorded"

printf '\n[test_record_communication] %d passed, %d failed\n' "$PASS" "$FAIL"
if [[ "$FAIL" -gt 0 ]]; then exit 1; fi
exit 0
