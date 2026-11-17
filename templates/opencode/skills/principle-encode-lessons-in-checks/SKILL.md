---
name: principle-encode-lessons-in-checks
description: Apply when a recurring failure or repeated instruction can be checked reliably; prefer a proportionate executable safeguard over relying on repeated prose alone.
---

# Encode Lessons in Checks

## Trigger

Use when a meaningful failure recurs, or when an important instruction is repeatedly missed and a specific violation can be detected reliably. Use judgment for a one-off event or a subjective decision that cannot be checked accurately.

## Rule

Fix the underlying issue first. When a repeatable failure can be detected at reasonable cost, add the smallest appropriate check at the boundary where it prevents or exposes that failure. Preserve the reason and the limits of the check; a string match or passing test is not proof that an agent behaved correctly.

## Apply

- Identify a concrete failure, its cause, and the behavior a check should protect. Prefer an existing test, validation, or helper over another framework or redundant rule.
- Choose a safeguard proportionate to the risk: a regression test, invariant check, validation, or safer API. Include a case that would fail without the safeguard and avoid brittle assertions that merely duplicate wording when behavior can be checked.
- If automation is unreliable or too costly, record the limitation and use a human-review or operational safeguard instead. Do not create infrastructure for a hypothetical failure.
- When a delivery event reveals a durable role-specific lesson, use `role-memory` under its existing threshold. GitHub remains the operational record; a test or curated lesson does not replace approvals or task evidence.

## Boundaries and examples

- A helper that accidentally permits a duplicate transition can gain a regression test that repeats the operation and verifies no second mutation occurs.
- A single preference for different prose does not justify a new linter; explain the preference in review instead.
- Do not turn every event into role memory or a new test. Do not treat a textual presence check as proof that a model will follow a nuanced procedure.
