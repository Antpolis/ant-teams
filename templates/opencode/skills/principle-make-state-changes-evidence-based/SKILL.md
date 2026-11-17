---
name: principle-make-state-changes-evidence-based
description: Apply when defining or changing task lifecycle statuses and transitions across projects or tracking tools; map each status to a common category and verify transition conditions and evidence.
---

# Define and Transition Work States

## Trigger

Apply when defining a task lifecycle or moving tracked work between statuses. The category contract applies regardless of the board or tracking tool; a simple personal checklist can satisfy it without adding administrative machinery.

## Rule

Every task status must map unambiguously to one of four ordered categories: **Backlog → Progressing → Reviews → Done**. A project may define multiple statuses per category and use different names. Category flow is forward only, except that work may return from Reviews to Progressing for rework, attention, or a blocker. Status changes within a category must follow the project's defined rules. Move work only when the applicable conditions are met and supported by evidence; status represents reality, not merely an intention or progress report.

## Define categories and statuses

- **Backlog:** captured or being shaped; the work is not yet in the planned-to-do or active execution flow.
- **Progressing:** planned to do, underway, or awaiting attention or resolution before work can proceed. The project must provide a way to represent to-do, needs-attention, and blocked conditions in this category, even if its labels differ.
- **Reviews:** implementation or other assigned work has reached its review or verification stage; required checks and approvals are in progress or awaiting completion.
- **Done:** the applicable completion conditions, including required verification and approvals, have been met.

For every project status, define its category, meaning, entry and exit conditions, permitted next statuses, responsible owner, and required evidence or record. Specify how to represent blockers and attention, including their reason, owner, and next action. Map the project's existing statuses explicitly; do not assume a name alone proves equivalence. A task's current status must identify exactly one category.

## Apply

- Check the current authoritative state, the category mapping, the target status's conditions, required evidence, and who is authorized to make the transition. A summary or handoff does not itself prove approval or completion.
- Preserve real prerequisites and review gates. Report missing or inaccessible evidence and the smallest safe next step instead of guessing or marking work complete.
- Follow the ordered category flow and the project's permitted status transitions. When work in Reviews needs rework, attention, or blocker resolution, return it to the appropriate Progressing status. Do not move backward between other categories or bypass required gates.
- Record the reason, owner, and next action in the applicable record when a transition, blocker, or decision requires it. Continue independent work when safe.

## Boundaries and examples

- A review-ready change needs the selected workflow's actual verification evidence, not merely a builder's statement that implementation is nearly done.
- A small personal checklist can map its simple labels to the four categories and use proportionate checks; it does not require a formal review or a GitHub issue.
- The categories do not mandate identical board columns, status names, or the same number of statuses in each project. This principle does not authorize board migration, start managed delivery, or replace the selected workflow's approval rules. Reconcile an existing incompatible workflow before applying a changed mapping; do not silently bypass its current gates.
