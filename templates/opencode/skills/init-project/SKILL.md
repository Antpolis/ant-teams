---
name: init-project
description: Initialize or re-initialize the repository delivery baseline and central documentation routing. Founder-facing bootstrap flow, explicitly invoked with /init-project: runs the deterministic init-project engine unchanged, then tailors AGENTS.md from repository evidence with draft-before-write confirmation.
argument-hint: Optionally specify a focus area, e.g. build commands, architecture, or conventions
disable-model-invocation: true
---

# Init Project

Bootstrap the current repository for agentic delivery work. This skill is a thin
orchestration layer over the tested shell engine `$ANT_TEAM_SCRIPTS/init-project.sh`:

1. **Deterministic layer** — the engine seeds/updates `.github-project.env` and a
   minimal evidence-based `AGENTS.md` baseline. Never edit the engine or add shell
   logic here; this skill only calls it.
2. **Judgment layer** — after the engine runs, inspect repository evidence and tailor
   `AGENTS.md`: preserve existing content, update outdated sections, and confirm with
   the founder before any substantial overwrite or merge.

If the user passed a focus argument, prioritize that area during inspection and
tailoring. Do not start any other task in the argument.

## Workflow

### 1. Discuss intent before running

The engine writes only safe defaults; all project-specific content comes from founder
conversation or repository evidence. Before running it, discuss with the founder what
this repository is for and its GitHub project configuration.

### 2. Run the engine unchanged

Preview first, then apply:

```sh
"$ANT_TEAM_SCRIPTS/init-project.sh" --dry-run
"$ANT_TEAM_SCRIPTS/init-project.sh"
```

The engine is deterministic, byte-for-byte idempotent, and no-write under `--dry-run`.
Required behavior it upholds (do not work around it):

- founder-set `.github-project.env` values are preserved verbatim; only missing keys are filled
- never invent real-looking remote IDs; placeholders stay until founder-verified
- a pre-existing `AGENTS.md` is skipped, never overwritten without `--force`/`--merge`
- the legacy `agent.md` is never deleted

### 3. Inspect repository evidence

Explore the codebase for what makes an agent immediately productive here:

- build, test, and run commands (from manifests, CI, scripts — only what you actually find)
- architecture: source roots, component boundaries, deployment surface
- project-specific conventions that differ from common practice
- known pitfalls or environment quirks
- existing documentation to link, not duplicate (`README.md`, `docs/**`,
  `CONTRIBUTING.md`, architecture or ADR notes)

### 4. Tailor AGENTS.md from evidence

Every factual claim you add or change must trace to repository evidence inspected in
step 3 or explicit founder input. Do not invent tooling, commands, or architecture
claims. If evidence for a section is absent, keep the engine's minimal baseline for
that section and note the gap to the founder instead of filling it with assumptions.

- **Preserve**: existing founder content stays unless it is demonstrably outdated.
- **Update**: correct outdated sections; remove duplication.
- **Link, don't embed**: link to existing documentation instead of copying it.
- **Concise and actionable**: every line should guide behavior; sections without
  content stay absent.

### 5. Draft before writing

Present the proposed `AGENTS.md` changes as a concrete draft (added/edited sections,
what is preserved, what is linked) and get founder confirmation before any substantial
overwrite or merge of the file. If confirmation is declined, leave the engine-generated
baseline in place and record the decline as an open item — never force the write.

### 6. Confirm `.github-project.env` with the founder

Walk through owner, project number/ID, Workflow State field/option IDs, worktree root,
and vault paths; replace placeholders only with founder-verified values. Show the
resolved documentation path (`$ANT_TEAM_DOCS_PROJECT_PATH`) when done.

### 7. Delegate durable vault documentation

After founder confirmation, invoke `project-initialization` to create or update the
durable Obsidian baseline (project overview, architecture baseline, document index)
from repository evidence. This skill never writes vault architecture docs itself;
create SPEC, ADR, and GOV notes only when their content is known.

## Re-runs

Re-running is safe and idempotent: existing `.github-project.env` values are preserved
and only missing keys are filled. On re-run, skip straight to the evidence pass and
tailoring for anything the founder wants improved.
