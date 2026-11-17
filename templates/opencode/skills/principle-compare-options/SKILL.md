---
name: principle-compare-options
description: Apply when choosing between product, technical, or workflow approaches and the consequences or uncertainty warrant comparison; examine realistic alternatives in proportion to the decision rather than defaulting to the first idea.
---

# Compare Options in Proportion to the Decision

## Trigger

Apply when a meaningful scope, product, architecture, or workflow decision has plausible alternatives, especially when it is costly to reverse or depends on uncertain assumptions. A clear, low-risk choice does not require a formal option study.

## Rule

Compare the proposed approach with the smallest credible alternatives, including doing less, using an existing capability, or validating first when relevant. Judge them by the outcome they enable, user and maintainer impact, feasibility, risks, and cost—not by novelty or the amount of code produced. Increase the depth of investigation as consequences and uncertainty increase.

## Apply

- Understand the user, problem, constraints, and what success would look like. Separate evidence from assumptions and identify who controls each option.
- Investigate options using existing code, documentation, observed behavior, or a focused experiment. A manual process, existing tool, or narrow slice may be the best alternative. Prototype only when it can resolve a consequential uncertainty more effectively than available evidence.
- Give an honest recommendation with concrete trade-offs and the smallest useful next step. If evidence is insufficient, say what would change the decision. Bring genuinely unresolved product preferences or authority decisions to their owner.
- Use `idea-challenge` when the user asks to pressure-test a new product idea and `ponytail` for the smallest complete implementation where applicable. Reading this principle does not start a managed workflow or require GitHub artifacts.

## Boundaries and examples

- Before building a custom analytics dashboard, compare a focused improvement to an existing report, an off-the-shelf option, and the proposed build against the user's actual reporting need.
- For an obvious typo fix, correct and verify it; generating multiple designs would add effort without reducing meaningful risk.
- Do not manufacture alternatives, make external-party cooperation sound guaranteed, or trade required security and accessibility for a cheaper option. Where alternatives are constrained, state the constraint rather than pretending there is a choice.
