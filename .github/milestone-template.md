# GitHub Milestone Template

Use this body when tech-lead creates a milestone for a spec in the agentic delivery flow.
Tech-lead is the sole owner of this milestone and all issues attached to it.

```md
## Spec

- Spec document: <path to spec file in repo>
- Spec ID: <SPEC-ID>
- Milestone created by: tech-lead

## Delivery Intent

<One sentence: what this milestone delivers and why it matters to the business.>

## Summary

<What the deliverable is, the problem it solves, and the expected business outcome.>

## Success Criteria

- <Criterion 1 — specific and observable>
- <Criterion 2>

## Scope

- Included:
- Excluded:

## Risks

- <Key delivery, technical, or business risks and mitigations>

## Issue Sequence

| # | Issue | Type | Depends on | Parallel-safe with |
|---|---|---|---|---|
| 1 | <issue title> | backend | none | — |
| 2 | <issue title> | data model | #1 | — |

## Required Task Types Coverage

- [ ] Data model / migration — issue exists or excluded: <reason if excluded>
- [ ] API / contract — issue exists or excluded: <reason if excluded>
- [ ] Backend / business logic — issue exists or excluded: <reason if excluded>
- [ ] Frontend / UI — issue exists or excluded: <reason if excluded>
- [ ] Infrastructure / configuration — issue exists or excluded: <reason if excluded>
- [ ] Integration — issue exists or excluded: <reason if excluded>
- [ ] Security — issue exists or excluded: <reason if excluded>
- [ ] Observability — issue exists or excluded: <reason if excluded>
- [ ] Error handling — issue exists or excluded: <reason if excluded>
- [ ] Documentation — issue exists or excluded: <reason if excluded>
- [ ] Testing / QA — issue exists or excluded: <reason if excluded>

## Spec Coverage Confirmation

- [ ] Every spec acceptance criterion is traceable to at least one issue
- [ ] Every functional requirement is addressed by at least one issue
- [ ] Every technical requirement is addressed by at least one issue
- [ ] Every data model, API, security, observability, and error handling requirement is addressed
- [ ] Strategist has confirmed the issue set maps to business value and acceptance criteria

## Architecture Docs Referenced

- <path to arch doc used to set guardrails>

## Exit Rule

Close this milestone only when all required issues are Done or explicitly deferred with rationale recorded as a GitHub comment.
```

## Usage Notes

- One milestone represents one spec or deliverable.
- Tech-lead creates the milestone before creating any issue.
- The canonical implementation detail lives in the repository spec, not only in the milestone.
- Link the spec document in the milestone body.
- Attach every execution issue for that deliverable to the milestone.
- Complete the Required Task Types Coverage checklist before moving any issue to `Ready`.
- If work is intentionally deferred, capture the rationale before closing the milestone.
