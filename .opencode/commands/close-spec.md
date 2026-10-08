---
description: "Close and release a completed SPEC: reconcile milestone issues and board state, create the GitHub Release/tag, close the milestone, and safely clean merged task workspaces."
agent: ant
---

Explicitly run the managed `close-spec` workflow for: $ARGUMENTS

Load `github-agentic-delivery-flow` for shared delivery rules and `spec-closeout` for the canonical procedure. Execute that procedure for the supplied scope.
