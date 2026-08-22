---
name: documentation-standard
description: Use whenever creating, updating, searching, or organizing documentation in the central Obsidian vault at /home/chrissim/Projects/documentation. This is a vault workflow: always use obsidian-markdown for notes and obsidian-bases for Bases; use obsidian-cli when available.
---

# Documentation Standard

This is the central Obsidian architecture-vault documentation workflow. Use this skill whenever creating, updating, searching, or organizing documentation. Always load and follow `obsidian-markdown` for Markdown notes and `obsidian-bases` for `.base` files.

This skill should also help decide what kind of document to create. In particular, it must distinguish clearly between:

- `adr`: why a durable technical decision was made
- `arch`: how the system is structured or what the canonical technical truth is
- `gov`: what control, policy, traceability, or governance record must exist

## Required Behavior

- Treat `/home/chrissim/Projects/documentation` as an Obsidian vault, not as an ordinary repository docs folder.
- Never create project documentation directly in the vault root `/home/chrissim/Projects/documentation/`.
- Always resolve the project folder by sourcing `./.github-project.env` in the repository (the sole committed project config source) and using `ANT_TEAM_DOCS_PROJECT_PATH`, and write under `/home/chrissim/Projects/documentation/projects/<project-name>/` (or the configured equivalent).
- Root-level vault files are reserved for vault-wide indexes, governance entry points, and architecture-meta references; they are not valid destinations for project notes.
- After completing any vault documentation task, inspect the diff, commit only the files changed for that task, and push the commit to the vault remote. Never stage unrelated user changes or secrets.
- For every vault documentation task, use the Obsidian skills before editing: `obsidian-markdown` for notes and `obsidian-bases` for Bases.
- Before creating or updating any Obsidian note, inspect the central vault available templates under 01-Architecture-Meta/Templates/ and use the matching template.
- Before creating or updating any Obsidian Base, inspect the available Bases under 01-Architecture-Meta/Templates/Bases/ and extend the matching Base instead of inventing a parallel one.
- Never create a new documentation type, note structure, property set, or Base without first checking for an available template. If no suitable template exists, stop and request a template or explicit approval to create one.
- Preserve template frontmatter, required properties, naming conventions, and linked Base fields; do not silently create incompatible metadata.

- The canonical product documentation root is `/home/chrissim/Projects/documentation`.
- Resolve the project-specific destination from `ANT_TEAM_DOCS_PROJECT_PATH` by sourcing `./.github-project.env` — the sole committed project config source.
- Use `obsidian-markdown` whenever creating or editing Obsidian Markdown, properties, wikilinks, embeds, callouts, or templates.
- Use `obsidian-bases` whenever creating or editing `.base` files, Base filters, views, formulas, or summaries.
- Use `obsidian-cli` only when a running Obsidian instance is available; otherwise edit valid vault files directly and validate their structure.
- Read the central vault governance and project notes before changing product documentation.
- Do not create new product documentation under a repository `docs/` or `.docs/` folder. Keep only code-adjacent operational guidance locally.
- Do not rely on numeric document ordering.
- Use stable IDs such as `ADR-001`, `GOV-001`, `ARCH-001`, `SPEC-001`, `DB-001`, `API-001`, `DEPLOY-001`, `QA-001`, or `RUNBOOK-001`.
- Use `adr` for architecture decision records.
- Use `gov` for governance, standards, policies, conventions, and required process docs.
- Use `arch` for customized architecture decisions and architecture guidance specific to the repository.
- Prefer the central Obsidian vault folder convention defined by the `ANT_TEAM_DOCS_*` exports from `.github-project.env` (the sole committed project config source).
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

For `spec` documents, include all of the following. A spec missing any business section is not implementation-ready.

Business sections (owned by strategist — must be complete enough to answer future business questions without re-interviewing the founder):

- Problem statement: what problem this solves, for whom, and why it matters now
- Business value: the measurable or observable outcome for the founder or users if this succeeds
- Success metrics: how we know this worked — specific, observable, and time-bounded where possible
- Goals: what this spec is trying to achieve
- Non-goals: what is explicitly out of scope and why
- Stakeholders: who is affected, who must approve, who is the primary user
- Constraints: time, budget, team size, dependencies, or non-negotiable technical limits

Technical sections (owned by tech-lead — each section must be present or explicitly marked "not applicable" with a reason):

- Functional requirements: what the system must do, written as specific behavioural statements
- Technical requirements: performance targets, scalability expectations, reliability requirements, SLA or SLO targets
- Data model changes: new or modified tables, collections, fields, indexes, constraints; migrations required; seed data
- API changes: new or modified endpoints or interfaces; request/response contracts; breaking changes; versioning strategy
- Security considerations: authentication and authorisation changes; data sensitivity classification; threat model notes; secrets or credential handling
- Integration points: external services, internal services, or queues this change touches; contract and failure behaviour for each
- Observability requirements: logging expectations, metrics to emit, alerting thresholds, tracing needs
- Error handling: how errors are surfaced to users or callers; retry or fallback behaviour; failure modes
- Testing strategy: what must be tested (unit, integration, end-to-end, smoke); who writes the tests; coverage expectations
- Architecture notes: relevant decisions or guardrails from the central Obsidian project path; any new ADR or ARCH doc needed
- Acceptance criteria at the spec level: the conditions that prove the spec is fully delivered; each criterion must be traceable to at least one implementation task; criteria should be verifiable, not subjective
- Rollout and rollback plan: phasing, feature flags, migration steps, rollback procedure, and who is responsible for each step

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

For architecture principles, use the TOGAF 10 EA principle format defined by the central vault governance standard.

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

For code-adjacent `deployment` or `runbook` documents, include:

- Prerequisites
- Commands
- Environment variables
- Rollback
- Troubleshooting

For code-adjacent `qa` documents, include:

- Smoke checks
- Test commands
- Expected result
- Known gaps

## Document Discovery Guidance

When looking for relevant docs:

- Read the central vault project record and relevant notes under `/home/chrissim/Projects/documentation/projects/<project-name>/` first.
- Match by frontmatter properties, tags, keywords, domain, project, and document type.
- Then search the central vault by topic, feature name, domain terms, filenames, paths, module names, and synonyms.
- Treat the index as an accelerator, not the only source of truth.
- If the repository has a governance document describing how an external master enterprise architecture is applied locally, read that before creating new architecture-principle, governance, or architecture-reference docs.

## Obsidian Workflow

When documentation work involves the central vault:

1. Source `./.github-project.env` — the sole committed project config source — and resolve the vault and the exact project folder from `ANT_TEAM_DOCS_VAULT_PATH` and `ANT_TEAM_DOCS_PROJECT_PATH`.
2. Confirm the destination is the project-specific folder, never the vault root.
3. Inspect the matching template before editing; stop if none exists.
4. Load `obsidian-markdown` for note authoring and link/property conventions.
5. Load `obsidian-bases` for portfolio, project, architecture, or memory views.
6. Create or update the note in the resolved project folder using the approved template.
7. Verify frontmatter, internal links, and Base references.
8. Keep GitHub links as external execution references; do not duplicate live issue status in notes.

## Preferred Paths

Use `ANT_TEAM_DOCS_PROJECT_PATH` (sourced from `./.github-project.env`, the sole committed project config source) for all product, architecture, ADR, governance, lifecycle, and specification documents. Resolve to the current project folder under the central Obsidian vault. Do not create these documents in repository `docs/` or `.docs/`.
