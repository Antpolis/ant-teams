---
description: "Sync provided local specs and plans into GitHub milestones and task issues, then complete the handoff state."
agent: ant
---

Explicitly run the managed `sync-spec` workflow for: $ARGUMENTS

Load `github-agentic-delivery-flow` and read its `references/sync-spec.md` procedure. Execute that procedure for the supplied scope. This command does not authorize another delivery stage.
