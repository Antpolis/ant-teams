---
description: "Execute the selected approved spec through implementation, review, and merge."
agent: ant
---

Explicitly run the managed `do-tasks` workflow for: $ARGUMENTS

Load `github-agentic-delivery-flow` for shared delivery rules and `do-task` for the canonical procedure. Resolve the selected spec and execute its required issues through review and merge. Respect an explicitly narrowed scope. Continue past individual issue completion until scoped work is done or no safe scoped action remains. Do not create releases, close milestones, or start another spec automatically.
