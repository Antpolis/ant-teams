# Governance Folder Guide

This folder contains governance records, policy docs, and traceability logs.

## Purpose

Use governance docs to record approvals, implementation control rules, risk controls, policy enforcement, and decision traceability over time.

Governance docs are especially useful during migrations, sensitive refactors, and multi-step delivery programs where execution needs explicit controls.

## When To Add A Governance Doc

Create or update a governance doc when:

- a migration or replacement effort needs an execution log
- a policy or control rule needs to be enforced
- approvals and status history must be traceable
- implementation packages need documented sign-off state

## Naming Convention

File name format:

`GOV-001-short-kebab-case-title.md`

Examples:

- `GOV-001-backend-replacement-governance-log.md`
- `GOV-002-auth-hardening-policy.md`

Rules:

- use the `GOV-###` prefix with zero-padded numbering
- keep the rest of the title descriptive and kebab-case
- use one file for the same ongoing governance log rather than creating many tiny fragments

## Recommended Structure

Governance docs may take one of two common forms:

1. Policy or standard
   - purpose
   - scope
   - required behavior
   - exceptions
   - enforcement

2. Governance log
   - dated entries
   - plan or package identifier
   - status
   - decision context
   - evidence
   - traceability links

## Relationship To Other Docs

- Governance tracks control and traceability.
- ADRs capture durable decisions.
- Architecture docs capture system truth.
- Specs and plans capture intended delivery work.
