# Project Baseline Templates

Use these templates after repository inspection. Keep only evidence-backed content. All vault-internal references must use Obsidian wikilinks.

## `PROJECT_OVERVIEW.md`

```md
---
title: <Project> overview
tags: [project, overview]
status: active
created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
---

# <Project> Overview

## Purpose And Current State

<Observed product purpose and implementation state. State uncertainty explicitly.>

## Agent Starting Point

1. Start with the assigned GitHub issue and its Durable Context links.
2. Read the linked [[SPEC-...|SPEC]], [[ARCH-...|architecture]], ADR, GOV, and runbook records.
3. Record active delivery work in GitHub; update this vault only for durable knowledge.

## Open Questions

- <Question and owner>

## Related Documents

- [[DOCUMENT_INDEX|Document index]]
- [[ARCH-001-current-system-architecture|Current system architecture]]
- [[PROJECT_STRUCTURE|Project structure]]
```

## `architecture/ARCH-001-current-system-architecture.md`

```md
---
title: <Project> current system architecture
tags: [architecture]
status: active
created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
---

# Current System Architecture

## Observed Components And Boundaries

<Components, ownership, dependencies, and interfaces.>

## Runtime And Delivery

<Stack, deployment, CI, data stores, external services, and verification evidence.>

## Known Gaps And Risks

- <Observed gap; do not label it a decision without evidence.>

## Related Documents

- [[PROJECT_OVERVIEW|Project overview]]
- [[PROJECT_STRUCTURE|Project structure]]
- [[DOCUMENT_INDEX|Document index]]
```

## `PROJECT_STRUCTURE.md`

```md
---
title: <Project> structure
tags: [project, structure]
status: active
created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
---

# Project Structure

| Path | Responsibility | Evidence / Notes |
|---|---|---|
| `<path>` | <responsibility> | <evidence> |

## Related Documents

- [[PROJECT_OVERVIEW|Project overview]]
- [[ARCH-001-current-system-architecture|Current system architecture]]
```
