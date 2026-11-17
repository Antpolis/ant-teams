---
name: principle-respect-project-constraints
description: Apply when planning, implementing, or reviewing work affected by project architecture, governance, conventions, or documented ownership; identify applicable constraints and handle conflicts explicitly.
---

# Respect Project Constraints

## Trigger

Apply when a decision may affect documented architecture, security, governance, ownership, or established project conventions. Read the relevant guidance and nearby implementation in proportion to the change.

## Rule

Work within applicable project constraints rather than silently replacing them with generic preferences. Distinguish binding requirements from conventions, and make material conflicts or justified deviations explicit so the responsible owner can decide when needed.

## Apply

- Identify the relevant authoritative project guidance, its scope, and existing implementation patterns before making consequential decisions. Follow the repository's documentation routing.
- Prefer established patterns when they fit. If a pattern is broken for the case, superseded, or would create greater risk, explain the evidence and propose a proportionate alternative rather than forcing it blindly.
- When the request conflicts with a constraint, name the conflict, investigate safe compliant options, and obtain any required decision or approval before the affected action. Do not treat a conversational request as permission to bypass a protection or another owner's authority.
- If guidance is missing, stale, or contradictory, distinguish known facts from assumptions and resolve the uncertainty with the appropriate owner when it materially affects the work. Report deviations and limitations that matter.

## Boundaries and examples

- If the architecture assigns database access to a service layer, implement through that boundary or raise the specific reason it cannot meet the requirement; do not silently add direct database calls elsewhere.
- A nearby formatting convention that is not a binding requirement need not trigger an architecture decision for a typo fix. Follow it where practical without inventing a formal exception.
- This principle does not freeze flawed architecture, create an approval gate, or activate managed delivery. Follow applicable workflow ownership and gates when already in force.
