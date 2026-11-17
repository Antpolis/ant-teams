---
name: principle-design-code-for-readers
description: Apply when writing, refactoring, or reviewing code; make responsibilities, names, and control flow clear to the people who will read and maintain it.
---

# Design Code for Readers

## Trigger

Apply when choosing how to organize, name, or express code, and when assessing whether an existing implementation is understandable. Scale the effort to the change and its maintenance risk.

## Rule

Make the code's purpose and behavior easy to follow without unnecessary indirection or surprise. Favor clear responsibilities and familiar project conventions over cleverness; add structure only when it helps a reader understand or change the code.

## Apply

- Give functions, modules, and names clear responsibilities and meaning. Keep unrelated concerns apart when doing so improves comprehension, while following the repository's established boundaries.
- Prefer explicit control flow and local reasoning over hidden effects, magical behavior, or compressed expressions. Keep the common path easy to follow and make meaningful side effects visible.
- Use concise comments to explain intent, constraints, or non-obvious trade-offs that the code cannot readily express. Do not repeat the code or use a comment to excuse a confusing design that can be simplified.
- Judge readability in context: an extra well-named step can be clearer than a dense one-liner, and a small function with multiple closely related operations is not automatically a problem. Avoid splitting code or introducing abstractions merely to satisfy a rule of thumb.
- When reviewing, identify concrete evidence and maintenance impact; distinguish a material readability risk from a personal preference. Preserve required behavior and use `principle-change-existing-code-safely` when refactoring.

## Boundaries and examples

- If a helper named `load_config` also sends notifications, separate or rename responsibilities in a way that makes the actual behavior clear and fits the project.
- A short, obvious local calculation does not need to be extracted into a separate function simply to make it look structured.
- Do not sacrifice correctness, security, accessibility, performance requirements, or repository constraints for a stylistic preference. This principle does not start a managed workflow or make every readability suggestion a review blocker.
