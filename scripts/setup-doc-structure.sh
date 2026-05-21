#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  scripts/setup-doc-structure.sh FOLDER

Creates the standard documentation and markdown project-management structure.

Examples:
  scripts/setup-doc-structure.sh docs
  scripts/setup-doc-structure.sh .docs
  scripts/setup-doc-structure.sh documentation

Creates:
  FOLDER/DOCUMENT_INDEX.md
  FOLDER/adr/
  FOLDER/gov/
  FOLDER/arch/
  FOLDER/spec/
  FOLDER/runbook/
  FOLDER/qa/
  FOLDER/memory/
  FOLDER/proj-management/board.md
  FOLDER/proj-management/tasks/
  FOLDER/proj-management/communication/
  FOLDER/proj-management/templates/
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

doc_root="${1%/}"

if [[ -z "$doc_root" || "$doc_root" == "." || "$doc_root" == "/" ]]; then
  echo "Refusing to use unsafe documentation root: ${1:-}" >&2
  exit 1
fi

mkdir -p \
  "$doc_root/adr" \
  "$doc_root/gov" \
  "$doc_root/arch" \
  "$doc_root/spec" \
  "$doc_root/runbook" \
  "$doc_root/qa" \
  "$doc_root/memory" \
  "$doc_root/proj-management/tasks" \
  "$doc_root/proj-management/communication" \
  "$doc_root/proj-management/templates"

create_if_missing() {
  local path="$1"
  local content="$2"

  if [[ -e "$path" ]]; then
    echo "Exists: $path"
    return 0
  fi

  printf '%s\n' "$content" > "$path"
  echo "Created: $path"
}

create_if_missing "$doc_root/DOCUMENT_INDEX.md" '# Document Index

| ID | Title | Type | Domain | Status | Path | Summary | Keywords | Applies To | Related Docs | Supersedes | Last Updated |
|---|---|---|---|---|---|---|---|---|---|---|---|'

create_if_missing "$doc_root/proj-management/board.md" '# Project Board

| Spec | Task | Title | Status | Owner | Branch | PR | Loop | Blocker | Updated |
|---|---|---|---|---|---|---|---|---|---|'

create_if_missing "$doc_root/memory/developer-memory.md" '# Developer Memory

## Active Lessons
'

create_if_missing "$doc_root/memory/qa-memory.md" '# QA Memory

## Active Lessons
'

create_if_missing "$doc_root/memory/architect-memory.md" '# Architect Memory

## Active Decisions And Constraints
'

spec_template_path="$doc_root/proj-management/templates/spec-template.md"
task_template_path="$doc_root/proj-management/templates/spec-tasks-template.md"
script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_spec_template="$script_root/docs/proj-management/templates/spec-template.md"
source_task_template="$script_root/docs/proj-management/templates/spec-tasks-template.md"

if [[ -f "$source_spec_template" && ! -e "$spec_template_path" ]]; then
  cp "$source_spec_template" "$spec_template_path"
  echo "Created: $spec_template_path"
elif [[ -e "$spec_template_path" ]]; then
  echo "Exists: $spec_template_path"
else
  create_if_missing "$spec_template_path" '# __SPEC_TITLE__

Metadata:

| Field | Value |
|---|---|
| ID | __SPEC_ID__ |
| Type | spec |
| Status | draft |
| Owner | __OWNER__ |
| Task File | __TASK_FILE__ |
| Communication Log | __COMMUNICATION_LOG__ |
| Last Updated | __DATE__ |

## Summary

__SPEC_DESCRIPTION__

## Context

Describe the background, problem, constraints, assumptions, and why this spec is needed.

## Goals

- Define the intended outcome.

## Non-Goals

- Define what is explicitly out of scope.

## Functional Requirements

- Describe behavior requirements.

## Technical Requirements

- Describe architecture, data, API, infrastructure, integration, security, or operational requirements.

## Architecture Considerations

- Capture architecture constraints, risks, dependencies, and guardrails for architect review.

## Acceptance Criteria

- Given <state>, when <action>, then <expected result>.

## Risks And Assumptions

- Risk or assumption.

## Open Questions

- Question requiring product, architecture, or human decision.'
fi

if [[ -f "$source_task_template" && ! -e "$task_template_path" ]]; then
  cp "$source_task_template" "$task_template_path"
  echo "Created: $task_template_path"
elif [[ -e "$task_template_path" ]]; then
  echo "Exists: $task_template_path"
else
  create_if_missing "$task_template_path" '# Tasks: __SPEC_TITLE__

Metadata:

| Field | Value |
|---|---|
| Spec ID | __SPEC_ID__ |
| Spec Title | __SPEC_TITLE__ |
| Source Spec | __SOURCE_SPEC__ |
| Communication Log | __COMMUNICATION_LOG__ |
| Status | draft |
| Owner | __OWNER__ |
| Related Docs |  |
| Architecture Guardrails |  |
| Last Updated | __DATE__ |

## Summary

Describe the implementation scope for this spec.

## Dependencies

List cross-task, technical, environment, data, or external dependencies.

## Parallelization Plan

Describe which tasks can run at the same time and which must wait.

## Communication Log

All agent handoffs, review loops, blockers, defer tasks, and approvals must be recorded in:

`__COMMUNICATION_LOG__`

## Task Index

| Task ID | Title | Phase | Status | Owner | Dependencies | Can Run In Parallel With |
|---|---|---|---|---|---|---|
| TASK-001 | Replace with task title | Phase 1 | draft | __OWNER__ | none |  |

## Tasks

### TASK-001: Replace With Task Title

Status: draft

Phase: Phase 1
Owner: __OWNER__
Dependencies: none
Parallel With:

#### Context

Explain why this task exists and what part of the spec it satisfies.

#### Scope

- Specific work included in this task.

#### Out Of Scope

- Specific work excluded from this task.

#### Files Or Modules Expected

- `<path or module>`

#### Implementation Details

- Concrete implementation instruction.

#### Definition Of Done

- Implementation satisfies the task scope.
- Relevant docs or configuration are updated if needed.
- Relevant verification passes.
- Communication log is updated.
- Role memory is reviewed and updated, or marked as no new durable memory.

#### Acceptance Tests

- Given <state>, when <action>, then <expected result>.
- Command/test: `<command>` should pass.

#### Verification Commands

```bash
<command>
```

#### Risks And Notes

- Risk, assumption, or note.'
fi

echo "Documentation structure ready under: $doc_root"
