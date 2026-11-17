---
name: create-playbook
description: Create or improve a playbook-* skill: a practical procedure for a type of work with relevant principles, verification, and explicit boundaries. Use when the user asks to define, revise, or evaluate an Ant playbook, not when simply executing an existing playbook.
---

# Create a Playbook

Use `skill-creator` for skill authoring, testing, and iteration. A playbook is a procedure for a kind of work; a `principle-*` skill is a decision rule that can apply across playbooks. The tracking workflow records and coordinates work; it does not define product or engineering judgment.

## Shape the procedure

1. Clarify the desired outcome, entry conditions, input and evidence, intended user and output, and when the playbook should not be used. Separate a direct task from an explicitly requested managed workflow.
2. Inspect relevant existing skills, `playbook-*` and `principle-*` entries, and repository guidance. Prefer extending an existing playbook over creating a competing procedure. Identify conflicts with role ownership, approval gates, tracking records, or explicit user constraints.
3. Define the smallest useful ordered steps, including investigation, execution, and verification where applicable. Identify checkpoints, permitted skips and their reasons, expected result, failure and recovery paths, and human decisions. Match ceremony to the risk and scope.
4. Reference existing applicable `principle-*` skills by exact name and explain when to load them; do not invent missing skills or duplicate their rules. If a useful principle is missing, identify the gap without silently creating it or blocking ordinary work.
5. Choose a descriptive `playbook-<work-type>` name. Create or edit the canonical `templates/opencode/skills/<name>/SKILL.md` unless the user specifies another destination. Do not edit generated runtime copies.
6. Inspect every canonical mode for routing and references affected by the new or changed playbook. Update each mode as needed so matching work can discover it and renamed or removed skills are not referenced; preserve each mode's scope and do not make unrelated procedures mandatory. Report modes inspected and any that need no change.

## Skill structure

Use frontmatter with matching `name` and a `description` explaining when to trigger and when not to. Include:

- **Scope and entry:** outcome, trigger, prerequisites, and non-goals.
- **Applicable principles and skills:** exact existing names, with when to consult them.
- **Procedure:** ordered steps, ownership, evidence, and permitted skips.
- **Verification and return:** observable success, checks, limitations, and next action.
- **Failure and recovery:** what to do if evidence, access, or execution is unavailable.

Reading a playbook does not start a managed GitHub workflow or create GitHub artifacts. An explicitly selected managed workflow retains its role ownership, operational record, review, and merge gates; the playbook must not bypass or silently replace them. Do not make GitHub a prerequisite for ordinary work.

## Check and iterate

Use `skill-creator` to propose realistic evaluation scenarios, including a normal case, a near miss, and a blocked or exceptional case. Ask the user to review those scenarios before running the evaluation. Check that steps and verification actually produce the requested outcome and that managed and ordinary work remain distinct. Report what was tested, remaining uncertainty, and affected modes, indexes, or routing; update them when applicable and within scope.
