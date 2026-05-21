---
name: documentation-standard
description: Use when creating or updating project documentation under docs/, .docs/, or ~/.config/opencode/docs, including ADR, GOV, ARCH, specs, runbooks, API docs, database docs, deployment docs, QA docs, or document index entries. Intended for docs-focused roles and documentation tasks; not for CPO/CTO/spec-governance drafting unless explicitly updating docs.
---

# Documentation Standard

Use this skill whenever creating or updating repository documentation.

This skill should also help decide what kind of document to create. In particular, it must distinguish clearly between:

- `adr`: why a durable technical decision was made
- `arch`: how the system is structured or what the canonical technical truth is
- `gov`: what control, policy, traceability, or governance record must exist

## Required Behavior

- Documentation roots are `docs/`, `.docs/`, and the global company docs root `~/.config/opencode/docs/`.
- Check for `docs/DOCUMENT_INDEX.md`, `.docs/DOCUMENT_INDEX.md`, then `DOCUMENT_INDEX.md`, in that order.
- If an index exists, add or update the document row there.
- If no index exists, create `docs/DOCUMENT_INDEX.md` before adding new docs unless the repository already uses `.docs/` or the global company docs root.
- Do not rely on numeric document ordering.
- Use stable IDs such as `ADR-001`, `GOV-001`, `ARCH-001`, `SPEC-001`, `DB-001`, `API-001`, `DEPLOY-001`, `QA-001`, or `RUNBOOK-001`.
- Use `adr` for architecture decision records.
- Use `gov` for governance, standards, policies, conventions, and required process docs.
- Use `arch` for customized architecture decisions and architecture guidance specific to the repository.
- Prefer the repository's real folder conventions when present. If the repo uses `docs/architecture/` and `docs/governance/`, follow that instead of forcing `docs/arch/` and `docs/gov/`.
- Prefer content-based metadata: domain, applies-to, keywords, related docs, and supersedes.
- Mark stale or replaced docs as `deprecated` or `superseded`; do not silently delete historical docs unless explicitly asked.
- Keep documentation technical, specific, and actionable.

## Document Type Routing

Choose the document type intentionally.

### Use `adr` when:

- the document explains why a major technical decision was made
- a stack replacement, migration strategy, or architecture direction is being approved
- future contributors will need the decision context, alternatives, and consequences

Think: decision record.

### Use `arch` when:

- the document is the canonical reference for how the system works
- multiple specs, ADRs, or plans should defer to one technical source of truth
- the document defines boundaries, ownership, flow, terminology, canonical models, or implementation guardrails

Think: structural or canonical technical reference.

### Use `gov` when:

- the document records policy, control rules, enforcement expectations, sign-off state, or traceability over time
- a migration or delivery program needs a governance log
- approvals, status history, or implementation control evidence must be preserved
- the repository needs a local rule describing how an external master enterprise architecture applies here

Think: policy or governance record.

### Quick heuristic

- `Why did we choose this?` -> `adr`
- `How does this system work?` -> `arch`
- `What control, policy, or approval trail do we need?` -> `gov`

If the repository has a local governance document that explains how it relates to an external master enterprise architecture, use that governance document as the routing rule before creating new local `ADR`, `ARCH`, or `GOV` material.

## Document Index

The repository document index must use this table:

```md
# Document Index

| ID | Title | Type | Domain | Status | Path | Summary | Keywords | Applies To | Related Docs | Supersedes | Last Updated |
|---|---|---|---|---|---|---|---|---|---|---|---|
```

Column definitions:

- `ID`: Stable identifier, not derived from file order.
- `Title`: Human-readable document title.
- `Type`: One of `adr`, `gov`, `arch`, `spec`, `api`, `database`, `deployment`, `qa`, `runbook`, `troubleshooting`, `decision`, or `reference`.
- `Domain`: System area, feature area, or technical domain.
- `Status`: One of `draft`, `active`, `deprecated`, or `superseded`.
- `Path`: Exact repository-relative path.
- `Summary`: One concise sentence explaining the document purpose.
- `Keywords`: Search terms, aliases, feature names, modules, services, tables, APIs, tools, and likely synonyms.
- `Applies To`: Modules, services, components, environments, or teams affected by the document.
- `Related Docs`: IDs of documents that should be read together.
- `Supersedes`: IDs of older documents replaced by this document, or blank.
- `Last Updated`: ISO date, `YYYY-MM-DD`.

## Standard Document Template

Every new document should use this template unless a more specific format is required:

```md
# <Title>

Metadata:

| Field | Value |
|---|---|
| ID | <stable-id> |
| Type | <adr/gov/arch/spec/api/database/deployment/qa/runbook/troubleshooting/decision/reference> |
| Domain | <domain> |
| Status | <draft/active/deprecated/superseded> |
| Owner | <owner or team if known> |
| Applies To | <services/modules/components/environments> |
| Keywords | <comma-separated searchable terms> |
| Related Docs | <doc IDs or paths> |
| Supersedes | <doc IDs or blank> |
| Last Updated | <YYYY-MM-DD> |

## Summary

<One short paragraph describing the document purpose.>

## Context

<Relevant background, problem, constraints, and assumptions.>

## Details

<Technical details, design, behavior, configuration, commands, interfaces, or workflow.>

## Decisions

<Decisions made by this document, if any. Use bullets.>

## Guardrails

<Rules developers must follow. Use bullets.>

## Verification

<How to verify the document remains correct, including commands if relevant.>

## Related Documents

<Links to related docs by ID and path.>
```

## Type-Specific Additions

For `spec` documents, include:

- Goals
- Non-goals
- Functional requirements
- Technical requirements
- Acceptance criteria
- Rollout or migration plan if applicable

For `arch` documents, include:

- Purpose
- Scope
- Audience
- System boundaries
- Components
- Data flow
- Canonical models or ownership models when relevant
- Operational concerns
- Failure modes
- Repository-specific architecture constraints
- Developer guardrails
- Traceability to ADRs, governance docs, plans, or specs

For architecture principles, use the TOGAF 10 EA principle format defined in `docs/gov/GOV-001-architecture-principles-standard.md`:

- Statement
- Rationale
- Implications

For `adr` or `decision` documents, include:

- Status
- Context
- Decision
- Options considered
- Consequences
- Risk controls or rollout constraints when relevant
- Reversal criteria if the decision is intentionally reversible
- Compliance or governance impact when relevant

For `gov` documents, include:

- one of these forms:
  - policy or standard
  - governance log

For `gov` policy or standard documents, include:

- Policy or standard
- Scope
- Required behavior
- Exceptions
- Enforcement or review process

For `gov` governance log documents, include:

- dated entries
- plan, package, or workstream identifier
- status
- decision context
- evidence
- traceability links

For `gov` documents that define local application of an external enterprise architecture, include:

- where the master enterprise architecture lives
- whether that source is authoritative or mirrored
- what should remain external versus local
- how local `GOV`, `ARCH`, and `ADR` docs should be used
- mirroring or traceability rules if relevant

For `api` documents, include:

- Endpoints or interfaces
- Request and response schemas
- Error cases
- Compatibility notes

For `database` documents, include:

- Tables or collections
- Migrations
- Indexes
- Constraints
- Backup or restore notes

For `deployment` or `runbook` documents, include:

- Prerequisites
- Commands
- Environment variables
- Rollback
- Troubleshooting

For `qa` documents, include:

- Smoke checks
- Test commands
- Expected result
- Known gaps

## Document Discovery Guidance

When looking for relevant docs:

- Read `docs/DOCUMENT_INDEX.md`, `.docs/DOCUMENT_INDEX.md`, or `DOCUMENT_INDEX.md` first if present.
- Match by `Keywords`, `Domain`, `Applies To`, and `Summary`.
- Then search repository content under `docs/` and `.docs/` for the deliverable terms and synonyms.
- Treat the index as an accelerator, not the only source of truth.
- If the repository has a governance document describing how an external master enterprise architecture is applied locally, read that before creating new architecture-principle, governance, or architecture-reference docs.

## Preferred Paths

Use these folders when creating new documents if the repository does not already have a stronger convention:

- `docs/adr/` or `.docs/adr/` for ADRs.
- `docs/governance/`, `docs/gov/`, `.docs/governance/`, or `.docs/gov/` for governance and standards.
- `docs/architecture/`, `docs/arch/`, `.docs/architecture/`, or `.docs/arch/` for repository-specific architecture guidance.
- `~/.config/opencode/docs/adr/`, `~/.config/opencode/docs/gov/`, and `~/.config/opencode/docs/arch/` for global enterprise defaults.
- `docs/spec/` or `.docs/spec/` for product and enhancement specs.
- `docs/runbook/` or `.docs/runbook/` for runbooks.
- `docs/qa/` or `.docs/qa/` for QA and smoke-test docs.

## Naming Conventions

When creating these document types, use zero-padded stable prefixes plus a descriptive kebab-case title:

- `ADR-001-short-kebab-case-title.md`
- `ARCH-001-short-kebab-case-title.md`
- `GOV-001-short-kebab-case-title.md`

Do not renumber published documents casually.
