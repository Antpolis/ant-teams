---
name: principle-make-retries-safe
description: Apply when designing or changing state-mutating commands, jobs, API requests, or lifecycle operations that may be repeated, interrupted, or retried; prevent duplicate effects and recover safely from partial progress.
---

# Make Retries Safe

## Trigger

Apply when an operation may run more than once or be interrupted, including deployments, initialization, event processing, scheduled jobs, and external API mutations. Assess the consequences of repetition and partial completion before choosing a retry strategy.

## Rule

Design retries and recovery so repeated execution does not produce unintended extra effects and interrupted work can safely reach the intended state. Prefer idempotent or convergent operations where feasible; where an effect cannot safely be repeated, detect uncertainty and reconcile it rather than blindly retrying.

## Apply

- Identify durable state, external effects, concurrency, and failure points. Ask what happens on a second run, after a partial run, and when two runs overlap.
- Reuse existing transactions, unique constraints, idempotency keys, or conditional writes where appropriate. Scope keys to the intended operation and account for their lifetime and the external service's guarantees.
- Inspect and reconcile partial state before resuming. Validate ownership and liveness before reclaiming locks or cleaning artifacts; do not assume a PID or file's age alone proves it is safe to remove.
- Test repeated runs and representative interruption and concurrency cases in proportion to risk. Confirm both the final state and side effects, such as messages or payments, not merely a successful return code.
- If an external outcome is unknown or cannot be deduplicated, stop or seek confirmation through a safe recovery path. Report the uncertainty and any manual action needed instead of claiming exactly-once execution.

## Boundaries and examples

- An initialization command can check whether a resource already exists, validate that it matches the desired configuration, and resume a partial setup without creating duplicates.
- A payment request that timed out may already have succeeded. Reconcile using the provider's transaction status or supported idempotency mechanism before retrying; do not submit a second charge blindly.
- Repeating an operation may intentionally create a new event or transaction. Preserve that contract and distinguish a deliberate new request from a retry. Do not delete user data or bypass authorization to force convergence; this principle does not start a managed workflow.
