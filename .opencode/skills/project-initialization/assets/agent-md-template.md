# Agent Guide

This repository uses `__DOC_ROOT__` as the documentation root.

## What Agents Should Read First

- `__DOC_ROOT__/DOCUMENT_INDEX.md` if it exists
- product specs under `__DOC_ROOT__/spec/`
- architecture docs under `__DOC_ROOT__/architecture/` or equivalent
- ADRs under `__DOC_ROOT__/adr/`
- governance docs under `__DOC_ROOT__/governance/` or equivalent
- project-management artifacts under `__DOC_ROOT__/proj-management/`

## Working Rule

Do not assume the docs root is `docs/` or `.docs/` in this repository. Use `__DOC_ROOT__` as the authoritative docs root unless a newer repository instruction overrides it.

## Document Conventions

- ADRs: `ADR-001-short-kebab-case-title.md`
- Architecture docs: `ARCH-001-short-kebab-case-title.md`
- Governance docs: `GOV-001-short-kebab-case-title.md`

## Notes

- Keep repository docs aligned with code reality.
- If product docs and code disagree, surface the mismatch explicitly.
- If migration is in progress, treat migration notes as first-class project context.
