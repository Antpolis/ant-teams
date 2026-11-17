---
name: principle-shape-verifiable-tasks
description: Apply when splitting, shaping, or sequencing work into tasks; create coherent, independently verifiable slices and retain only genuine prerequisites.
---

# Shape Verifiable Tasks

## Trigger

Apply when an outcome needs to be split into multiple tasks or when an existing task is too broad, ambiguous, or dependent to execute safely. A small self-contained request does not need artificial subtasks.

## Rule

Define each task around the smallest coherent outcome that can be implemented, reviewed, and verified. Make its scope, observable acceptance, relevant constraints, and verification clear to the person doing the work. Minimize hard dependencies without pretending independent work is safe when it is not.

## Apply

- Start from the intended outcome and existing system. Account for user-visible behavior, required security, data integrity, compatibility, and integration; avoid fragments that cannot deliver or verify a coherent result.
- For each actual prerequisite, identify what must be available, why it is required, and how it will be known to be satisfied. Distinguish preferred order from a hard dependency and identify parallel-safe tasks. Separate workspaces do not isolate shared contracts, databases, or external resources.
- Before advancing dependent work, confirm that the prerequisite has actually finished and its required result is verified. A progress update, posted handoff, or launch acknowledgement alone is not completion. Reconcile interrupted or failed work rather than treating it as a satisfied prerequisite; continue genuinely independent work when safe.
- Plan a useful baseline and focused check for each unit when practical. For bugs, reproduce the failing behavior before the fix when possible; for a refactor, establish a passing baseline. Verify a prerequisite before advancing work that depends on its result; independent work may continue in parallel.
- Assign integration ownership and verify the combined outcome separately. Individual passing checks or merged changes are evidence of progress, not proof of the complete outcome.
- Consider alternatives and ownership for external dependencies. Record unknowns and practical workarounds without promising actions controlled by a third party. Keep verification proportional to risk and report unavailable evidence.

## Boundaries and examples

- Separate independent frontend and backend slices against an agreed contract, with a later integration check and an owner. If the contract is undecided, resolve it rather than pretending the tasks are independent.
- Correcting a typo does not need a task breakdown, baseline document, or GitHub issue. Make and check the change directly.
- Do not weaken acceptance, security, required review, or real dependency gates to gain parallelism. This principle does not create GitHub artifacts, assign managed roles, start a workflow, or replace a selected workflow's review and merge gates.
