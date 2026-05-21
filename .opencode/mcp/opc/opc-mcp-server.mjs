#!/usr/bin/env node

import { readdirSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { spawn } from "node:child_process"
import process from "node:process"

import { Server } from "@modelcontextprotocol/sdk/server/index.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import {
  CallToolRequestSchema,
  ListPromptsRequestSchema,
  ListResourcesRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const scriptsDir = path.join(__dirname, "scripts")

function listOpcScripts() {
  const excluded = new Set(["init-company.sh", "init-project-docs.sh", "update-company.sh"])
  return readdirSync(scriptsDir)
    .filter((name) => name.endsWith(".sh") && name !== "pm-lib.sh" && !excluded.has(name))
    .map((name) => name.slice(0, -3))
    .sort()
}

const scriptNames = listOpcScripts()

const COMMAND_DETAILS = {
  "add-task-dependency": { purpose: "Add a dependency edge between two tasks in the same spec.", output: "Updates dependencies in task and board, then appends a dependency log entry.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "depends_on_task_id", required: true }] },
  "close-task": { purpose: "Close a task after approval and attach closure evidence.", output: "Marks task done/closed and records evidence in communication artifacts.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "evidence", required: true }] },
  "close-fast-task": { purpose: "Close a lightweight fast-path task after validation completes.", output: "Marks a fast-path task done and records closure evidence.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "evidence", required: true }] },
  "create-blocker": { purpose: "Create a hard blocker record linked to a task.", output: "Writes blocker metadata and required unblock actions.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "blocker_id", required: true }, { name: "blocker_type", required: true }, { name: "description", required: true }, { name: "needs", required: true }] },
  "create-quick-task": { purpose: "Add a lightweight task under an existing fast-path spec.", output: "Creates a small fast-path task, auto-generating the task ID when omitted, updates the board, and appends a fast-path log entry.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: false, flag: "--task-id" }, { name: "task_title", required: true }, { name: "task_description", required: true }, { name: "owner", required: false }] },
  "create-defer-task": { purpose: "Create a defer-task decision for out-of-scope work.", output: "Records defer rationale, target, and optional risk.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "defer_id", required: true }, { name: "reason", required: true }, { name: "deferred_work", required: true }, { name: "target", required: true }, { name: "risk", required: false }] },
  "create-spec": { purpose: "Create a new implementation-ready spec.", output: "Creates spec files/sections and initializes project-management context, auto-generating the spec ID when omitted.", params: [{ name: "spec_id", required: false, flag: "--spec-id" }, { name: "spec_title", required: true }, { name: "spec_description", required: true }, { name: "owner", required: false }] },
  "create-spec-tasks": { purpose: "Compatibility wrapper for older spec+task scaffold flows.", output: "Creates the spec document and reminds callers that tasks are now one file per task.", params: [{ name: "spec_id", required: false, flag: "--spec-id" }, { name: "spec_title", required: true }, { name: "spec_description", required: true }, { name: "owner", required: false }] },
  "create-task": { purpose: "Add a new task under a spec.", output: "Adds task section and board row with initial metadata, auto-generating the task ID when omitted.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: false, flag: "--task-id" }, { name: "task_title", required: true }, { name: "task_description", required: true }, { name: "owner", required: false }, { name: "phase", required: false }] },
  "create-task-branch": { purpose: "Create a git branch for a task using naming convention.", output: "Creates/switches to task branch and records branch metadata.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "base_branch", required: false }, { name: "branch_name", required: false }] },
  "create-task-comment": { purpose: "Add a comment to a task communication thread.", output: "Appends structured comment with author/type.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "author", required: true }, { name: "comment", required: true }, { name: "comment_type", required: false }] },
  "init-project": { purpose: "Initialize project docs via init-project-docs wrapper.", output: "Runs wrapper and returns command output.", params: [] },
  "list-tasks": { purpose: "List tasks with optional filters.", output: "Prints matching tasks from board/task data.", params: [{ name: "status", required: false, flag: "--status" }, { name: "spec_id", required: false, flag: "--spec" }, { name: "name", required: false, flag: "--name" }] },
  "next-id": { purpose: "Generate next sequential ID for a prefix.", output: "Returns the next identifier string.", params: [{ name: "prefix", required: true }] },
  "open-review-loop": { purpose: "Open a review-loop record for a task PR.", output: "Updates loop metadata and logs review start.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "branch", required: true }, { name: "pr_url", required: true }, { name: "loop", required: false }] },
  "promote-fast-task": { purpose: "Promote a fast-path task into the normal spec workflow.", output: "Creates the target spec and marks the fast-path task deferred/promoted.", params: [{ name: "fast_spec_id", required: true }, { name: "fast_task_id", required: true }, { name: "target_spec_id", required: true }, { name: "target_spec_title", required: true }, { name: "target_spec_description", required: true }, { name: "owner", required: false }] },
  "read-role-memory": { purpose: "Read durable role memory entries.", output: "Prints role memory for selected role.", params: [{ name: "role", required: true, enum: ["developer", "qa", "architect"] }] },
  "read-task-comments": { purpose: "Read top-level comments for a task.", output: "Prints task comments from communication artifacts.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }] },
  "read-task-replies": { purpose: "Read replies for a comment thread.", output: "Prints nested replies for the given ID.", params: [{ name: "spec_id", required: true }, { name: "comment_or_reply_id", required: true }] },
  "record-loop-breaker": { purpose: "Record architect loop-breaker decision.", output: "Appends decision and optional status update.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "loop", required: true }, { name: "issue", required: true }, { name: "architect_decision", required: true }, { name: "next_status", required: false }] },
  "record-merge": { purpose: "Record branch merge completion.", output: "Stores merge commit and evidence for task.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "merge_commit", required: true }, { name: "evidence", required: true }] },
  "record-pr": { purpose: "Record PR metadata for a task branch.", output: "Updates PR fields and review-loop context.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "branch", required: true }, { name: "pr_url", required: true }, { name: "loop", required: false }] },
  "record-pr-comment": { purpose: "Record PR review comment metadata.", output: "Appends PR comment link/summary for traceability.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "author", required: true }, { name: "pr_comment_url", required: true }, { name: "summary", required: true }, { name: "comment_type", required: false }] },
  "record-fast-result": { purpose: "Record a fast-path validation result for a small fix or experiment.", output: "Updates task status for the fast-path outcome and stores evidence in the communication log.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "result", required: true }, { name: "evidence", required: true }, { name: "next_step", required: false }] },
  "record-qa-smoke": { purpose: "Record QA smoke verification result.", output: "Writes pass/fail result and evidence.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "result", required: true }, { name: "evidence", required: true }] },
  "record-release": { purpose: "Record release evidence for task/spec.", output: "Adds release entry with version and evidence.", params: [{ name: "release_id", required: true }, { name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "version", required: true }, { name: "evidence", required: true }] },
  "record-review-result": { purpose: "Record architect-reviewer result for loop.", output: "Stores review result, loop value, and summary.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "result", required: true }, { name: "loop", required: true }, { name: "summary", required: true }] },
  "reply-task-comment": { purpose: "Reply to an existing task comment.", output: "Adds reply and optional status marker.", params: [{ name: "spec_id", required: true }, { name: "comment_id", required: true }, { name: "author", required: true }, { name: "reply", required: true }, { name: "status", required: false }] },
  "resolve-blocker": { purpose: "Resolve a previously recorded blocker.", output: "Marks blocker resolved and can advance task status.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "blocker_id", required: true }, { name: "resolution", required: true }, { name: "next_status", required: false }] },
  "setup-doc-structure": { purpose: "Create standard docs folder skeleton.", output: "Creates docs/proj-management directories and seed files.", params: [{ name: "folder", required: true }] },
  "start-fast-path": { purpose: "Start a lightweight fast-path spec and first task for a small fix or experiment.", output: "Creates fast-path spec/task docs, a board row, and a communication log entry, auto-generating IDs when omitted.", params: [{ name: "spec_id", required: false, flag: "--spec-id" }, { name: "task_id", required: false, flag: "--task-id" }, { name: "task_title", required: true }, { name: "task_description", required: true }, { name: "owner", required: false }] },
  "update-document-index": { purpose: "Insert or update a document index entry.", output: "Mutates DOCUMENT_INDEX metadata row.", params: [{ name: "id", required: true }, { name: "title", required: true }, { name: "doc_type", required: true }, { name: "domain", required: true }, { name: "status", required: true }, { name: "doc_path", required: true }, { name: "summary", required: true }, { name: "keywords", required: true }, { name: "applies_to", required: true }, { name: "related_docs", required: false }, { name: "supersedes", required: false }] },
  "update-role-memory": { purpose: "Append role memory note after task/review loop.", output: "Writes structured role-memory entry.", params: [{ name: "role", required: true, enum: ["developer", "qa", "architect"] }, { name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "entry", required: true }] },
  "update-task-owner": { purpose: "Change task owner assignment.", output: "Updates owner in task, board, and logs.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "owner", required: true }] },
  "update-task-status": { purpose: "Change task status and review metadata.", output: "Updates status plus optional branch, PR, loop, blocker fields.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "status", required: true }, { name: "branch", required: false }, { name: "pr_url", required: false }, { name: "loop", required: false }, { name: "blocker", required: false }] },
  "validate-project-state": { purpose: "Validate board/spec/task consistency.", output: "Prints failures and exits non-zero, or prints project valid message.", params: [] },
}

function toolNameForScript(scriptName) {
  return scriptName.replace(/-/g, "_")
}

function scriptForToolName(toolName) {
  const scriptName = toolName.replace(/_/g, "-")
  return scriptNames.includes(scriptName) ? scriptName : null
}

function argsFromNamedParams(scriptName, named) {
  const details = COMMAND_DETAILS[scriptName]
  const params = details?.params ?? []
  const missing = params.filter((p) => p.required && (named[p.name] === undefined || named[p.name] === null || named[p.name] === ""))
  if (missing.length) throw new Error(`Missing required args for ${scriptName}: ${missing.map((p) => p.name).join(", ")}`)

  const out = []
  for (const p of params) {
    const value = named[p.name]
    if (value === undefined || value === null || value === "") continue
    if (p.flag) out.push(p.flag)
    out.push(String(value))
  }
  return out
}

function runScript({ scriptName, args = [], docRoot = "docs", worktree = process.cwd() }) {
  const scriptPath = path.join(scriptsDir, `${scriptName}.sh`)
  return new Promise((resolve, reject) => {
    const proc = spawn("bash", [scriptPath, ...args], {
      cwd: worktree,
      env: { ...process.env, DOC_ROOT: docRoot },
    })

    let stdout = ""
    let stderr = ""
    proc.stdout.on("data", (chunk) => { stdout += String(chunk) })
    proc.stderr.on("data", (chunk) => { stderr += String(chunk) })
    proc.on("error", reject)
    proc.on("close", (code) => {
      const output = [stdout.trim(), stderr.trim()].filter(Boolean).join("\n")
      if (code !== 0) {
        reject(new Error(output || `${scriptName} failed with exit code ${code ?? 1}`))
        return
      }
      resolve(output || `Completed ${scriptName}`)
    })
  })
}

function inputSchemaForScript(scriptName) {
  const details = COMMAND_DETAILS[scriptName]
  const params = details?.params ?? []
  const properties = {
    doc_root: {
      type: "string",
      default: "docs",
      description: "DOC_ROOT environment variable for OPC scripts",
    },
    worktree: {
      type: "string",
      description: "Working directory for script execution",
    },
  }
  const required = []

  for (const p of params) {
    properties[p.name] = { type: "string", description: `Script argument: ${p.name}` }
    if (p.enum) properties[p.name].enum = p.enum
    if (p.required) required.push(p.name)
  }

  return {
    type: "object",
    properties,
    required,
    additionalProperties: false,
  }
}

function toolDefForScript(scriptName) {
  const details = COMMAND_DETAILS[scriptName] ?? {
    purpose: "Execute an OPC workflow command.",
    output: "Runs script and returns stdout/stderr text.",
  }
  return {
    name: toolNameForScript(scriptName),
    description: `${details.purpose} Output: ${details.output}`,
    inputSchema: inputSchemaForScript(scriptName),
  }
}

const serverTools = [
  {
    name: "run_command",
    description: "Generic runner for OPC scripts. Prefer specific script tools for typed arguments.",
    inputSchema: {
      type: "object",
      properties: {
        command: { type: "string", enum: scriptNames, description: "Script name without .sh" },
        args: { type: "array", items: { type: "string" }, default: [] },
        doc_root: { type: "string", default: "docs" },
        worktree: { type: "string", description: "Working directory for script execution" },
      },
      required: ["command"],
      additionalProperties: false,
    },
  },
  ...scriptNames.map(toolDefForScript),
]

const server = new Server(
  { name: "opc-tools", version: "1.0.0" },
  { capabilities: { tools: {}, prompts: {}, resources: {} } },
)

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: serverTools }
})

server.setRequestHandler(ListPromptsRequestSchema, async () => {
  return { prompts: [] }
})

server.setRequestHandler(ListResourcesRequestSchema, async () => {
  return { resources: [] }
})

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const name = request.params.name
  const args = request.params.arguments ?? {}

  try {
    if (name === "run_command") {
      const command = args.command
      if (typeof command !== "string" || !scriptNames.includes(command)) {
        return { content: [{ type: "text", text: `Unknown command: ${String(command)}` }], isError: true }
      }
      const output = await runScript({
        scriptName: command,
        args: Array.isArray(args.args) ? args.args.map(String) : [],
        docRoot: typeof args.doc_root === "string" ? args.doc_root : "docs",
        worktree: typeof args.worktree === "string" ? args.worktree : process.cwd(),
      })
      return { content: [{ type: "text", text: output }] }
    }

    const scriptName = scriptForToolName(name)
    if (!scriptName) {
      return { content: [{ type: "text", text: `Unknown tool: ${name}` }], isError: true }
    }

    const positionalArgs = argsFromNamedParams(scriptName, args)
    const output = await runScript({
      scriptName,
      args: positionalArgs,
      docRoot: typeof args.doc_root === "string" ? args.doc_root : "docs",
      worktree: typeof args.worktree === "string" ? args.worktree : process.cwd(),
    })
    return { content: [{ type: "text", text: output }] }
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error)
    return { content: [{ type: "text", text: message }], isError: true }
  }
})

const transport = new StdioServerTransport()
await server.connect(transport)
