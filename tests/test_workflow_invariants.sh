#!/usr/bin/env bash
#
# tests/test_workflow_invariants.sh — workflow-revision invariants (2026-08).
#
# Migrated from tests/test_workflow_invariants.js (SPEC-004-T4, issue #54).
# Assertion parity: all 59 Node checks migrated 1:1 against the current
# master assertions (post #73 GitHub-first record language, which the earlier
# draft of this harness predated). None weakened.
#
# Locks the agreed workflow revision into executable checks so later edits
# cannot silently regress it:
#
#   INV-1  Canonical state model (Open → … → Done; Need attentions
#          founder-only; Blocked exception).
#   INV-2  Canonical state set as constants; .github-project.env carries the
#          verified Workflow State field/option IDs (env-only, no JSON).
#   INV-3  The GitHub helper targets the canonical Workflow State field and
#          never mutates remote board options; role prompts use the
#          centralized wrapper.
#   INV-4  Record split: GitHub issue/PR comments and Project Workflow State
#          are the operational collaboration record; Obsidian holds curated
#          durable knowledge; session-context is the scoped local carve-out.
#   INV-5  Tech-lead owns merge and cleanup.
#   INV-6  ANT_TEAM_SCRIPTS prerequisite; pm-lib family stays retired.
#   INV-7  /migrate command and --migrate-agent-md are retired.
#   INV-8  Orchestrator model stays openai/gpt-6-luna (agent frontmatter).
#   INV-9  project-init is env-only with NO JSON import/removal path.
#   INV-10 Runtime metadata comes from .github-project.env, not JSON parsing.
#   INV-11 No routine Obsidian communication-event regression; SPEC ID and
#          closeout contracts; role-memory is never a completion gate;
#          init-project is a native source skill.
#   INV-12 No legacy state names; issue/PR template contracts.
#   INV-13 No legacy roles/statuses on active surfaces.
#   INV-14 README reflects the current model.
#   INV-15 No stale ANT_TEAM_GITHUB_STATUS_* legacy env keys.
#   INV-16 No ANT_TEAM_DOCS_PROJECT_PATH_TEMPLATE on any active surface.
#   INV-17 Session context is a local, per-root-session, non-authoritative
#          tier (GOV-001).
#
# No network access. Temp fixtures only.
#
# Run directly: `bash tests/test_workflow_invariants.sh`.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/init_helpers.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

OUT="$TMP/out.txt"
ERR="$TMP/err.txt"

# --- Building blocks -------------------------------------------------------------

# read_file REL — print a repo-rooted file.
read_file() { cat "$INIT_REPO_ROOT/$1"; }

# must_contain CONTENT NEEDLE CONTEXT — fail (return 1) when the needle is absent.
must_contain() {
  local content="$1" needle="$2" context="${3:-content}"
  if ! grep -qF -- "$needle" <<< "$content"; then
    printf 'FAIL - %s must contain %s\n' "$context" "$needle" >&2
    return 1
  fi
}

# must_not_contain CONTENT NEEDLE CONTEXT — fail (return 1) when the needle is present.
must_not_contain() {
  local content="$1" needle="$2" context="${3:-content}"
  if grep -qF -- "$needle" <<< "$content"; then
    printf 'FAIL - %s must not contain %s\n' "$context" "$needle" >&2
    return 1
  fi
}

# check_body NAME CMD... — run a check body; record ok/FAIL by its exit code.
check_body() {
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then
    check OK "$name"
  else
    check FAIL "$name"
  fi
}

# active_markdown_surfaces — guidance a runtime agent or operator consumes.
active_markdown_surfaces() {
  {
    find "$INIT_REPO_ROOT/templates/opencode/skills" -name '*.md' -type f 2>/dev/null
    find "$INIT_REPO_ROOT/templates/opencode/commands" -name '*.md' -type f 2>/dev/null
    find "$INIT_REPO_ROOT/templates/opencode/prompts" -name '*.md' -type f 2>/dev/null
    find "$INIT_REPO_ROOT/templates/opencode/agents" -name '*.md' -type f 2>/dev/null
    printf '%s/README.md\n' "$INIT_REPO_ROOT"
    printf '%s/AGENTS.md\n' "$INIT_REPO_ROOT"
    printf '%s/.github/ISSUE_TEMPLATE/task.yml\n' "$INIT_REPO_ROOT"
  } | sort
}

# active_script_surfaces — executable guidance surfaces.
active_script_surfaces() {
  {
    find "$INIT_REPO_ROOT/scripts" -name '*.sh' -type f 2>/dev/null
    find "$INIT_REPO_ROOT/templates/scripts" -name '*.sh' -type f 2>/dev/null
    find "$INIT_REPO_ROOT/templates/opencode/skills" -name '*.sh' -type f 2>/dev/null
  } | sort
}

CURRENT_ROLES=( orchestrator strategist tech-lead builder reviewer )
CANONICAL_BOARD_STATES=( 'Open' 'Backlog' 'Need attentions' 'Ready' 'In Progress' 'In Review' 'Ready to Merge' 'Blocked' 'Done' )
CANONICAL_STATES=( 'Open' 'Backlog' 'Ready' 'In Progress' 'In Review' 'Ready to Merge' 'Done' )
EXCEPTION_STATES=( 'Need attentions' 'Blocked' )
OPTION_VAR_NAMES=( OPEN BACKLOG NEED_ATTENTIONS READY IN_PROGRESS IN_REVIEW READY_TO_MERGE BLOCKED DONE )
RETIRED_SCRIPT_BASENAMES=(
  'pm-lib.sh' 'add-task-dependency.sh' 'close-task.sh' 'create-blocker.sh'
  'create-defer-task.sh' 'create-spec.sh' 'create-spec-tasks.sh'
  'create-task-comment.sh' 'create-task.sh' 'list-tasks.sh' 'next-id.sh'
  'open-review-loop.sh' 'read-role-memory.sh' 'read-task-comments.sh'
  'read-task-replies.sh' 'record-loop-breaker.sh' 'record-merge.sh'
  'record-pr-comment.sh' 'record-pr.sh' 'record-qa-smoke.sh'
  'record-release.sh' 'record-review-result.sh' 'reply-task-comment.sh'
  'resolve-blocker.sh' 'setup-doc-structure.sh' 'update-document-index.sh'
  'update-role-memory.sh' 'update-task-owner.sh' 'update-task-status.sh'
  'validate-project-state.sh'
)
OLD_ROLE_TERMS=( 'product-owner' 'delivery-manager' 'qa-smoke' 'developer-memory' 'qa-memory' )
OLD_STATUS_TERMS=( 'In Development' 'PR Open' 'QA Smoke' 'Architecture Review' )

# role_agent_file ROLE — canonical prompt surface for a role.
role_agent_file() {
  if [[ "$1" == orchestrator ]]; then
    printf '%s' 'templates/opencode/skills/github-agentic-delivery-flow/references/orchestration.md'
  else
    printf 'templates/opencode/skills/github-agentic-delivery-flow/references/%s-delivery.md' "$1"
  fi
}

# yaml_dropdown_options FILE SELECTOR_ID — print the "- option" values of the
# options: block that follows `id: <selector>` (mirrors the .js regex).
yaml_dropdown_options() {
  local file="$1" selector="$2"
  awk -v sel="id: $selector" '
    $0 ~ sel { in_block=1; next }
    in_block && /options:/ { in_opts=1; next }
    in_opts && /^[[:space:]]+- / {
      line=$0; sub(/^[[:space:]]+- /, "", line); print line; next }
    in_opts { exit }
  ' "$file"
}

# --- INV-1: canonical state model --------------------------------------------------

init_suite "INV-1 canonical state model"

inv1a() {
  local s; s="$(read_file 'templates/opencode/skills/state-transitions/SKILL.md')"
  must_contain "$s" '`Open` -> `Backlog` -> `Ready` -> `In Progress` -> `In Review` -> `Ready to Merge` -> `Done`' "state-transitions"
  must_contain "$s" '`Open` -> `Backlog`' "state-transitions"
  must_contain "$s" '`Backlog` -> `Ready`' "state-transitions"
}
inv1b() {
  local s; s="$(read_file 'templates/opencode/skills/state-transitions/SKILL.md')"
  must_not_contain "$s" '### `Inbox`' "state-transitions"
  must_not_contain "$s" '### `Shaping`' "state-transitions"
  local without_note
  without_note="$(sed '/Legacy board option names/d' <<< "$s")"
  must_not_contain "$without_note" '`Inbox`' "state-transitions (outside legacy note)"
  must_not_contain "$without_note" '`Shaping`' "state-transitions (outside legacy note)"
}
inv1c() {
  local f s st
  for f in \
    'templates/opencode/skills/state-transitions/SKILL.md' \
    'templates/opencode/skills/approval-or-escalation/SKILL.md' \
    'templates/opencode/skills/github-agentic-delivery-flow/SKILL.md' \
    'templates/opencode/skills/github-conventions/SKILL.md'; do
    s="$(read_file "$f")"
    must_contain "$s" 'founder-only' "$f"
  done
  st="$(read_file 'templates/opencode/skills/state-transitions/SKILL.md')"
  must_contain "$st" 'after strategist and tech-lead review' "state-transitions"
}
inv1d() {
  local st; st="$(read_file 'templates/opencode/skills/state-transitions/SKILL.md')"
  must_contain "$st" 'Any State` -> `Blocked` (exception)' "state-transitions"
  must_contain "$st" 'typically `In Progress` or `In Review`' "state-transitions"
}
inv1e() {
  local flow conv
  flow="$(read_file 'templates/opencode/skills/github-agentic-delivery-flow/SKILL.md')"
  must_contain "$flow" '- `Open`' "github-agentic-delivery-flow"
  must_contain "$flow" '- `Backlog`' "github-agentic-delivery-flow"
  must_not_contain "$flow" '- `Inbox`' "github-agentic-delivery-flow"
  must_not_contain "$flow" '- `Shaping`' "github-agentic-delivery-flow"
  conv="$(read_file 'templates/opencode/skills/github-conventions/SKILL.md')"
  must_contain "$conv" '- `Open`' "github-conventions"
  must_contain "$conv" '- `Backlog`' "github-conventions"
  must_not_contain "$conv" '- `Inbox`' "github-conventions"
  must_not_contain "$conv" '- `Shaping`' "github-conventions"
}
check_body 'INV-1a: state-transitions defines the canonical happy path in order' inv1a
check_body 'INV-1b: state-transitions has no legacy Inbox/Shaping transitions' inv1b
check_body 'INV-1c: Need attentions is founder-only after strategist and tech-lead review' inv1c
check_body 'INV-1d: Blocked is an exception state, any state may enter, typically In Progress/In Review' inv1d
check_body 'INV-1e: flow and conventions skills list the canonical states, not legacy ones' inv1e

# --- INV-2: canonical state constants; env carries IDs -------------------------------

init_suite "INV-2 canonical state constants"

inv2a() { [[ ! -e "$INIT_REPO_ROOT/.github-project.json" ]]; }
inv2b() {
  local st h state
  st="$(read_file 'templates/opencode/skills/state-transitions/SKILL.md')"
  for state in "${CANONICAL_STATES[@]}" "${EXCEPTION_STATES[@]}"; do
    must_contain "$st" "$state" "state-transitions canonical state name"
  done
  h="$(read_file 'templates/opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh')"
  must_contain "$h" 'CANONICAL_FIELD_NAME="Workflow State"' "helper"
}
inv2c() {
  local env key
  env="$(read_file '.github-project.env')"
  must_contain "$env" 'export ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID=' ".github-project.env"
  for key in "${OPTION_VAR_NAMES[@]}"; do
    must_contain "$env" "export ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_${key}_ID=" ".github-project.env workflow state option"
  done
  must_not_contain "$env" 'canonicalWorkflowStates' ".github-project.env"
  must_not_contain "$env" 'identity' ".github-project.env"
  must_not_contain "$env" 'boundaries' ".github-project.env"
  must_not_contain "$env" 'initMeta' ".github-project.env"
}
check_body 'INV-2a: no .github-project.json config exists (env-only contract)' inv2a
check_body 'INV-2b: state-transitions and the helper carry the canonical model as constants' inv2b
check_body 'INV-2c: .github-project.env carries the canonical Workflow State field and option IDs' inv2c

# --- INV-3: helper targets Workflow State, never mutates remote options -----------------

init_suite "INV-3 helper targets Workflow State"

HELPER_CONTENT="$(read_file 'templates/opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh')"
inv3a() {
  must_contain "$HELPER_CONTENT" 'CANONICAL_FIELD_NAME="Workflow State"' "helper"
  must_contain "$HELPER_CONTENT" 'ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID' "helper"
  must_contain "$HELPER_CONTENT" 'ANT_TEAM_GITHUB_WORKFLOW_STATE_OPTION_' "helper"
}
inv3b() {
  must_not_contain "$HELPER_CONTENT" 'select(.name == "Status")' "helper"
  must_not_contain "$HELPER_CONTENT" 'list-todo' "helper"
}
inv3c() {
  must_not_contain "$HELPER_CONTENT" 'field-update' "helper"
  must_not_contain "$HELPER_CONTENT" 'option-update' "helper"
  must_not_contain "$HELPER_CONTENT" 'updateProjectV2Field' "helper"
  must_contain "$HELPER_CONTENT" 'never renames remote board options' "helper"
}
inv3d() {
  must_contain "$HELPER_CONTENT" 'select(.name == $state)' "helper"
}
inv3e() {
  local role file prompt
  for role in "${CURRENT_ROLES[@]}"; do
    file="$(role_agent_file "$role")"
    prompt="$(read_file "$file")"
    must_not_contain "$prompt" './.opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh' "$file"
    if grep -qF 'gh_project_helper.sh' <<< "$prompt"; then
      must_contain "$prompt" '$ANT_TEAM_SCRIPTS/gh_project_helper.sh' "$file"
    fi
  done
}
check_body 'INV-3a: gh_project_helper targets the canonical Workflow State field' inv3a
check_body 'INV-3b: helper contains no legacy Status-field selection or list-todo' inv3b
check_body 'INV-3c: helper performs no option-mutating mutations (no field/option create or rename)' inv3c
check_body 'INV-3d: helper resolves option IDs by exact remote name or known local IDs only' inv3d
check_body 'INV-3e: role prompts use the centralized helper wrapper, never the skill source path' inv3e

# --- INV-4: GitHub operational record / Obsidian knowledge boundary ------------------------

init_suite "INV-4 record split"

FLOW_CONTENT="$(read_file 'templates/opencode/skills/github-agentic-delivery-flow/SKILL.md')"
LOG_CONTENT="$(read_file 'templates/opencode/skills/agent-communication-log/SKILL.md')"
CONV_CONTENT="$(read_file 'templates/opencode/skills/github-conventions/SKILL.md')"
inv4a() {
  must_contain "$FLOW_CONTENT" 'Collaboration Record is the GitHub issue, linked pull request, and GitHub Project `Workflow State`' "flow skill"
  must_contain "$FLOW_CONTENT" 'never use it as a routine task, communication-event, or review-loop mirror' "flow skill"
}
inv4b() {
  must_contain "$LOG_CONTENT" 'GitHub issue and PR comments carry routine discussion, handoffs, status, blockers, review findings, approvals, and closure' "agent-communication-log"
  must_contain "$LOG_CONTENT" 'Do not create a per-task communication-event mirror or Obsidian issue vault' "agent-communication-log"
}
inv4c() {
  local role file prompt
  for role in "${CURRENT_ROLES[@]}"; do
    file="$(role_agent_file "$role")"
    prompt="$(read_file "$file")"
    if [[ "$role" == "orchestrator" ]]; then
      must_contain "$prompt" 'GitHub is the active collaboration surface: keep task discussion, decisions, blockers, handoffs, review findings, and closure there' "$file"
    else
      must_contain "$(read_file 'templates/opencode/skills/github-agentic-delivery-flow/references/specialist-context.md')" 'GitHub Issues and PRs are the active collaboration and execution record' "shared specialist context"
    fi
  done
}
inv4d() {
  must_contain "$FLOW_CONTENT" 'orchestrator-assigned local `session-context/` note' "flow skill"
  must_contain "$FLOW_CONTENT" 'never authoritative for Workflow State, PR approval, merge, task ownership, blockers, or closure' "flow skill"
  must_contain "$CONV_CONTENT" 'session-context/<session_id>.md' "conventions skill"
  must_contain "$CONV_CONTENT" 'never workflow state' "conventions skill"
  must_contain "$LOG_CONTENT" '$ANT_TEAM_DOCS_PROJECT_PATH/session-context/<session_id>.md' "communication skill"
  must_contain "$LOG_CONTENT" 'never authoritative for Workflow State, PR approval, merge, task ownership, blockers, or closure' "communication skill"
}
check_body 'INV-4a: top-level flow defines the GitHub operational record' inv4a
check_body 'INV-4b: communication skill requires GitHub for routine collaboration' inv4b
check_body 'INV-4c: agent prompts preserve the GitHub-first routine collaboration rule' inv4c
check_body 'INV-4d: session-context carve-out stays scoped and non-authoritative' inv4d

# --- INV-5: tech-lead owns merge and cleanup --------------------------------------------------

init_suite "INV-5 tech-lead merge gate"

TECH_LEAD_PROMPT="$(read_file "$(role_agent_file tech-lead)")"
BUILDER_PROMPT="$(read_file "$(role_agent_file builder)")"
DO_TASK_CONTENT="$(read_file 'templates/opencode/skills/do-task/SKILL.md')"
inv5a() {
  must_contain "$FLOW_CONTENT" 'Tech-lead is the only role that merges' "flow skill"
}
inv5b() {
  must_contain "$TECH_LEAD_PROMPT" 'clean up the task worktree and local branch with `$ANT_TEAM_SCRIPTS/cleanup-task-worktree.sh`' "tech-lead prompt"
  must_not_contain "$BUILDER_PROMPT" 'clean up the task worktree and local branch once they are no longer needed' "builder prompt"
  must_contain "$DO_TASK_CONTENT" '`tech-lead` cleans up the issue worktree and local branch' "do-task skill"
}
check_body 'INV-5a: tech-lead merge gate stays exclusive' inv5a
check_body 'INV-5b: tech-lead owns post-merge cleanup' inv5b

# --- INV-6: ANT_TEAM_SCRIPTS / sync-company prerequisite -----------------------------------------

init_suite "INV-6 ANT_TEAM_SCRIPTS"

inv6a() {
  local f
  for f in "$INIT_REPO_ROOT/scripts/"*.sh; do
    [[ -f "$f" ]] || continue
    if grep -qF '$(dirname "$0")/pm-lib.sh' "$f" 2>/dev/null; then
      return 1
    fi
  done
}
inv6b() {
  local f
  for f in "${RETIRED_SCRIPT_BASENAMES[@]}"; do
    if [[ -e "$INIT_REPO_ROOT/scripts/$f" ]]; then return 1; fi
  done
  while IFS= read -r f; do
    if [[ -f "$f" ]] && grep -qF 'pm-lib' "$f" 2>/dev/null; then return 1; fi
  done < <(active_script_surfaces)
  return 0
}
inv6c() {
  local w wf
  w="$(read_file 'scripts/init-project.sh')"
  must_contain "$w" '${ANT_TEAM_SCRIPTS:' "init-project.sh"
  must_contain "$w" 'init-company.sh' "init-project.sh"
  must_not_contain "$w" '$(dirname "$0")/../.opencode' "init-project.sh"
  for wf in 'templates/scripts/create-task-branch.sh' 'templates/scripts/cleanup-task-worktree.sh'; do
    must_contain "$(read_file "$wf")" '${ANT_TEAM_SCRIPTS:' "$wf"
  done
}
inv6d() {
  local s; s="$(read_file 'scripts/init-company.sh')"
  must_contain "$s" 'sync_team_scripts' "init-company.sh"
  must_contain "$s" 'export ANT_TEAM_SCRIPTS="$HOME/.agents/scripts"' "init-company.sh"
}
check_body 'INV-6a: no operational script sources pm-lib relatively' inv6a
check_body 'INV-6b: the retired pm-lib script family stays retired' inv6b
check_body 'INV-6c: init-project wrappers route through ANT_TEAM_SCRIPTS' inv6c
check_body 'INV-6d: sync-company installs team scripts and exports ANT_TEAM_SCRIPTS' inv6d

# --- INV-7: /migrate and --migrate-agent-md retired -------------------------------------------------

init_suite "INV-7 retired /migrate"

inv7a() { [[ ! -e "$INIT_REPO_ROOT/templates/opencode/commands/migrate.md" ]]; }
inv7b() {
  local s; s="$(read_file 'templates/scripts/init-project.sh')"
  must_not_contain "$s" '--migrate-agent-md' "init engine"
  must_not_contain "$s" 'opt_migrate_agent_md' "init engine"
}
check_body 'INV-7a: /migrate command file is gone' inv7a
check_body 'INV-7b: init engine has no --migrate-agent-md flag' inv7b

# --- INV-8: orchestrator model ------------------------------------------------------------------------

init_suite "INV-8 orchestrator model"

inv8() {
  local model
  model="$(sed -n 's/^model:[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' "$INIT_REPO_ROOT/templates/opencode/agents/ant.md" | head -1)"
  [[ -n "$model" ]] || { printf 'orchestrator agent frontmatter model not found\n' >&2; return 1; }
  [[ "$model" == "openai/gpt-6-luna-fast" ]]
}
check_body 'INV-8: Ant Agent model is openai/gpt-6-luna-fast' inv8

# --- INV-9: env-only project-init, no JSON import/removal path ------------------------------------------

init_suite "INV-9 env-only project-init"

inv9a() {
  local tmp stray r
  tmp="$(init_make_repo "$TMP/inv9a")"
  stray="$tmp/.github-project.json"
  printf '{ "owner": "json-owner", "project": { "id": "PVT_JSON" } }' > "$stray"
  init_run "$OUT" "$ERR" -- --noninteractive --project-dir "$tmp" --worktree-root "$tmp/wt" \
    --name demo --github-owner antpolis --github-project-number 1
  [[ "$INIT_RC" -eq 0 ]] || { printf 'init exit %s\n' "$INIT_RC" >&2; return 1; }
  [[ -f "$stray" ]] || { printf '.github-project.json must be left in place\n' >&2; return 1; }
  r="$(cat "$tmp/.github-project.env")"
  grep -qF "export ANT_TEAM_GITHUB_OWNER='antpolis'" <<< "$r" || { printf 'flag owner not recorded\n' >&2; return 1; }
  ! grep -qF 'json-owner' <<< "$r" || return 1
  ! grep -qF 'PVT_JSON' <<< "$r" || return 1
}
inv9b() {
  local tmp stray
  tmp="$(init_make_repo "$TMP/inv9b")"
  stray="$tmp/.github-project.json"
  printf '{ "owner": "json-owner" }' > "$stray"
  init_run "$OUT" "$ERR" -- --noninteractive --force --project-dir "$tmp" --worktree-root "$tmp/wt" \
    --name demo --github-owner antpolis --github-project-number 1
  [[ "$INIT_RC" -eq 0 ]] || return 1
  cp "$tmp/.github-project.env" "$TMP/inv9b.env.first"
  init_run "$OUT" "$ERR" -- --noninteractive --force --project-dir "$tmp" --worktree-root "$tmp/wt" \
    --name demo --github-owner antpolis --github-project-number 1
  [[ "$INIT_RC" -eq 0 ]] || return 1
  [[ -f "$stray" ]] || return 1
  cmp -s "$TMP/inv9b.env.first" "$tmp/.github-project.env"
}
check_body 'INV-9a: a stray .github-project.json is ignored (never read, never removed)' inv9a
check_body 'INV-9b: rerun with a stray JSON is idempotent and leaves the JSON untouched' inv9b

# --- INV-10: runtime metadata via .github-project.env ------------------------------------------------------

init_suite "INV-10 runtime metadata"

AGENTS_CONTENT="$(read_file 'AGENTS.md')"
inv10a() {
  must_contain "$AGENTS_CONTENT" '$ANT_TEAM_SCRIPTS/gh_project_helper.sh' "AGENTS.md"
  must_contain "$AGENTS_CONTENT" 'do not prefix every helper command' "AGENTS.md"
  must_contain "$AGENTS_CONTENT" 'direct shell command that must expand an `ANT_TEAM_*` variable' "AGENTS.md"
  must_contain "$AGENTS_CONTENT" 'sole committed project config source' "AGENTS.md"
  local v
  for v in ANT_TEAM_GITHUB_OWNER ANT_TEAM_GITHUB_REPO ANT_TEAM_GITHUB_PROJECT_NUMBER \
           ANT_TEAM_GITHUB_PROJECT_ID ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID \
           ANT_TEAM_WORKTREE_ROOT ANT_TEAM_DOCS_VAULT_PATH ANT_TEAM_DOCS_PROJECT_NAME \
           ANT_TEAM_DOCS_PROJECT_PATH ANT_TEAM_DOCS_REPOSITORY; do
    must_contain "$AGENTS_CONTENT" "$v" "AGENTS.md key variables"
  done
  must_contain "$AGENTS_CONTENT" 'scripts/init-company.sh' "AGENTS.md"
  must_contain "$AGENTS_CONTENT" 'init-project.sh' "AGENTS.md"
  must_contain "$AGENTS_CONTENT" 'no standalone generator' "AGENTS.md"
  must_contain "$AGENTS_CONTENT" 'no JSON config' "AGENTS.md"
  must_contain "$AGENTS_CONTENT" 'git does not expand tildes inside variables' "AGENTS.md"
}
inv10b() {
  local f content lineno line ok m
  local -a runtime_files=(
    'templates/opencode/commands/sprint-clean.md'
    'templates/opencode/skills/github-agentic-delivery-flow/references/sync-spec.md'
    'templates/opencode/skills/documentation-standard/SKILL.md'
    'templates/opencode/skills/agent-communication-log/SKILL.md'
    'templates/opencode/skills/role-memory/SKILL.md'
    'templates/opencode/skills/founder-escalation-preflight/SKILL.md'
    'templates/opencode/skills/pr-review-flow/SKILL.md'
    'templates/opencode/skills/development-hygiene/SKILL.md'
    'AGENTS.md'
  )
  for f in "${runtime_files[@]}"; do
    lineno=0
    while IFS= read -r line; do
      lineno=$((lineno + 1))
      grep -qF '.github-project.json' <<< "$line" || continue
      ok=false
      for m in '.github-project.env' 'ANT_TEAM_' 'canonical' 'source of truth' \
               'initializat' 'init-project' 'instead of parsing' 'do not parse' \
               'never parse' 'no JSON' 'no `.github-project.json`' 'regenerat' 'generated'; do
        if grep -qF -- "$m" <<< "$line"; then ok=true; break; fi
      done
      [[ "$ok" == true ]] || { printf '%s:%s: %s\n' "$f" "$lineno" "$line" >&2; return 1; }
    done < <(read_file "$f")
  done
}
check_body 'INV-10a: AGENTS.md is the primary runtime guidance for .github-project.env' inv10a
check_body 'INV-10b: runtime-facing commands and skills never instruct runtime JSON parsing' inv10b

# --- INV-11: no routine Obsidian regression; spec/closeout/memory contracts ---------------------------------

init_suite "INV-11 record-boundary and planning contracts"

inv11a() {
  local f phrase
  local -a phrases=(
    'must be recorded as individual Obsidian communication event files'
    'record each clarification discussion as an Obsidian communication event file'
    'full agent communication record in the central Obsidian project folder'
  )
  while IFS= read -r f; do
    if [[ ! -f "$f" ]]; then continue; fi
    for phrase in "${phrases[@]}"; do
      if grep -qF -- "$phrase" "$f" 2>/dev/null; then
        printf '%s: %s\n' "$f" "$phrase" >&2
        return 1
      fi
    done
  done < <(active_markdown_surfaces)
  for phrase in "${phrases[@]}"; do
    if grep -qF -- "$phrase" "$INIT_REPO_ROOT/templates/opencode/opencode.json" 2>/dev/null; then
      return 1
    fi
  done
  return 0
}
inv11b() {
  must_contain "$AGENTS_CONTENT" 'GOV-001 — GitHub Operational Record and Obsidian Knowledge Base' "AGENTS.md"
  must_contain "$AGENTS_CONTENT" 'operational execution, handoff, blocker, and review record' "AGENTS.md"
}
inv11ba() {
  local skill template
  skill="$(read_file 'templates/opencode/skills/project-initialization/SKILL.md')"
  template="$(read_file 'templates/opencode/skills/project-initialization/references/project-baseline-template.md')"
  must_contain "$skill" 'GitHub remains the operational collaboration record' "project-initialization skill"
  must_contain "$skill" 'Do not infer an ADR merely from code structure' "project-initialization skill"
  must_contain "$skill" 'PROJECT_OVERVIEW.md' "project-initialization skill"
  must_contain "$template" '[[DOCUMENT_INDEX|Document index]]' "project baseline template"
  must_contain "$(read_file 'templates/opencode/skills/init-project/SKILL.md')" 'invoke `project-initialization`' "init-project skill"
}
inv11bb() {
  local docs role
  docs="$(read_file 'templates/opencode/skills/documentation-standard/SKILL.md')"
  must_contain "$docs" '## Obsidian Role Responsibilities' "documentation standard"
  for role in '**Strategist**' '**Tech-lead**' '**Builder**' '**Reviewer**' '**Orchestrator**'; do
    must_contain "$docs" "$role" "documentation standard role ownership"
  done
  must_contain "$docs" 'GitHub Issues, Pull Requests, milestone discussions' "documentation standard record boundary"
  must_contain "$docs" 'Does not write routine vault notes' "documentation standard builder/reviewer boundary"
}
inv11bc() {
  local helper docs shaping command content label
  helper="$(read_file 'templates/opencode/skills/github-issues-projects-cli/scripts/gh_project_helper.sh')"
  docs="$(read_file 'templates/opencode/skills/documentation-standard/SKILL.md')"
  shaping="$(read_file 'templates/opencode/skills/product-shaping/SKILL.md')"
  command="$(read_file 'templates/opencode/skills/github-agentic-delivery-flow/references/new-spec.md')"
  must_contain "$helper" 'spec-next' "GitHub helper"
  must_contain "$helper" 'spec_id: SPEC-\([0-9][0-9][0-9]*\)' "GitHub helper numeric SPEC matcher"
  for content in "$docs" "$shaping" "$command"; do
    case "$content" in "$docs") label="documentation standard" ;; "$shaping") label="product shaping" ;; *) label="new-spec command" ;; esac
    must_contain "$content" 'SPEC-###' "$label"
    must_contain "$content" 'spec-next' "$label"
  done
  must_contain "$docs" 'Do not create `SPEC-AUTH-001`' "documentation standard numeric-only rule"
}
inv11bd() {
  local closeout command
  closeout="$(read_file 'templates/opencode/skills/spec-closeout/SKILL.md')"
  command="$(read_file 'templates/opencode/commands/close-spec.md')"
  must_contain "$closeout" 'all required milestone issues are in `Done`' "spec closeout gate"
  must_contain "$closeout" 'release-create TAG' "spec closeout release creation"
  must_contain "$closeout" 'milestone-close MILESTONE_NUMBER' "spec closeout milestone closure"
  must_contain "$closeout" 'Keep completed items in GitHub Project `Done`' "spec closeout board history"
  must_contain "$closeout" 'cleanup-task-worktree.sh' "spec closeout local cleanup"
  must_contain "$closeout" 'Do not use `git branch -D`' "spec closeout destructive-cleanup guard"
  must_contain "$command" 'spec-closeout' "close-spec command"
  must_contain "$FLOW_CONTENT" 'run `spec-closeout`' "delivery-flow closeout integration"
}
inv11be() {
  local phrase f
  local -a banned=(
    'verify builder updated Builder Memory'
    'verify reviewer updated Reviewer Memory'
    'verify tech-lead updated Architect Memory'
  )
  for phrase in "${banned[@]}"; do
    if grep -qF -- "$phrase" "$INIT_REPO_ROOT/templates/opencode/opencode.json" 2>/dev/null; then return 1; fi
    if grep -qF -- "$phrase" "$INIT_REPO_ROOT/templates/opencode/skills/github-agentic-delivery-flow/references/orchestration.md" 2>/dev/null; then return 1; fi
  done
  while IFS= read -r f; do
    if [[ ! -f "$f" ]]; then continue; fi
    for phrase in "${banned[@]}"; do
      if grep -qF -- "$phrase" "$f" 2>/dev/null; then return 1; fi
    done
  done < <(active_markdown_surfaces)
  return 0
}
inv11bf() {
  local prompts; prompts="$(read_file 'templates/opencode/skills/github-agentic-delivery-flow/references/orchestration.md')"
  must_contain "$prompts" 'Do not create no-op memory entries when no durable lesson exists' "orchestrator.md"
  must_contain "$prompts" 'Do not verify or require role-memory updates as a completion gate' "orchestrator.md"
}
inv11bg() {
  local skill; skill="$(read_file 'templates/opencode/skills/init-project/SKILL.md')"
  must_contain "$skill" 'name: init-project' "init-project skill frontmatter"
  must_contain "$skill" 'disable-model-invocation: true' "init-project skill frontmatter"
  must_contain "$skill" '$ANT_TEAM_SCRIPTS/init-project.sh' "init-project skill engine invocation"
  must_contain "$skill" 'invoke `project-initialization`' "init-project skill vault-docs delegation"
  [[ ! -e "$INIT_REPO_ROOT/templates/opencode/commands/init-project.md" ]]
}
inv11c() {
  local shaping tasks
  shaping="$(read_file 'templates/opencode/skills/product-shaping/SKILL.md')"
  tasks="$(read_file 'templates/opencode/skills/how-to-create-task/SKILL.md')"
  must_contain "$shaping" 'ready for planning' "product-shaping"
  must_contain "$shaping" 'open decision blocks planning' "product-shaping"
  must_contain "$tasks" 'planning-blocking decision remains unresolved' "how-to-create-task"
  must_contain "$tasks" 'canonical SPEC' "how-to-create-task"
}
inv11d() {
  local f
  for f in \
    'templates/opencode/skills/how-to-create-task/SKILL.md' \
    'templates/opencode/skills/state-transitions/SKILL.md' \
    'templates/opencode/skills/do-task/SKILL.md' \
    'templates/opencode/skills/development-hygiene/SKILL.md' \
    'templates/opencode/skills/pr-review-flow/SKILL.md' \
    'templates/opencode/skills/task-completion/SKILL.md' \
    'templates/opencode/skills/github-agentic-delivery-flow/references/orchestration.md'; do
    must_contain "$(read_file "$f")" 'Durable Context' "$f"
  done
  must_contain "$(read_file 'templates/opencode/skills/state-transitions/SKILL.md')" 'Do not move work to `Ready`' "state-transitions"
  must_contain "$DO_TASK_CONTENT" 'do not invoke builder' "do-task"
  must_contain "$(read_file 'templates/opencode/skills/pr-review-flow/SKILL.md')" 'do not approve the PR' "pr-review-flow"
  must_contain "$(read_file 'templates/opencode/skills/task-completion/SKILL.md')" 'do not approve completion' "task-completion"
  must_contain "$(read_file 'templates/opencode/skills/approval-or-escalation/SKILL.md')" 'updates the Obsidian SPEC only when it changes durable product intent' "approval-or-escalation"
  must_contain "$(read_file 'templates/opencode/skills/approval-or-escalation/SKILL.md')" 'updates ARCH, ADR, GOV, or runbook documentation only when the outcome is durable' "approval-or-escalation"
  must_contain "$BUILDER_PROMPT" 'route product intent, scope, success criteria, or acceptance ambiguity to strategist' "builder routing"
  must_contain "$(read_file "$(role_agent_file reviewer)")" 'Route product intent, scope, success-criteria, or acceptance ambiguity to strategist' "reviewer routing"
  must_contain "$LOG_CONTENT" '## Delegation — <source> → <target>' "agent-communication-log delegation template"
  must_contain "$DO_TASK_CONTENT" 'direct runtime instruction' "do-task delegation context"
  must_contain "$(read_file 'templates/opencode/skills/pr-review-flow/SKILL.md')" '## Review Delegation — builder → reviewer' "pr-review-flow review delegation"
  must_contain "$(read_file 'templates/opencode/skills/pr-review-flow/SKILL.md')" 'pr-review <PR> --approve' "pr-review-flow native approval"
}
inv11e() {
  local f line
  while IFS= read -r f; do
    if [[ ! -f "$f" ]]; then continue; fi
    while IFS= read -r line; do
      if grep -qE 'No [Nn]ew [Dd]urable [Mm]emory' <<< "$line" && ! grep -qE '[Dd]o not create' <<< "$line"; then
        printf '%s: %s\n' "$f" "$line" >&2
        return 1
      fi
    done < "$f"
  done < <(active_markdown_surfaces)
  if grep -qE 'No [Nn]ew [Dd]urable [Mm]emory' "$INIT_REPO_ROOT/templates/opencode/opencode.json" 2>/dev/null; then
    return 1
  fi
  return 0
}
check_body 'INV-11a: active guidance does not require routine Obsidian event records' inv11a
check_body 'INV-11b: AGENTS.md references GOV-001 as the record-boundary policy' inv11b
check_body 'INV-11ba: project initialization skill provides evidence-based vault baseline templates' inv11ba
check_body 'INV-11bb: documentation standard defines role-specific Obsidian ownership' inv11bb
check_body 'INV-11bc: new specifications use helper-allocated numeric-only IDs' inv11bc
check_body 'INV-11bd: completed specs use the gated GitHub closeout flow' inv11bd
check_body 'INV-11be: no active surface requires role-memory updates as a completion gate' inv11be
check_body 'INV-11bf: orchestrator prompt explicitly forbids no-op role-memory entries' inv11bf
check_body 'INV-11bg: init-project is a native source skill, not command-derived' inv11bg
check_body 'INV-11c: planning requires a stable SPEC and recorded decision status' inv11c
check_body 'INV-11d: Ready issues provide deterministic builder documentation context' inv11d
check_body 'INV-11e: no active surface mandates no-op "No New Durable Memory" role-memory entries' inv11e

# --- INV-12: legacy state names and template drift -------------------------------------------------------------

init_suite "INV-12 legacy state names"

TASK_YML="$INIT_REPO_ROOT/.github/ISSUE_TEMPLATE/task.yml"
inv12a() {
  local -a options=()
  mapfile -t options < <(yaml_dropdown_options "$TASK_YML" 'workflow_state')
  [[ ${#options[@]} -eq ${#CANONICAL_BOARD_STATES[@]} ]] || return 1
  local i
  for i in "${!options[@]}"; do
    [[ "${options[$i]}" == "${CANONICAL_BOARD_STATES[$i]}" ]] || return 1
  done
}
inv12aa() {
  local pr delegation
  must_contain "$(read_file '.github/ISSUE_TEMPLATE/task.yml')" 'id: durable_context' "task.yml"
  must_contain "$(read_file '.github/ISSUE_TEMPLATE/task.yml')" 'Open decisions' "task.yml"
  pr="$(read_file '.github/pull_request_template.md')"
  must_contain "$pr" '## Review Delegation — builder → reviewer' "pull_request_template.md"
  delegation="$(read_file '.github/delegation-template.md')"
  must_contain "$delegation" '## Delegation — <source> → <target>' "delegation-template.md"
}
inv12b() {
  local -a options
  mapfile -t options < <(yaml_dropdown_options "$TASK_YML" 'role_owner')
  local -a expected_sorted actual_sorted
  mapfile -t expected_sorted < <(printf '%s\n' "${CURRENT_ROLES[@]}" | sort)
  mapfile -t actual_sorted < <(printf '%s\n' "${options[@]}" | sort)
  [[ ${#actual_sorted[@]} -eq ${#expected_sorted[@]} ]] || return 1
  local i
  for i in "${!expected_sorted[@]}"; do
    [[ "${actual_sorted[$i]}" == "${expected_sorted[$i]}" ]] || return 1
  done
}
inv12c() {
  local f line
  while IFS= read -r f; do
    if [[ ! -f "$f" ]]; then continue; fi
    while IFS= read -r line; do
      if grep -qE '`(Shaping|Inbox)`' <<< "$line" && ! grep -qi 'legacy' <<< "$line"; then
        printf '%s: %s\n' "$f" "$line" >&2
        return 1
      fi
    done < "$f"
  done < <({ active_markdown_surfaces; active_script_surfaces; })
  return 0
}
inv12d() {
  local f s
  for f in 'templates/opencode/skills/github-agentic-delivery-flow/references/new-spec.md' 'templates/opencode/skills/github-agentic-delivery-flow/references/sync-spec.md'; do
    s="$(read_file "$f")"
    must_not_contain "$s" '`Shaping`' "$f"
    must_not_contain "$s" '`Inbox`' "$f"
    must_contain "$s" '`Backlog`' "$f"
  done
}
check_body 'INV-12a: issue template Workflow State options are exactly the canonical nine' inv12a
check_body 'INV-12aa: issue and PR templates carry durable context and delegation contracts' inv12aa
check_body 'INV-12b: issue template role owner options are the current roles only' inv12b
check_body 'INV-12c: no backticked legacy states on active surfaces outside legacy-alias notes' inv12c
check_body 'INV-12d: sprint/spec command surfaces use Open/Backlog semantics, not Shaping' inv12d

# --- INV-13: legacy roles/statuses -------------------------------------------------------------------------------

init_suite "INV-13 legacy roles/statuses"

inv13a() {
  local f term
  while IFS= read -r f; do
    if [[ ! -f "$f" ]]; then continue; fi
    for term in "${OLD_ROLE_TERMS[@]}"; do
      if grep -qF -- "$term" "$f" 2>/dev/null; then
        printf '%s: %s\n' "$f" "$term" >&2
        return 1
      fi
    done
    if grep -qE '\b(CPO|CTO)\b' "$f" 2>/dev/null; then
      printf '%s: CPO/CTO\n' "$f" >&2
      return 1
    fi
  done < <({ active_markdown_surfaces; active_script_surfaces; })
  for term in "${OLD_ROLE_TERMS[@]}"; do
    if grep -qF -- "$term" "$INIT_REPO_ROOT/templates/opencode/opencode.json" 2>/dev/null; then return 1; fi
  done
  if grep -qE '\b(CPO|CTO)\b' "$INIT_REPO_ROOT/templates/opencode/opencode.json" 2>/dev/null; then return 1; fi
  return 0
}
inv13b() {
  local f term
  while IFS= read -r f; do
    if [[ ! -f "$f" ]]; then continue; fi
    for term in "${OLD_STATUS_TERMS[@]}"; do
      if grep -qF -- "$term" "$f" 2>/dev/null; then
        printf '%s: %s\n' "$f" "$term" >&2
        return 1
      fi
    done
  done < <({ active_markdown_surfaces; active_script_surfaces; })
  return 0
}
check_body 'INV-13a: no legacy role names on active surfaces' inv13a
check_body 'INV-13b: no legacy local-board statuses on active surfaces' inv13b

# --- INV-14: README drift -----------------------------------------------------------------------------------------

init_suite "INV-14 README drift"

README_CONTENT="$(read_file 'README.md')"
inv14a() {
  local role
  for role in "${CURRENT_ROLES[@]}"; do
    must_contain "$README_CONTENT" "\`$role\`" "README current roles"
  done
  must_contain "$README_CONTENT" '`Open` -> `Backlog` -> `Ready` -> `In Progress` -> `In Review` -> `Ready to Merge` -> `Done`' "README"
  must_contain "$README_CONTENT" '`Need attentions`' "README"
  must_contain "$README_CONTENT" 'Workflow State' "README"
  must_contain "$README_CONTENT" 'only role that merges' "README"
  must_contain "$README_CONTENT" '.github-project.env' "README"
  must_contain "$README_CONTENT" 'ANT_TEAM_' "README"
  must_contain "$README_CONTENT" 'sole committed project config source' "README"
  must_contain "$README_CONTENT" 'Obsidian' "README"
  must_contain "$README_CONTENT" 'final decisions, status, closure, and code-review results' "README"
}
inv14b() {
  local term f
  local -a banned=(
    '`migrate`' '/migrate' 'product-owner' 'delivery-manager' 'CPO' 'CTO'
    'qa-smoke' 'DOC_ROOT' 'OBSIDIAN_VAULT_PATH' 'developer-memory' 'qa-memory'
  )
  for f in "${RETIRED_SCRIPT_BASENAMES[@]}"; do
    banned+=( "scripts/$f" )
  done
  for term in "${banned[@]}"; do
    if grep -qF -- "$term" <<< "$README_CONTENT"; then
      printf 'README references retired artifact: %s\n' "$term" >&2
      return 1
    fi
  done
  return 0
}
check_body 'INV-14a: README carries the current model anchors' inv14a
check_body 'INV-14b: README makes no retired command, role, or script claims' inv14b

# --- INV-15: no stale legacy env keys --------------------------------------------------------------------------------

init_suite "INV-15 no stale legacy env keys"

inv15() {
  local f
  for f in '.github-project.env' 'templates/scripts/init-project.sh' \
           'templates/opencode/skills/github-issues-projects-cli/references/command-patterns.md'; do
    must_not_contain "$(read_file "$f")" 'ANT_TEAM_GITHUB_STATUS_' "$f"
  done
  must_contain "$(read_file '.github-project.env')" 'export ANT_TEAM_GITHUB_WORKFLOW_STATE_FIELD_ID=' ".github-project.env"
}
check_body 'INV-15: no ANT_TEAM_GITHUB_STATUS_* legacy keys in the env or its seed sources' inv15

# --- INV-16: retired template key -------------------------------------------------------------------------------------

init_suite "INV-16 retired template key"

inv16() {
  local f
  while IFS= read -r f; do
    if [[ -f "$f" ]] && grep -qF 'ANT_TEAM_DOCS_PROJECT_PATH_TEMPLATE' "$f" 2>/dev/null; then
      return 1
    fi
  done < <({ active_markdown_surfaces; active_script_surfaces; printf '%s/.github-project.env\n' "$INIT_REPO_ROOT"; })
  return 0
}
check_body 'INV-16: ANT_TEAM_DOCS_PROJECT_PATH_TEMPLATE is retired' inv16

# --- INV-17: local session-context tier (GOV-001) ------------------------------------------------------------------------

init_suite "INV-17 session context tier"

ORCH_PROMPT="$(read_file 'templates/opencode/skills/github-agentic-delivery-flow/references/orchestration.md')"
inv17a() {
  local f s
  for f in 'templates/opencode/skills/github-agentic-delivery-flow/references/orchestration.md'; do
    s="$(read_file "$f")"
    must_contain "$s" '`ctx-<uuid-v4>`' "$f"
    must_contain "$s" 'uuidgen' "$f"
    must_contain "$s" '/proc/sys/kernel/random/uuid' "$f"
    must_contain "$s" 'Collision-check before creating' "$f"
    must_contain "$s" 'Do not assume the runtime exports a session ID' "$f"
    must_contain "$s" 'Never use a `timestamp + <4 hex>` scheme' "$f"
    must_not_contain "$s" 'ctx-<timestamp>' "$f"
  done
}
inv17b() {
  local f s
  for f in 'templates/opencode/skills/github-agentic-delivery-flow/references/orchestration.md'; do
    s="$(read_file "$f")"
    must_contain "$s" 'Pass the exact key and path in every child delegation' "$f"
    must_contain "$s" '**Session context:** $ANT_TEAM_DOCS_PROJECT_PATH/session-context/<session_id>.md' "$f"
  done
  must_contain "$LOG_CONTENT" '**Session context:** $ANT_TEAM_DOCS_PROJECT_PATH/session-context/<session_id>.md' "agent-communication-log delegation template"
  must_contain "$(read_file '.github/delegation-template.md')" '**Session context:** $ANT_TEAM_DOCS_PROJECT_PATH/session-context/<session_id>.md' "delegation-template.md"
  must_contain "$(read_file '.github/delegation-template.md')" 'session_id: <session_id>' "delegation-template.md"
}
inv17c() {
  local role p
  for role in strategist tech-lead builder reviewer; do
    p="$(read_file 'templates/opencode/skills/github-agentic-delivery-flow/references/specialist-context.md')"
    must_contain "$p" 'read the exact note path passed in your delegation on entry' "$(role_agent_file "$role")"
    must_contain "$p" 'append a dated `## <role> — <UTC timestamp>` section' "$(role_agent_file "$role")"
    must_contain "$p" 'never write a global current-session pointer' "$(role_agent_file "$role")"
    must_contain "$p" 'never authoritative for Workflow State, PR approval, merge, task ownership, blockers, or closure' "$(role_agent_file "$role")"
  done
}
inv17d() {
  local f
  while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    grep -qF 'session-context/current' "$f" 2>/dev/null && return 1
  done < <(active_markdown_surfaces)
  must_contain "$ORCH_PROMPT" 'Never maintain a global current-session pointer' "orchestrator prompt"
}
inv17e() {
  must_contain "$ORCH_PROMPT" 'session-context/archive/' "orchestrator prompt"
  must_contain "$ORCH_PROMPT" 'Never auto-delete' "orchestrator prompt"
  must_contain "$ORCH_PROMPT" 'rg -n "session_id: <id>"' "orchestrator prompt"
  must_contain "$ORCH_PROMPT" 'never committed to the durable documentation repo' "orchestrator prompt"
  must_contain "$AGENTS_CONTENT" '`$ANT_TEAM_DOCS_PROJECT_PATH/session-context/<session_id>.md`' "AGENTS.md"
  must_contain "$AGENTS_CONTENT" 'never commit, stage, or push session-context notes' "AGENTS.md"
}
inv17f() {
  must_contain "$(read_file 'templates/opencode/skills/documentation-standard/SKILL.md')" \
    'is session context (GOV-001; local-only, never committed), not a vault note' "documentation standard"
  must_contain "$README_CONTENT" 'session-context/' "README"
  must_contain "$README_CONTENT" 'never authoritative for workflow state, approval, merge, task ownership, or closure' "README"
}
check_body 'INV-17a: orchestrator generates a UUID-strength session ID and collision-checks before creation' inv17a
check_body 'INV-17b: orchestrator passes the exact session ID and note path in every child delegation' inv17b
check_body 'INV-17c: child roles read and append only their own session note' inv17c
check_body 'INV-17d: no global current-session pointer on any active surface' inv17d
check_body 'INV-17e: notes are local-only, rg-searchable, and archived without auto-delete' inv17e
check_body 'INV-17f: documentation-standard and README scope the session-context carve-out' inv17f

# --- Summary ----------------------------------------------------------------------------------------------------------------

init_done
