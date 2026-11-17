---
name: playbook-documentation
description: Use when creating, revising, or organizing documentation that needs a deliberate authoring procedure; choose the appropriate collaboration, destination, format, and verification without imposing a managed workflow on ordinary work.
---

# Documentation Playbook

## Scope and entry

Use this playbook to produce or update documentation that its intended readers can use. Start from the user's request, existing material, and repository guidance. A small correction can use a proportionate subset of these steps; explain a material skip or limitation. Reading this playbook does not itself start managed delivery, create GitHub artifacts, or authorize a commit or push.

## Applicable principles and skills

- Apply `principle-write-for-the-audience` to audience, purpose, collaboration, and reader verification; use `principle-concise-actionable-communication` where applicable.
- Apply `principle-respect-project-constraints` to applicable documentation routing, templates, ownership, and publication requirements.
- For central vault work, follow `documentation-standard` for document types, templates, SPEC identifiers, ownership, and vault-specific rules. Load `obsidian-markdown` for Obsidian notes and `obsidian-bases` for Bases; do not impose their syntax on ordinary Markdown.

## Procedure

1. **Establish the outcome.** Identify audience, document purpose, intended action, existing source material, scope, and owner from available evidence. Ask focused questions only when consequential information cannot be resolved safely; let the user choose a freeform collaboration style.
2. **Choose the destination and format.** Follow the repository's documentation routing and applicable instructions. Determine whether the request calls for an existing document, a new document, or an operational record. Ordinary work does not require the central vault or GitHub unless applicable project rules or the user require it. Do not duplicate live managed-workflow state in durable documentation.
3. **Gather context and select a structure.** Read relevant source, existing documents, and applicable templates. Choose an appropriate document type; for vault work follow `documentation-standard` and stop when its required template is unavailable. Identify assumptions, missing evidence, and required decisions rather than inventing them.
4. **Draft or revise.** Explain the outcome, rationale, evidence, limitations, and next action as relevant to the reader and document type. Preserve required metadata, format, links, and existing unrelated content. Collaborate iteratively when useful, without requiring a full interview for small changes.
5. **Verify and return.** Check factual claims against sources, document structure and links, and whether the intended reader can act. For consequential or ambiguous documents, seek an independent or fresh-context reader check when practical; otherwise report the limitation. Summarize changes, checks, unresolved questions, and next owner or action.

## Failure, publication, and workflow boundaries

- If evidence, access, a required template, or a consequential decision is missing, explain the impact and propose the smallest feasible next step. Do not claim the document is complete or planning-ready without the required evidence and decisions.
- Preserve existing user work. Before staging, committing, or publishing, follow applicable project instructions and user authorization. If those conflict, do not perform the conflicting action; report it and request the needed direction. Never stage unrelated changes or secrets.
- In an explicitly active managed workflow, retain its role ownership, approval gates, and GitHub operational record. Durable vault documentation follows the applicable `documentation-standard` and project governance; a playbook does not change those rules.
