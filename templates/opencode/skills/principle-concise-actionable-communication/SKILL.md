---
name: principle-concise-actionable-communication
description: Apply when writing context, handoffs, questions, reviews, PR comments, results, or escalations; minimize reading effort while preserving the evidence, recommendation, and next action the recipient needs.
---

# Communicate Concisely and Actionably

## Trigger

Apply to communication with the founder, teammates, and agents, including questions, context relays, handoffs, PR comments, and final summaries. Match detail to the recipient's decision, scope, and risk rather than the amount of work performed.

## Rule

Lead with the outcome, recommendation, or action. Use clear, concise language without removing the context, evidence, uncertainty, or material risks needed to understand and act. Keep supporting detail accessible rather than duplicating whole investigations.

## Apply

- For questions, investigate facts that can be safely established first. Offer a feasible recommended option and its reason, along with meaningful alternatives and trade-offs when known. If no recommendation is justified, explain the uncertainty and propose the next investigation. Ask a specific question the recipient can answer; do not invent choices or a preference.
- For a blocker, state what is blocked, why, who can act or decide, and the smallest feasible unblocking step. Identify any uncertainty about ownership or feasibility.
- For a visual preference, use existing design guidance or exercise safe design judgment first. If a human decision is genuinely needed, provide accessible visual examples or a prototype and recommend an option. Do not ask someone to choose a CSS radius from numbers alone without seeing its effect; if a visual cannot be provided, say so and propose a practical next step.
- Before escalating, verify the recipient has the authority, access, and practical ability to perform the requested action. Distinguish a request to an external party from the outcome it controls. If the recipient cannot resolve the blocker, investigate alternatives and state a realistic next action rather than presenting an impossible request.
- For a genuine escalation, explain the blocker and impact, what has been tried, why this person is needed, feasible options and recommendation, and the exact decision. Include an unblock plan with owner, next steps, exit condition, and fallback. Use `principle-founder-escalation-preflight` for managed-delivery founder escalations; brevity does not replace its required checks or role reviews.
- For handoffs and PR final comments, give the recipient the relevant decision and rationale, actual changes or findings, verification and limits, and next owner or action. Link precise supporting sources when accessible; a link alone is not the actionable context.

## Boundaries and examples

- Instead of listing every dependency investigation and asking “what now?”, say what remains blocked, recommend a verified team-controlled workaround if one exists, and state the specific decision and next step. Label an untested workaround as such.
- If a security decision requires several material risks or alternatives, retain them. Summarize first and supply accessible evidence; do not enforce an arbitrary word count.
- Do not omit failed checks, uncertainty, dependencies, decisions, or required approvals to make a message short. This principle governs communication and does not change workflow gates or the authoritative collaboration record.
