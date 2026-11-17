---
name: principle-understand-the-outcome
description: Apply when shaping a product, choosing scope, or interpreting an ambiguous change: identify who needs what outcome and what must remain safe before prescribing a solution.
---

# Understand the Outcome

## Trigger

Apply when a request leaves the problem, expected behavior, scope, or trade-off unclear, especially when choosing what to build or change. For an unambiguous small request, existing context can provide the answer without a discovery exercise.

## Rule

First identify whose problem is being solved, the observable outcome they need, and the constraints or existing behavior the change must preserve. Choose the smallest complete solution that achieves that outcome, not merely the easiest implementation or the most impressive feature set. Consider the experience of both the person using the result and the person maintaining it.

## Apply

- Inspect relevant behavior and callers before deciding what must change. Separate evidence from assumptions; identify acceptance and verification appropriate to the risk.
- For a meaningful product or scope decision, define how success will be observed or measured and what is explicitly outside the current scope when that prevents ambiguity. Use a practical proxy or qualitative evidence when a reliable metric is unavailable; do not invent precision.
- Identify open decisions and their owners. Treat a decision as blocking only when its unresolved answer materially changes the work, acceptance, constraints, or verification needed now; record other questions as non-blocking when useful.
- Prefer existing capabilities and a coherent small slice. Include necessary validation, accessibility, error handling, and compatibility; those are part of a complete outcome, not optional extras.
- Investigate factual uncertainties that can be safely resolved. If a product preference, authorization, or consequential trade-off remains genuinely undecided, present the evidence and ask the person who owns that decision.
- Use `playbook-product-shaping` for substantial product framing and `ponytail` for proportional implementation judgment when applicable. Reading this principle does not start a managed workflow or require tracking artifacts.

## Boundaries and examples

- A request to add many dashboard filters may really require finding overdue work quickly. Check the user's workflow and existing filters, then propose the smallest useful change and how to verify it.
- A clear request to fix a typo does not require interviews or a product spec. Fix it and verify the result; do not broaden the task based on a hypothetical user need.
- Do not silently replace explicit scope with a preferred solution or trade security, user safety, or required behavior for a shorter implementation.
