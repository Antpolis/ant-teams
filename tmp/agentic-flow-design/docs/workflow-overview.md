# Workflow Overview

## Goal

Run a continuous loop from spec to validated product delivery using:

- GitHub Milestones as spec containers
- GitHub Issues as task records
- GitHub Projects as the shared kanban board
- role-based delegation across strategist, tech-lead, builder, and validator

## Source Of Truth

- Canonical spec: repository doc
- Spec tracking container: GitHub milestone
- Task execution record: GitHub issue
- Workflow visualization: GitHub project
- Implementation artifact: branch + pull request
- Durable execution narrative: issue comments + PR comments

## Workflow

1. Strategist shapes the problem into a practical MVP and spec draft.
2. Founder reviews and decides on direction.
3. Tech-lead validates technical feasibility and sets guardrails.
4. A milestone is created or updated for the spec.
5. The spec is decomposed into issues.
6. Builder implements one issue at a time.
7. Validator performs code review and lightweight smoke verification.
8. If findings remain, the work returns to builder.
9. If approved, the issue moves to done.
10. The milestone closes when all required issues are done or intentionally deferred.

## Non-Negotiables

- No issue should enter implementation without clear acceptance criteria.
- No task should be merged before validation passes.
- No important decision should live only in chat context.
- Rework loops should be bounded and escalated when they stop producing progress.
