---
name: principle-separate-shared-state
description: Apply when parallel agents, processes, or tasks may modify shared state: prefer safe ownership separation and coordinate only the state that truly must remain shared.
---

# Separate Shared State

## Trigger

Apply when concurrent work can affect the same mutable data, files, branches, contracts, external resources, or operational records, and that overlap could cause lost updates, conflicts, or inconsistent behavior.

## Rule

Identify what must genuinely be shared. Prefer the smallest complete design that gives independent work separate ownership and brings results together at a defined integration point. If a shared invariant cannot be separated safely, enforce coordination with an appropriate mechanism; an instruction to take turns is not concurrency control.

## Apply

- Identify writers, readers, ownership, shared resources, and required consistency. Separate outputs, workspaces, keys, or resources where doing so preserves the intended outcome and existing safety constraints.
- Define how and by whom results are integrated and verified. Separate worktrees isolate local files, not shared APIs, databases, remote state, or incompatible changes to the same contract.
- Where a single shared state is necessary, use an existing appropriate mechanism such as an atomic operation, single writer, lock, or explicitly sequential execution. Match the mechanism to the failure mode and environment; do not add a locking framework or infrastructure without need.
- Use `ponytail` for the smallest complete implementation and existing workflow guidance for role ownership. A principle does not authorize a new workflow, bypass its gates, or create GitHub artifacts.

## Boundaries and examples

- Two independent issue builders can use separate branches and worktrees, with a designated integration owner checking shared interfaces and merged behavior.
- Two payment operations updating one balance cannot be made safe merely by putting their code in separate worktrees. Preserve the shared invariant with transactional or equivalent coordination appropriate to the system.
- Do not split data that must be consistent merely to enable parallelism. If separation creates more risk or complexity than the benefit, serialize the work safely instead.
