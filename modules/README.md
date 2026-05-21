# OPC MCP Tools

This module exposes all OPC workflow commands from `../scripts/*.sh` as MCP tools.

## What it provides

- One generic tool: `opc_run_command`
- One tool per script, named as `opc_<script_name>` with dashes converted to underscores

Examples:

- `scripts/create-task.sh` -> `opc_create_task`
- `scripts/record-pr.sh` -> `opc_record_pr`
- `scripts/validate-project-state.sh` -> `opc_validate_project_state`

`pm-lib.sh` is intentionally excluded because it is a helper library, not a runnable command.

## Run locally

```bash
node one-person-company/modules/opc-mcp-server.mjs
```

## Tool arguments

All command tools accept:

- `args: string[]` (default `[]`)
- `doc_root: string` (default `"docs"`)
- `worktree?: string` (defaults to MCP process CWD)

The generic `opc_run_command` additionally requires:

- `command: string` (must be one of available scripts without `.sh`)

## MCP client config example

```json
{
  "mcpServers": {
    "opc-tools": {
      "command": "node",
      "args": [
        "/Users/chrissim/Projects/Antpolis/k3s-cluster/one-person-company/modules/opc-mcp-server.mjs"
      ]
    }
  }
}
```
