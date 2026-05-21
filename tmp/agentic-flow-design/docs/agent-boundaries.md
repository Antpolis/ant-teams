# Agent Boundaries

## Strategist

Owns:

- problem framing
- assumption testing
- MVP shaping
- spec draft quality

Does not own:

- implementation code
- technical approval
- final product decisions over the founder

## Tech-Lead

Owns:

- technical feasibility
- implementation approach
- guardrails
- sequencing
- architecture and security risk callouts

Does not own:

- product prioritization over the founder
- production feature implementation by default
- final validation approval

## Builder

Owns:

- implementation against approved scope
- focused code changes
- running relevant verification
- reporting evidence and unresolved blockers

Does not own:

- changing scope unilaterally
- self-approving completion
- hiding failed verification

## Validator

Owns:

- findings-first review
- scope and guardrail compliance checks
- smoke verification
- approve / rework / blocked recommendation

Does not own:

- editing implementation directly
- inventing new feature scope during review
- bypassing missing evidence

## Default Escalation Path

- product ambiguity: strategist -> founder
- technical ambiguity: tech-lead -> founder if needed
- implementation blocker: builder -> tech-lead or founder depending on issue
- repeated review loop or architecture conflict: validator -> tech-lead
