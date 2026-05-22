---
name: do-task
description: Use when tech-lead should drive execution from the GitHub project queue, prioritize issues by spec, clarify unclear issues, delegate implementation to builder, and require validator review before any issue is treated as done.
---

# Do Task

Use this skill whenever execution should start from the current GitHub project issue queue rather than from a single already-picked task.

Use the agentic-flow-terms skill as the canonical glossary for custom workflow metadata terms referenced by this skill.
Use github-agentic-delivery-flow for the top-level GitHub operating model.
Use github-conventions, state-transitions, approval-and-escalation, and agent-communication-log for GitHub workflow mechanics.
Use role-memory for durable cross-loop continuity.
Use founder-escalation-preflight before asking the founder for a decision.

## Core Rule

`tech-lead` owns issue-level technical triage for execution.

Do not require strategist confirmation for every issue.
Bring in `strategist` only when product intent, scope meaning, or execution meaning is unclear.

## Queue-Driven Flow

1. Start from the GitHub project issue queue.
2. First inspect any issues already in `In Progress` or equivalent processing status.
3. Also inspect any issues already in `In Review` before pulling fresh work so validator-gated work does not stall behind new execution.
4. For each active issue already in progress or review:
   - review with `builder` whether the implementation is actually done or still in flight
   - if the work is done from the builder side, move it forward into validator review and transition the issue accordingly
   - if the work is already waiting on validator, delegate validator before considering fresh queue work
   - if the work is not done, carry on to finish it before pulling fresh work
   - if `builder` has questions about product intent, scope meaning, or execution meaning, review with `strategist` only as needed and record that discussion in GitHub comments
   - if the issue is blocked for any reason, move it to `Blocked`, add a GitHub comment explaining the blocker, and notify the user
5. After reconciling active issues, read the remaining issues in the project with their milestone/spec, status, dependencies, prior comments, and linked docs.
6. Group issues by spec or milestone.
7. Prioritize within the current spec group before moving to another spec.
8. Only switch away from the current spec group when:
   - an issue is blocked by a real dependency
   - human intervention is required
   - there are no more executable issues in that spec group
9. Build an ordered issue list for the current execution pass.
10. Process issues one by one.
11. If there are no executable issues after reconciliation:
   - do not stop at queue reporting alone
   - inspect open repo issues that are not on the project board or are on the board in a non-executable state but may be ready for triage
   - check whether open repo issues or spec work exist outside the current executable queue that can be triaged into the project
   - if tasks exist but are not builder-usable, create or request the missing technical delegation details needed to make one issue executable
   - if product/spec direction is needed, delegate to `strategist` to clarify or prepare the next actionable spec/issue path
   - only return to the user without internal delegation when no safe next internal action exists or explicit human direction is required

## Return-To-User Gate

Do not return control to the user merely because the current project queue looks empty.

Before ending a `do-task` pass, explicitly exhaust this checklist:

1. reconcile any `In Progress` issues with `builder`
2. reconcile any `In Review` issues with `validator`
3. process any `Ready` issues in the current spec group
4. inspect open repo issues or milestone work that may need project-board triage
5. decide whether a missing executable task can be created or clarified safely through `strategist`

If any checklist item still has a safe internal next step, take that step before replying to the user.

Only stop and report back when:

- every safe internal delegation path has been attempted, and
- the remaining blocker is a real human decision, missing approval, missing credential, or missing external input

When you do return to the user, say which checklist items were exhausted and name the exact blocking decision.
Before returning for a founder decision, run founder-escalation-preflight and include its result.

## Per-Issue Rules

For each issue:

- confirm the technical requirement is clear enough for implementation
- read the linked spec, dependencies, prior delegations, and relevant repository docs
- if product intent, scope meaning, or execution meaning is unclear, clear it with `strategist`
- record any clarification discussion in GitHub comments for auditability
- if the issue has a blocker or needs human intervention, record that in GitHub and skip to the next executable issue
- once the technical requirement is clear, delegate the issue to `builder` and record that delegation in GitHub

## Builder And Validator Gate

- `builder` works the delegated issue according to the task-development workflow
- after `builder` finishes, `validator` must review before the issue can be treated as done
- if `validator` finds issues, return the issue to `builder` on the same branch and continue the loop
- builder completion is not final completion
- an issue is only treated as done after validator approval, or otherwise blocked or escalated

## GitHub Audit Rules

- GitHub Issues are the canonical execution tasks
- GitHub Project status is the canonical workflow board
- GitHub issue comments and PR comments are the canonical delegation and audit log
- repository docs are the canonical spec and architecture source

## Delegation Rule

- for internal role-to-role work, always delegate when the next safe role is clear
- do not stop after only posting a GitHub comment if `strategist`, `builder`, or `validator` can be invoked now
- reserve the word `handoff` for founder-facing return, escalation, or final control transfer

## Required Delegation Content

Every tech-lead delegation to builder should include:

- current issue and spec
- technical interpretation of the requirement
- guardrails and constraints
- dependencies or blockers
- expected verification
- exact next action

## Stop And Skip Rules

- if an issue needs human intervention, record it and skip to the next executable issue
- if an in-progress issue is blocked, move it to `Blocked`, add a GitHub comment, and notify the user
- if a spec is too unclear to proceed safely, record the clarification need in GitHub before pausing or switching
- if the executable queue is empty, treat that as a triage trigger, not as completion of the pass
- do not start a new spec unless the remaining work changes scope
