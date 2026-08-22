---
name: development-hygiene
description: Use when implementing, refactoring, reviewing, or planning code changes and the work should stay clean, simple, and aligned with the repository's existing architecture and conventions. Trigger this whenever the user asks for clean code, refactoring, cleanup, maintainability, technical debt reduction, KISS, consistency, architecture alignment, or wants a feature added without creating a messy solution.
---

# Development Hygiene

Use this skill whenever code work should be kept simple, consistent, and aligned with the architecture patterns that already exist in the repository.

This skill applies to both builder and reviewer. Builder uses it to write clean implementations. Reviewer uses it to evaluate whether the implementation is acceptably simple, well-separated, and correctly placed — and to raise mandatory findings when it is not.

This skill is not for inventing a new architecture style. It is for helping the model fit new work into the repo cleanly, with minimal moving parts and minimal surprise for future maintainers.

## Goals

- Keep implementation simple enough to understand and change later.
- Reuse the repository's existing architectural patterns before introducing new ones.
- Avoid speculative abstractions, cleverness, and premature generalization.
- Leave the codebase cleaner or at least no worse than it was before the task.
- Make deviations explicit when the requested change genuinely needs them.

## Read Before Changing Code

Before making strong implementation decisions:

1. Read the relevant task, spec, or issue if one exists.
2. Read the nearest existing code in the same feature or module area.
3. Read any linked repository docs that define architecture, governance, or implementation guardrails.
4. Prefer local repository guidance over generic best-practice instincts.

Useful repo guidance often lives in:

- the central Obsidian project documentation path from `ANT_TEAM_DOCS_PROJECT_PATH` in `.github-project.env` — the sole committed project config source (source `./.github-project.env`)
- project-specific architecture, governance, and ADR notes in that vault path
- related skill docs and workflow docs under `.opencode/skills/`

If the repo has a local governance document describing how architecture guidance is applied, follow that before inventing a new pattern.

## Core Working Rules

### 0. Preserve task continuity during execution

When continuing an existing task, prefer continuity over restart.

Prefer:

- staying in the existing issue worktree when one already exists
- staying on the existing task branch
- updating the existing pull request
- preserving visible review history

Avoid:

- creating a fresh worktree for normal continuation work
- creating a fresh branch for normal continuation work
- opening a replacement PR just because the current one is inconvenient
- discarding review context that future roles still need

If continuity is impossible because the worktree, branch, or PR is broken, stale beyond safe recovery, or otherwise unusable, record the reason clearly in GitHub before replacing it.

When starting new implementation, prefer a dedicated git worktree per active issue. This keeps parallel issue work isolated and prevents one task from blocking another because they share the same checked-out workspace.

After the issue PR is merged or the task is explicitly abandoned, clean up the now-unused issue worktree and local branch so stale workspaces do not pile up.

### 1. Start with the simplest change that can work

Prefer:

- extending an existing module
- reusing an existing helper
- adding a small focused function
- making a narrow refactor that directly supports the task

Avoid:

- introducing a new framework, pattern, or layer without a clear repo-backed reason
- extracting abstractions before there are repeated cases that justify them
- rewriting broad areas of code just to make the local change feel cleaner
- mixing cleanup, architecture redesign, and feature work unless the task truly requires it

When two approaches both work, prefer the one with:

- fewer concepts
- fewer files touched
- less hidden behavior
- easier testability
- better fit with nearby code

### 2. Match the existing architecture before proposing a new one

Treat the repository's current structure as a strong signal.

Look for existing patterns in:

- file layout
- module boundaries
- naming
- dependency direction
- error handling
- state management
- configuration access
- testing style

Follow the established pattern unless one of these is true:

- the pattern is clearly broken for this case
- repository docs already say it should change
- the task explicitly asks for an architectural shift
- preserving the old pattern would create higher risk than a controlled deviation

If you need to deviate, say so clearly and explain why the deviation is smaller risk than forcing the old pattern.

### 3. Keep responsibilities narrow

Prefer code where each unit has one clear job.

Watch for hygiene smells such as:

- one file accumulating unrelated responsibilities
- helpers that hide business logic unexpectedly
- shared utilities that are actually feature-specific
- functions that both decide and perform too many steps
- refactors that make the happy path harder to follow

When possible, improve by separating concerns in a way that matches the existing repo structure rather than creating a brand-new abstraction system.

### 4. Minimize surprise

A clean solution should be unsurprising to the next person reading the code.

Prefer:

- explicit flow over magical behavior
- clear names over compressed clever names
- local reasoning over indirection
- small comments only where the code's intent would otherwise be hard to infer

Avoid adding "flexibility" that nobody asked for if it makes normal usage harder to read.

### 5. Respect architecture and governance docs

When the repo has architecture or governance docs, treat them as decision constraints, not optional reading.

Especially respect docs that define:

- approved boundaries
- ownership
- implementation guardrails
- documentation routing
- allowed role or workflow responsibilities

If the requested change conflicts with those docs:

1. name the conflict plainly
2. avoid silently coding around it
3. either stay within the current guardrails or recommend the smallest doc-backed follow-up needed

## KISS Review Pass

**Builder self-check** — before finalizing a change:

1. Is there a smaller version of this change that still solves the problem?
2. Did I introduce a new abstraction that only has one caller or one use case?
3. Did I create indirection where a direct implementation would be clearer?
4. Did I follow a nearby existing pattern that future maintainers will already recognize?
5. Did I mix feature delivery with optional cleanup that should be separated?
6. If I touched architecture, is that because the task required it or because I preferred it?

If the answer exposes unnecessary complexity, simplify before finishing.

**Reviewer check** — on every review pass:

1. Is the implementation more complex than the simplest solution that would work?
2. Are there new abstractions with only one caller or one current use?
3. Is there indirection that obscures rather than clarifies?
4. Does the code live in the correct folder, package, or namespace as defined by the repository architecture documents? Read the central Obsidian project architecture notes before judging placement — do not apply generic language conventions when a project-specific architecture document defines the expected structure.
5. Are any two concerns mixed in a single file, class, or function that should be separated?
6. Was architecture or cleanup bundled into a feature change without being explicitly called out?

If yes to any of these, raise it as a finding — not a suggestion. Leniency on these principles is a reviewer failure.

## Optional Ponytail Tools

The repository ships optional Ponytail skills: `ponytail`, `ponytail-review`, `ponytail-audit`, `ponytail-debt`, and `ponytail-gain`. They complement this skill but never override correctness, security, architecture guardrails, required tests, role ownership, GitHub audit records, review gates, or merge approval.

- `ponytail` (core): optionally apply to hygiene-sensitive work to challenge YAGNI, reuse what already exists in the repo, avoid new dependencies, and prefer the smallest working diff. It aligns with the goals above; use it as an aid, never as a reason to skip required verification.
- `ponytail-review`: optionally run as an additional complexity-only review pass. It replaces nothing — the reviewer's scope/architecture/placement checks above remain mandatory, and its findings are actionable only when they do not conflict with requirements or guardrails.
- Mark meaningful deliberate simplifications that cut a real corner (a known ceiling such as a global lock, O(n²) scan, or naive heuristic) with a `ponytail:` comment naming the ceiling and the upgrade trigger.
- `ponytail-audit` may be run periodically or at milestone close for a one-shot repo-wide complexity listing; it applies nothing.
- `ponytail-debt` harvests `ponytail:` markers into a ledger. Debt that warrants follow-up must be converted into GitHub issues/tasks by `tech-lead`, under the existing issue-ownership rules — never silently hidden. Markers without an upgrade trigger are rot risks.
- `ponytail-gain` is informational benchmark context only and must not be used as a project metric.
- These tools are optional and one-shot where their skill says so. When an invocation affects an existing task or decision, record it in the normal issue/PR or milestone comments; standalone informational runs need no new record.

## Refactor Guidance

When asked to clean up or refactor:

- preserve behavior unless the task explicitly includes behavior change
- keep refactors incremental
- prefer one clear improvement theme per change
- remove dead code and duplication when confidence is high
- do not hide risky rewrites under the label of "cleanup"

If the codebase is already messy, do not try to fix everything in one pass. Improve the local area enough that the current task becomes safer and easier to maintain.

## Output Expectations

When reporting back on hygiene-sensitive work, include:

- what existing pattern or architecture you followed
- where you intentionally kept the solution simple
- any place where you chose not to generalize yet
- any architecture conflict or technical debt you noticed if it materially affects the change

If no conflict exists, keep the report brief.

## Examples

**Example 1**
Input: Add a new API handler similar to two existing handlers in the same module.
Output: Follow the same handler structure, validation style, and error mapping already used nearby. Do not introduce a new service layer unless the existing codebase already uses one here.

**Example 2**
Input: Clean up this feature because it feels messy.
Output: Read the local module first, identify the smallest high-value cleanup, preserve behavior, and avoid turning the request into a broad rewrite.

**Example 3**
Input: Add this capability, but keep it aligned with the current architecture.
Output: Read the relevant docs and nearby code first, then implement the smallest architecture-aligned change. If the request conflicts with the current structure, explain the conflict before forcing a new pattern.

## Do Not

- Do not treat novelty as improvement.
- Do not invent new layers just because they look cleaner in isolation.
- Do not override repository architecture with generic textbook advice.
- Do not broaden scope into speculative cleanup unless it directly supports the requested change.
- Do not silently violate documented guardrails.
