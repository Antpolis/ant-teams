# Master Enterprise Architecture Reference And Local Application

Metadata:

| Field | Value |
|---|---|
| ID | GOV-002 |
| Type | gov |
| Domain | architecture governance |
| Status | active |
| Owner | one-person-company |
| Applies To | all agents, architecture docs, governance docs, ADRs |
| Keywords | master enterprise architecture, TOGAF 10 EA, Google Drive, local application, architecture governance, ADR, ARCH, GOV |
| Related Docs | GOV-001, documentation-standard, project-initialization |
| Supersedes |  |
| Last Updated | 2026-05-21 |

## Summary

This document defines how this repository uses the company master enterprise architecture when that master source lives outside the repo, currently in Google Drive.

## Context

The company follows TOGAF 10 EA across projects. The master enterprise architecture is maintained outside this repository in Google Drive. This repo still needs a clear local rule so agents and developers know:

- where the authoritative enterprise architecture lives
- what should be copied into this repo versus only referenced
- how local governance, architecture, and decision records relate to the master source

Without this rule, local docs can drift, duplicate enterprise material unnecessarily, or misuse `GOV`, `ARCH`, and `ADR` documents.

## Master Source Rule

The company master enterprise architecture stored in Google Drive is the authoritative enterprise-level source unless a future governance decision replaces it.

Record the canonical Google Drive location here when available:

- Master EA location: `<replace-with-google-drive-link-or-path>`

If this repository later receives a repo-based mirrored or authoritative copy, update this governance document to say which location is authoritative for engineering use.

## Local Document Rules

This repository should not copy the entire enterprise architecture into local docs by default.

Instead:

- use local `GOV` docs to record how this repo is governed under the master EA
- use local `ARCH` docs to explain how this repo's system is structured and how it applies enterprise principles
- use local `ADR` docs to explain why significant local technical decisions were made

## How To Use GOV, ARCH, And ADR In This Repo

### GOV

Use local governance docs when the repository needs:

- local control rules
- policy application notes
- migration governance logs
- sign-off or traceability records
- clarification on how the master EA applies here

Governance answers:

- what rules must be followed here
- what controls or traceability must exist
- how local work is governed under the master EA

### ARCH

Use local architecture docs when the repository needs:

- a canonical technical source of truth
- system boundaries, flows, ownership, or dependency rules
- explanation of how this project applies enterprise architecture principles
- migration coexistence structure between old and new systems

Architecture answers:

- how this repo's system works
- how this repo applies the enterprise architecture locally

### ADR

Use local ADRs when the repository needs:

- a durable decision record
- rationale for a local stack choice or migration choice
- explanation of a major local technical tradeoff or deviation

ADR answers:

- why a significant local decision was made

## Architecture Principles Rule

Architecture principles follow the TOGAF 10 EA structure defined in `GOV-001`.

Enterprise-wide principles should remain in the master EA source unless there is a deliberate reason to mirror or restate them locally.

If a local project-specific principle must exist, it must:

- use the `GOV-001` principle format
- state clearly whether it is derived from or supplemental to the master EA
- link back to the master EA source or controlling governance doc when possible

## Mirroring Guidance

It is acceptable to mirror selected enterprise architecture content into this repo when:

- agents or developers need reliable local access
- the specific subset is directly relevant to this repository
- versioning and review in code are more important than Drive-only access

If mirrored locally:

- make the mirror scope explicit
- state whether the mirror is authoritative or reference-only
- link to the master source
- keep update responsibility clear

## Working Rule For Agents

When working in this repository:

1. Assume the master enterprise architecture is external and authoritative at the enterprise level.
2. Use local docs only for local application, local control, local structure, and local decisions.
3. Do not rewrite enterprise-wide principles into project docs unless there is a clear reason.
4. If the master EA source cannot be accessed, state that limitation explicitly and continue using the best local evidence available.

## Enforcement

- New local `GOV`, `ARCH`, and `ADR` docs should follow this separation of concerns.
- Project initialization should reference this governance rule when setting up repo documentation.
- Architecture reviews should check whether local docs are incorrectly duplicating enterprise material.

## Related Documents

- `docs/gov/GOV-001-architecture-principles-standard.md`
- `docs/arch/ARCH-001-skill-delegation.md`
- `.opencode/skills/documentation-standard/SKILL.md`
- `.opencode/skills/project-initialization/SKILL.md`
