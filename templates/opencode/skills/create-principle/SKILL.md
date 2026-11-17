---
name: create-principle
description: Create or improve a reusable principle-* skill: a specific decision rule with a clear trigger, guidance, boundaries, and examples. Use when the user asks to define, revise, or evaluate an Ant principle, not when merely applying an existing principle.
---

# Create a Principle

Use `skill-creator` for skill authoring, testing, and iteration. A principle is a reusable rule for making a decision in a particular situation, not a task workflow, lifecycle phase, GitHub procedure, or generic value statement.

## Define the rule

1. Clarify the problem, the situation that triggers the principle, the decision it changes, and who or what is affected. Use the user's context and existing repository guidance before asking questions.
2. Inspect existing `principle-*` skills and relevant guidance. Reuse or refine an existing rule if the proposed one overlaps; do not create a near-duplicate. Identify any conflict with safety, repository constraints, or approved workflows.
3. Challenge the proposed rule with a concrete case where it helps and a case where applying it mechanically would cause harm. Distinguish a required guardrail from a preference and state its limits. Discuss material trade-offs with the user; do not assume a proposed principle is approved.
4. Choose a descriptive `principle-<decision-rule>` name. Create or edit the canonical `templates/opencode/skills/<name>/SKILL.md` unless the user specifies another destination. Do not edit generated runtime copies.
5. When creating, adapting, or revising a principle, update the current principles comparison table if one exists: list the actual Ant skill in its created-principle column, map it to every relevant source row, and mark partial overlaps honestly. If no comparison exists, report that gap rather than inventing a mapping or a second authoritative table.
6. Inspect every canonical mode for routing and references affected by the new or changed principle. Update each mode as needed so applicable work can discover it and renamed or removed skills are not referenced; preserve each mode's scope and avoid forcing irrelevant principles into unrelated tasks. Report modes inspected and any that need no change.

## Skill structure

Use frontmatter with matching `name` and a `description` stating when the principle applies. Keep the content concise and include:

- **Trigger:** the situation in which the rule changes a decision.
- **Rule and rationale:** what to favor or check, and why.
- **Application:** how to use the rule proportionately, including relevant existing skills.
- **Boundaries:** exceptions, competing constraints, and what it does not authorize.
- **Examples:** at least one concrete application and one counterexample or exception.

Do not encode a complete playbook, mandate a GitHub issue, or activate managed delivery merely because the principle is read. Do not invent other principles or playbooks as dependencies. If the principle applies to an already managed workflow, preserve its gates and canonical records.

## Check and iterate

Use `skill-creator` to propose realistic evaluation scenarios, including a positive case, a near miss, and an exception or competing constraint. Ask the user to review those scenarios before running the evaluation. Check that the rule changes the intended decision without causing the exception to be treated as a violation. Report what was tested, remaining uncertainty, and affected modes, indexes, or playbooks; update them when applicable and within scope.
