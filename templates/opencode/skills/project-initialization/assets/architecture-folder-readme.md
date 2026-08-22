# Architecture Folder Guide

This folder contains repository-specific architecture documents.

## Purpose

Use architecture docs to describe the current or target system shape, canonical data ownership, boundaries, flows, constraints, and implementation guardrails.

These documents are the place for technical structure and system truth, not for one-time decision approval logs.

## When To Add An Architecture Doc

Create or update an architecture doc when:

- the system has a canonical flow or model that needs one source of truth
- multiple specs or ADRs defer to the same technical reference
- contributors need guidance on boundaries, ownership, or dependency rules
- a migration introduces coexistence between old and new systems

## Naming Convention

File name format:

`ARCH-001-short-kebab-case-title.md`

Examples:

- `ARCH-001-system-boundaries-and-service-ownership.md`
- `ARCH-006-knowledge-workflow-single-source-of-truth.md`

Rules:

- use the `ARCH-###` prefix with zero-padded numbering
- keep the rest of the title descriptive and kebab-case
- prefer stable titles for canonical reference docs

## Recommended Structure

- Purpose
- Scope
- Audience
- Terminology or glossary if needed
- Canonical data model or ownership model
- Flow diagrams or dependency diagrams
- Constraints and guardrails
- Traceability to ADRs, governance, plans, or specs

## Relationship To Other Docs

- Architecture docs explain how the system works.
- ADRs explain why a major decision was made.
- Governance docs explain required controls, policy, or traceability.
