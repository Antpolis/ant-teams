# Architecture Principles Standard

Metadata:

| Field | Value |
|---|---|
| ID | GOV-001 |
| Type | gov |
| Domain | architecture governance |
| Status | active |
| Owner | one-person-company |
| Applies To | architecture docs, governance docs |
| Keywords | TOGAF 10 EA, architecture principles, principle template, rationale, implications |
| Related Docs | documentation-standard, docs/DOCUMENT_INDEX.md |
| Supersedes |  |
| Last Updated | 2026-05-19 |

## Summary

This document defines the company standard for writing architecture principles.

## Context

The company follows TOGAF 10 EA for architecture principle structure. Architecture principles must be concise, durable, and usable as decision guidance.

## Standard

Every architecture principle must use this structure:

```md
# <Principle Name>

Metadata:

| Field | Value |
|---|---|
| ID | <stable-id> |
| Type | arch or gov |
| Domain | architecture governance |
| Status | active |
| Owner | <owner or team if known> |
| Applies To | <systems, teams, or decisions> |
| Keywords | <search terms> |
| Related Docs | <related docs> |
| Supersedes | <older principles or blank> |
| Last Updated | <YYYY-MM-DD> |

## Statement

<One concise, normative statement of the principle.>

## Rationale

<Why the principle exists and what risk or goal it addresses.>

## Implications

<What must change in behavior, design, review, or operations if this principle is followed.>

## Related Guidance

<Links to related ADR, ARCH, GOV, or specs.>
```

## Rules

- Keep the principle statement short and testable.
- Use normative language such as `must`, `shall`, or `should` consistently.
- Avoid writing implementation detail into the principle statement.
- Include rationale and implications for every principle.
- Keep architecture principles stable; only change them when the company direction truly changes.

## Enforcement

- Use this format whenever creating a new architecture principle.
- Update the document index when a new principle or principle standard is added.
- Review architecture principles during architecture review and governance updates.

## Related Documents

- `docs/DOCUMENT_INDEX.md`
- `docs/arch/ARCH-001-skill-delegation.md`
- `one-person-company/skills/documentation-standard/SKILL.md`
