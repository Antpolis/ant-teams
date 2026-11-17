# Principles comparison: Poteto and Ant Teams

Working draft for discussion. Coverage compares prior Ant guidance with the draft principles, not a completed catalogue. References to `development-hygiene` describe the removed predecessor, not an available skill.

**Coverage:** Strong = substantially addressed; Partial = present in some contexts but not a general decision rule; Gap = no clear equivalent identified in the skills reviewed.

| # | Poteto principle | Closest Ant guidance | Coverage / gap | Created Ant principle |
|---|---|---|---|---|
| 1 | Laziness Protocol | `ponytail`, `development-hygiene` | Strong: smallest complete change, reuse, and avoiding unnecessary abstraction. | `principle-understand-the-outcome` (partial: smallest complete outcome) |
| 2 | Foundational Thinking | `development-hygiene`, tech-lead planning | Partial: architecture and ownership are considered, but inputs, outputs, data shape, and shared state are not consistently defined first. | `principle-separate-shared-state` (partial: shared state) |
| 3 | Redesign from First Principles | `development-hygiene` allows justified deviations | Partial: prior guidance allowed redesign, but lacked a clear general trigger. | `principle-reconsider-the-design` (adapted: evidence-led comparison, not automatic redesign); `principle-respect-project-constraints` (related: handling justified deviations) |
| 4 | Subtract Before You Add | `ponytail` favors deletion and avoiding dead code | Strong in spirit; the new principle makes the simplify-and-reuse decision explicit without requiring deletion in every change. | `principle-simplify-before-adding` (based on Ponytail: smallest complete, understandable change) |
| 5 | Minimize Reader Load | `development-hygiene`, `ponytail-review` | Code readability, documentation, and actionable communication are distinct concerns, addressed by separate principles. | `principle-design-code-for-readers` (code readability); `principle-write-for-the-audience` (documentation); `principle-concise-actionable-communication` (messages and handoffs); `principle-review-by-impact` (related: actionable review findings) |
| 6 | Outcome-Oriented Execution | Specs, task acceptance, `do-tasks` | Partial: delivery outcomes are tracked; the new principle covers outcome-driven multi-step execution as well as migrations. | `principle-outcome-oriented-execution` (adapted: integrated acceptance, safe rollout, and explicit deferrals) |
| 7 | Experience First | `playbook-product-shaping` (formerly `product-shaping`), frontend design skills | Partial: user value is considered, but trade-offs against implementation convenience lack a clear general rule. | `principle-understand-the-outcome` (partial: user and maintainer outcome, success and scope); `principle-challenge-and-validate-assumptions` (related: evidence of user value and adoption) |
| 8 | Exhaust the Design Space | `idea-challenge`, product and technical shaping | Partial: alternatives were considered, but exploration was not consistently proportional to the cost of being wrong. | `principle-compare-options` (proportionate comparison); `principle-challenge-and-validate-assumptions` (related: test decision-changing assumptions) |
| 9 | Build the Lever | Helper scripts, tests, existing automation | Prior gap: automation exists, but no general decision rule for when a reusable tool is worthwhile. | `principle-build-useful-leverage` (adapted: proportionate automation rather than requiring a tool for every nontrivial task) |
| 10 | Boundary Discipline | `ponytail`, `security-review`, `development-hygiene` | Partial–strong: boundary validation and security are addressed across skills; the new principle makes the decision rule explicit. | `principle-validate-boundaries` (adapted: revalidate when independent security or trust boundaries require it) |
| 11 | Type System Discipline | General code-quality guidance; `principle-validate-boundaries` | Prior gap: no general guidance on modeling valid states across typed and untyped environments. | `principle-model-valid-states` (adapted: proportionate types plus runtime boundary validation) |
| 12 | Make Operations Idempotent | Some helper commands support safe repetition | Prior gap: safe retry behavior exists in places, but not as a general design rule. | `principle-make-retries-safe` (adapted: reconciliation, concurrency, and uncertain external effects) |
| 13 | Migrate Callers Then Delete Legacy APIs | `ponytail`, `development-hygiene` | Partial: prior guidance lacked a specific migration rule for callers and compatibility. | `principle-change-existing-code-safely` (adapted: behavior-preserving refactoring, coordinated internal migration, or explicitly owned staged compatibility) |
| 14 | Separate Before Serializing Shared State | Isolated task worktrees; one builder per issue | Partial: strong for worktrees, less explicit for shared services, data, interfaces, and other resources. | `principle-separate-shared-state` |
| 15 | Prove It Works | `ponytail`, `task-completion`, `webapp-testing`, reviewer checks | Strong: browser and reviewer procedures reference outcome verification; review independence is addressed proportionately. | `principle-prove-the-outcome` (direct evidence and limitations); `principle-review-by-impact` (independent review); `principle-make-state-changes-evidence-based` (related: lifecycle categories and evidence before status changes) |
| 16 | Fix Root Causes | `ponytail`; bug-fix workflow guidance | Prior gap: root causes were encouraged, but reproduce-and-trace was not one consistently discoverable rule. | `principle-fix-root-causes` (adapted: evidence-led diagnosis and explicit temporary containment) |
| 17 | Sequence Work into Verifiable Units | `how-to-create-task`, `do-tasks` | Strong for managed delivery; the new principle makes task shaping and verification independent of GitHub. | `principle-shape-verifiable-tasks` (safe parallelism, verified prerequisites, integrated outcomes); `principle-protect-context` (related: verify completed results before relay) |
| 18 | Guard the Context Window | Context relay requires concise briefs and evidence links | Partial: handoffs are covered; the new principles address selective investigation and continuity. | `principle-protect-context` (actionable handoffs and evidence); `principle-preserve-work-continuity` (related: retain work and history when resuming) |
| 19 | Never Block on the Human | `principle-founder-escalation-preflight` and safe internal-next-step checks | Use our existing guidance: exhaust safe internal options and provide an actionable escalation while preserving founder authority over permissions, product decisions, and irreversible actions. | `principle-founder-escalation-preflight` (managed delivery only); `principle-break-unproductive-loops` (related: change course rather than repeat stalled work); `principle-defer-only-when-safe` (related: bounded deferral, not bypassing decisions) |
| 20 | Encode Lessons in Structure | Workflow invariant tests, helper scripts, `role-memory` | Partial: practiced; the new principle adds a proportional, evidence-based trigger for checks. | `principle-encode-lessons-in-checks` (adapted: avoid brittle or speculative checks) |

Source: [Poteto's principles index](https://github.com/poteto/plugins/blob/main/pstack/skills/poteto-mode/SKILL.md#principles).

## Priority gaps for Ant Teams

1. **Know who controls the outcome.** Do not treat an external maintainer's action as guaranteed; investigate team-controlled workarounds.
2. **Escalate with a path forward.** Show impact, attempts, feasible options, a recommendation, the exact decision, and an unblock plan.
3. **Separate shared state before coordinating.** Worktrees do not isolate contracts, databases, or services.
4. **Make retries safe.** Handle partial completion and repeated attempts in installation, GitHub operations, and resumed work.
5. **Carry decisions with their rationale.** Relay the decision, founder corrections, constraints, and evidence, not only a link.
6. **Protect the coordinator's context.** Keep bulky material out of the main reasoning path while retaining accessible evidence.
7. **Reproduce, trace, and fix the cause.** Apply to ordinary debugging and managed bug fixes.
8. **Encode recurring failures in checks.** Automate a rule when it can be verified reliably rather than repeating prose.

## Adapt rather than copy verbatim

- Automate repeated or error-prone work when the investment pays off; do not build a tool for every nontrivial task.
- Compare alternatives in proportion to impact and reversibility; prototypes are not mandatory for every decision.
- Continue safe work without waiting for a human, but do not bypass authority, permissions, spending limits, or product decisions.
- Finish migrations deliberately while allowing staged compatibility and rollout where needed.
- Reconsider architecture when evidence warrants it; do not turn a small change into an automatic rewrite.

## Proposed first catalogue

Draft and test these candidates before treating them as approved principles:

1. `principle-understand-the-outcome`
2. `principle-ground-decisions-in-evidence`
3. `principle-smallest-complete-solution`
4. `principle-separate-shared-state`
5. `principle-make-retries-safe`
6. `principle-verifiable-units`
7. `principle-fix-root-causes`
8. `principle-prove-the-outcome`
9. `principle-relay-decision-context`
10. `principle-escalate-with-a-path`

Initially include external control and realistic workarounds in escalation guidance; split them out if useful in other contexts. The catalogue has not been approved or behavior-tested.
