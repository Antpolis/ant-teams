# ADR Folder Guide

This folder contains Architecture Decision Records.

## Purpose

Use ADRs to capture durable technical decisions that change architecture, stack, runtime behavior, integration shape, security posture, or other meaningful system constraints.

## When To Add An ADR

Create an ADR when:

- the stack changes or is being migrated
- a major architecture direction is chosen
- a long-lived tradeoff is accepted
- a migration path or replacement strategy is approved
- future contributors need to understand why a decision was made

Do not use ADRs for routine progress updates or temporary implementation notes.

## Naming Convention

File name format:

`ADR-001-short-kebab-case-title.md`

Examples:

- `ADR-001-dotnet-to-spring-backend-replacement.md`
- `ADR-002-public-chat-with-optional-login.md`

Rules:

- use the `ADR-###` prefix with zero-padded numbering
- keep the rest of the title short, descriptive, and kebab-case
- never renumber an existing ADR after publication

## Recommended Structure

- Title
- Status
- Context
- Decision
- Consequences
- Alternatives Considered
- Compliance or governance impact if relevant

## Relationship To Other Docs

- Link related architecture and governance documents.
- If the ADR drives migration work, link the migration plan and implementation spec.
- If the decision changes repo standards, update the relevant governance doc too.
