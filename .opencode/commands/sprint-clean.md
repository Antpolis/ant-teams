---
description: "Reconcile recent delivered work against specs, tasks, board state, and docs before sprint planning."
agent: ant
---

Explicitly run the managed `sprint-clean` workflow for: $ARGUMENTS

Load `github-agentic-delivery-flow` and read its `references/sprint-clean.md` procedure. Execute that procedure for the supplied scope. This command does not authorize another delivery stage.
