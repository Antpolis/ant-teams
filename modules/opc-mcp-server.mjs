#!/usr/bin/env node

import { readdirSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"
import { spawn } from "node:child_process"
import process from "node:process"

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)
const opcRoot = path.resolve(__dirname, "..")
const scriptsDir = path.join(opcRoot, "scripts")

function listOpcScripts() {
  const excluded = new Set(["init-company.sh", "init-project-docs.sh", "update-company.sh"])
  return readdirSync(scriptsDir)
    .filter((name) => name.endsWith(".sh") && name !== "pm-lib.sh" && !excluded.has(name))
    .map((name) => name.slice(0, -3))
    .sort()
}

const scriptNames = listOpcScripts()

const COMMAND_DETAILS = {
  "add-task-dependency": { purpose: "Add a dependency edge between two tasks in the same spec.", usage: "SPEC_ID TASK_ID DEPENDS_ON_TASK_ID", output: "Updates Dependencies in task section and board; appends a dependency update log entry.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "depends_on_task_id", required: true }] },
  "close-task": { purpose: "Close a task after approval and attach closure evidence.", usage: "SPEC_ID TASK_ID EVIDENCE", output: "Marks task closed/done in project state and records evidence in communication artifacts.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "evidence", required: true }] },
  "close-fast-task": { purpose: "Close a lightweight fast-path task after validation completes.", usage: "SPEC_ID TASK_ID EVIDENCE", output: "Marks a fast-path task done and records closure evidence.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "evidence", required: true }] },
  "create-blocker": { purpose: "Create a hard blocker record linked to a task.", usage: "SPEC_ID TASK_ID BLOCKER_ID TYPE DESCRIPTION NEEDS", output: "Writes blocker metadata, sets blocker linkage, and logs what is needed to unblock.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "blocker_id", required: true }, { name: "blocker_type", required: true }, { name: "description", required: true }, { name: "needs", required: true }] },
  "create-quick-task": { purpose: "Add a lightweight task under an existing fast-path spec.", usage: "SPEC_ID [--task-id TASK_ID] TASK_TITLE TASK_DESCRIPTION [OWNER]", output: "Creates a small fast-path task, auto-generating the task ID when omitted, updates the board, and appends a fast-path log entry.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: false, flag: "--task-id" }, { name: "task_title", required: true }, { name: "task_description", required: true }, { name: "owner", required: false }] },
  "create-defer-task": { purpose: "Create a defer-task decision for work moved out of current scope.", usage: "SPEC_ID TASK_ID DEFER_ID REASON DEFERRED_WORK TARGET [RISK]", output: "Records defer rationale, deferred scope, target destination, and optional risk note.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "defer_id", required: true }, { name: "reason", required: true }, { name: "deferred_work", required: true }, { name: "target", required: true }, { name: "risk", required: false }] },
  "create-spec": { purpose: "Create a new implementation-ready spec document for a request.", usage: "[--spec-id SPEC_ID] SPEC_TITLE SPEC_DESCRIPTION [OWNER]", output: "Creates spec files/sections and initializes project-management context for that spec, auto-generating the spec ID when omitted.", params: [{ name: "spec_id", required: false, flag: "--spec-id" }, { name: "spec_title", required: true }, { name: "spec_description", required: true }, { name: "owner", required: false }] },
  "create-spec-tasks": { purpose: "Compatibility wrapper for older spec+task scaffold flows.", usage: "[--spec-id SPEC_ID] SPEC_TITLE SPEC_DESCRIPTION [OWNER]", output: "Creates the spec document and reminds callers that tasks are now one file per task.", params: [{ name: "spec_id", required: false, flag: "--spec-id" }, { name: "spec_title", required: true }, { name: "spec_description", required: true }, { name: "owner", required: false }] },
  "create-task": { purpose: "Add a new task under a spec with ownership and phase metadata.", usage: "SPEC_ID [--task-id TASK_ID] TASK_TITLE TASK_DESCRIPTION [OWNER] [PHASE]", output: "Adds task section plus board row with initial status/dependencies fields, auto-generating the task ID when omitted.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: false, flag: "--task-id" }, { name: "task_title", required: true }, { name: "task_description", required: true }, { name: "owner", required: false }, { name: "phase", required: false }] },
  "create-task-branch": { purpose: "Create a git branch for a task using the workflow naming convention.", usage: "SPEC_ID TASK_ID [BASE_BRANCH] [BRANCH_NAME]", output: "Creates/switches to a branch with the correct task-based naming format and records branch metadata in project state.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "base_branch", required: false }, { name: "branch_name", required: false }] },
  "create-task-comment": { purpose: "Add a comment to a task communication thread.", usage: "SPEC_ID TASK_ID AUTHOR COMMENT [TYPE]", output: "Appends a structured comment entry with author/type to task communication log.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "author", required: true }, { name: "comment", required: true }, { name: "comment_type", required: false }] },
  "init-company": { purpose: "Install OPC workflow assets globally or into a project.", usage: "[--mode global|project] [--global-root PATH] [--project-dir PATH] [--docs-root docs]", output: "Copies config, tools, skills, scripts, and docs to selected installation target.", params: [{ name: "mode", required: false, flag: "--mode", enum: ["global", "project"] }, { name: "global_root", required: false, flag: "--global-root" }, { name: "project_dir", required: false, flag: "--project-dir" }, { name: "docs_root", required: false, flag: "--docs-root" }] },
  "init-project": { purpose: "Project docs initializer wrapper used by project installs.", usage: "Forwards all args to init-project-docs.sh", output: "Runs init-project-docs and returns that command's result.", params: [] },
  "init-project-docs": { purpose: "Initialize local project docs and workflow doc structure.", usage: "[--project-dir PATH] [--docs-root docs]", output: "Creates/copies docs baseline for project-level architecture and project-management files.", params: [{ name: "project_dir", required: false, flag: "--project-dir" }, { name: "docs_root", required: false, flag: "--docs-root" }] },
  "list-tasks": { purpose: "List tasks with optional filters by status/spec/name.", usage: "[--status STATUS] [--spec SPEC_ID] [--name TEXT]", output: "Prints matching tasks from board/task data as human-readable rows/table.", params: [{ name: "status", required: false, flag: "--status" }, { name: "spec_id", required: false, flag: "--spec" }, { name: "name", required: false, flag: "--name" }] },
  "next-id": { purpose: "Generate next sequential ID for a given prefix.", usage: "PREFIX", output: "Returns next identifier string based on existing docs entries.", params: [{ name: "prefix", required: true }] },
  "open-review-loop": { purpose: "Open a review loop record for a task and PR.", usage: "SPEC_ID TASK_ID BRANCH PR_URL [LOOP]", output: "Updates loop metadata and logs review-loop start with branch/PR linkage.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "branch", required: true }, { name: "pr_url", required: true }, { name: "loop", required: false }] },
  "promote-fast-task": { purpose: "Promote a fast-path task into the normal spec workflow.", usage: "FAST_SPEC_ID FAST_TASK_ID TARGET_SPEC_ID TARGET_SPEC_TITLE TARGET_SPEC_DESCRIPTION [OWNER]", output: "Creates the target spec and marks the fast-path task deferred/promoted.", params: [{ name: "fast_spec_id", required: true }, { name: "fast_task_id", required: true }, { name: "target_spec_id", required: true }, { name: "target_spec_title", required: true }, { name: "target_spec_description", required: true }, { name: "owner", required: false }] },
  "read-role-memory": { purpose: "Read durable role memory entries used across tasks/review loops.", usage: "developer|qa|architect", output: "Prints role memory content for the selected role.", params: [{ name: "role", required: true, enum: ["developer", "qa", "architect"] }] },
  "read-task-comments": { purpose: "Read top-level comments for a task.", usage: "SPEC_ID TASK_ID", output: "Prints task comment entries from communication log/comments sections.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }] },
  "read-task-replies": { purpose: "Read replies under a comment or reply thread ID.", usage: "SPEC_ID COMMENT_OR_REPLY_ID", output: "Prints nested replies associated with the provided comment/reply identifier.", params: [{ name: "spec_id", required: true }, { name: "comment_or_reply_id", required: true }] },
  "record-loop-breaker": { purpose: "Record architect loop-breaker decision at high review-loop count.", usage: "SPEC_ID TASK_ID LOOP ISSUE ARCHITECT_DECISION [NEXT_STATUS]", output: "Appends loop-breaker note and optionally changes task status.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "loop", required: true }, { name: "issue", required: true }, { name: "architect_decision", required: true }, { name: "next_status", required: false }] },
  "record-merge": { purpose: "Record branch merge completion for a task.", usage: "SPEC_ID TASK_ID MERGE_COMMIT EVIDENCE", output: "Stores merge commit hash and merge evidence in project-management records.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "merge_commit", required: true }, { name: "evidence", required: true }] },
  "record-pr": { purpose: "Record PR metadata for a task branch.", usage: "SPEC_ID TASK_ID BRANCH PR_URL [LOOP]", output: "Updates board/task PR fields and review-loop context.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "branch", required: true }, { name: "pr_url", required: true }, { name: "loop", required: false }] },
  "record-pr-comment": { purpose: "Record PR review comment metadata for traceability.", usage: "SPEC_ID TASK_ID AUTHOR PR_COMMENT_URL SUMMARY [TYPE]", output: "Appends PR comment reference and summary into communication artifacts.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "author", required: true }, { name: "pr_comment_url", required: true }, { name: "summary", required: true }, { name: "comment_type", required: false }] },
  "record-qa-smoke": { purpose: "Record QA smoke verification result for a task.", usage: "SPEC_ID TASK_ID RESULT EVIDENCE", output: "Writes pass/fail result and evidence into task and communication records.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "result", required: true }, { name: "evidence", required: true }] },
  "record-fast-result": { purpose: "Record a fast-path validation result for a small fix or experiment.", usage: "SPEC_ID TASK_ID RESULT EVIDENCE [NEXT_STEP]", output: "Updates task status for the fast-path outcome and stores evidence in the communication log.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "result", required: true }, { name: "evidence", required: true }, { name: "next_step", required: false }] },
  "record-release": { purpose: "Record release evidence tying spec/task to released version.", usage: "RELEASE_ID SPEC_ID TASK_ID VERSION EVIDENCE", output: "Adds row/entry to releases log with linked delivery evidence.", params: [{ name: "release_id", required: true }, { name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "version", required: true }, { name: "evidence", required: true }] },
  "record-review-result": { purpose: "Record architect-reviewer result for a review loop.", usage: "SPEC_ID TASK_ID RESULT LOOP SUMMARY", output: "Stores review outcome, loop index, and concise finding summary.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "result", required: true }, { name: "loop", required: true }, { name: "summary", required: true }] },
  "reply-task-comment": { purpose: "Reply to an existing task comment entry.", usage: "SPEC_ID COMMENT_ID AUTHOR REPLY [STATUS]", output: "Adds reply item and optional status marker under the comment thread.", params: [{ name: "spec_id", required: true }, { name: "comment_id", required: true }, { name: "author", required: true }, { name: "reply", required: true }, { name: "status", required: false }] },
  "resolve-blocker": { purpose: "Resolve a previously recorded blocker on a task.", usage: "SPEC_ID TASK_ID BLOCKER_ID RESOLUTION [NEXT_STATUS]", output: "Marks blocker resolved, writes resolution text, and can advance task status.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "blocker_id", required: true }, { name: "resolution", required: true }, { name: "next_status", required: false }] },
  "setup-doc-structure": { purpose: "Create standard docs folder skeleton for workflow use.", usage: "FOLDER", output: "Creates expected docs/proj-management directories and seed files.", params: [{ name: "folder", required: true }] },
  "start-fast-path": { purpose: "Start a lightweight fast-path spec and first task for a small fix or experiment.", usage: "[--spec-id FP_ID] [--task-id TASK_ID] TASK_TITLE TASK_DESCRIPTION [OWNER]", output: "Creates fast-path spec/task docs, a board row, and a communication log entry, auto-generating IDs when omitted.", params: [{ name: "spec_id", required: false, flag: "--spec-id" }, { name: "task_id", required: false, flag: "--task-id" }, { name: "task_title", required: true }, { name: "task_description", required: true }, { name: "owner", required: false }] },
  "update-company": { purpose: "Refresh installed OPC assets from this source repository.", usage: "[--mode global|project] [--global-root PATH] [--project-dir PATH] [--docs-root docs]", output: "Updates existing installation with latest scripts/config/docs.", params: [{ name: "mode", required: false, flag: "--mode", enum: ["global", "project"] }, { name: "global_root", required: false, flag: "--global-root" }, { name: "project_dir", required: false, flag: "--project-dir" }, { name: "docs_root", required: false, flag: "--docs-root" }] },
  "update-document-index": { purpose: "Insert or update a document entry in the index.", usage: "ID TITLE TYPE DOMAIN STATUS PATH SUMMARY KEYWORDS APPLIES_TO [RELATED_DOCS] [SUPERSEDES]", output: "Mutates DOCUMENT_INDEX.md to reflect authoritative document metadata.", params: [{ name: "id", required: true }, { name: "title", required: true }, { name: "doc_type", required: true }, { name: "domain", required: true }, { name: "status", required: true }, { name: "doc_path", required: true }, { name: "summary", required: true }, { name: "keywords", required: true }, { name: "applies_to", required: true }, { name: "related_docs", required: false }, { name: "supersedes", required: false }] },
  "update-role-memory": { purpose: "Append a durable memory note for a role after a task/review loop.", usage: "developer|qa|architect SPEC_ID TASK_ID ENTRY", output: "Writes structured role-memory entry keyed by role/spec/task.", params: [{ name: "role", required: true, enum: ["developer", "qa", "architect"] }, { name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "entry", required: true }] },
  "update-task-owner": { purpose: "Change task owner assignment.", usage: "SPEC_ID TASK_ID OWNER", output: "Updates owner in task section and board, and logs ownership change.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "owner", required: true }] },
  "update-task-status": { purpose: "Change task status and related review metadata fields.", usage: "SPEC_ID TASK_ID STATUS [BRANCH] [PR] [LOOP] [BLOCKER]", output: "Updates task/board status with optional branch, PR URL, loop count, blocker state.", params: [{ name: "spec_id", required: true }, { name: "task_id", required: true }, { name: "status", required: true }, { name: "branch", required: false }, { name: "pr_url", required: false }, { name: "loop", required: false }, { name: "blocker", required: false }] },
  "validate-project-state": { purpose: "Validate consistency across board, specs, tasks, and loop values.", usage: "No positional args", output: "Prints validation failures with reasons; exits non-zero on errors, else prints 'Project state valid'.", params: [] },
}

function argsFromNamedParams(scriptName, named) {
  const details = COMMAND_DETAILS[scriptName]
  const params = details?.params ?? []

  if (params.length === 0) return []

  const missing = params.filter((p) => p.required && (named[p.name] === undefined || named[p.name] === null || named[p.name] === ""))
  if (missing.length > 0) {
    throw new Error(`Missing required args for ${scriptName}: ${missing.map((p) => p.name).join(", ")}`)
  }

  const out = []
  for (const p of params) {
    if (named[p.name] === undefined || named[p.name] === null || named[p.name] === "") {
      continue
    }
    if (p.flag) out.push(p.flag)
    out.push(String(named[p.name]))
  }
  return out
}

function inputSchemaForScript(scriptName) {
  const details = COMMAND_DETAILS[scriptName]
  const params = details?.params ?? []
  const properties = {
    doc_root: {
      type: "string",
      default: "docs",
      description: "DOC_ROOT environment variable used by OPC scripts",
    },
    worktree: {
      type: "string",
      description: "Working directory for command execution",
    },
  }
  const required = []

  for (const p of params) {
    properties[p.name] = {
      type: "string",
      description: `Positional arg: ${p.name}`,
    }
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

function toolNameForScript(scriptName) {
  return `opc_${scriptName.replace(/-/g, "_")}`
}

function scriptForToolName(toolName) {
  const prefix = "opc_"
  if (!toolName.startsWith(prefix)) return null
  const scriptName = toolName.slice(prefix.length).replace(/_/g, "-")
  return scriptNames.includes(scriptName) ? scriptName : null
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

    proc.stdout.on("data", (chunk) => {
      stdout += String(chunk)
    })

    proc.stderr.on("data", (chunk) => {
      stderr += String(chunk)
    })

    proc.on("error", (error) => reject(error))
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

function toolDefForScript(scriptName) {
  const details = COMMAND_DETAILS[scriptName] ?? {
    purpose: "Execute an OPC workflow command.",
    usage: "See script help via --help",
    output: "Runs script and returns stdout/stderr text.",
  }

  return {
    name: toolNameForScript(scriptName),
    description: `${details.purpose} Args: ${details.usage}. Output: ${details.output}`,
    inputSchema: inputSchemaForScript(scriptName),
  }
}

const serverTools = [
  {
    name: "opc_run_command",
    description: "Run any OPC script from scripts/*.sh using command + args. Use tools/list to inspect each command's args order and output semantics.",
    inputSchema: {
      type: "object",
      properties: {
        command: {
          type: "string",
          enum: scriptNames,
          description: "Script name without .sh",
        },
        args: {
          type: "array",
          items: { type: "string" },
          default: [],
        },
        doc_root: {
          type: "string",
          default: "docs",
        },
        worktree: {
          type: "string",
          description: "Working directory for command execution",
        },
      },
      required: ["command"],
      additionalProperties: false,
    },
  },
  ...scriptNames.map(toolDefForScript),
]

function writeMessage(message) {
  const serialized = JSON.stringify(message)
  const payload = `Content-Length: ${Buffer.byteLength(serialized, "utf8")}\r\n\r\n${serialized}`
  process.stdout.write(payload)
}

function response(id, result) {
  return { jsonrpc: "2.0", id, result }
}

function errorResponse(id, code, message) {
  return { jsonrpc: "2.0", id, error: { code, message } }
}

async function handleRequest(msg) {
  const { id, method, params } = msg

  if (method === "initialize") {
    return response(id, {
      protocolVersion: "2024-11-05",
      serverInfo: {
        name: "opc-tools",
        version: "0.1.0",
      },
      capabilities: {
        tools: {},
        prompts: {},
        resources: {},
      },
    })
  }

  if (method === "notifications/initialized") {
    return null
  }

  if (method === "tools/list") {
    return response(id, { tools: serverTools })
  }

  if (method === "prompts/list") {
    return response(id, { prompts: [] })
  }

  if (method === "resources/list") {
    return response(id, { resources: [] })
  }

  if (method === "tools/call") {
    const name = params?.name
    const args = params?.arguments ?? {}

    try {
      if (name === "opc_run_command") {
        const command = args.command
        if (!scriptNames.includes(command)) {
          return errorResponse(id, -32602, `Unknown command: ${command}`)
        }
        const output = await runScript({
          scriptName: command,
          args: Array.isArray(args.args) ? args.args : [],
          docRoot: typeof args.doc_root === "string" ? args.doc_root : "docs",
          worktree: typeof args.worktree === "string" ? args.worktree : process.cwd(),
        })
        return response(id, { content: [{ type: "text", text: output }] })
      }

      const scriptName = scriptForToolName(name)
      if (!scriptName) {
        return errorResponse(id, -32601, `Unknown tool: ${name}`)
      }

      const positionalArgs = argsFromNamedParams(scriptName, args)
      const output = await runScript({
        scriptName,
        args: positionalArgs,
        docRoot: typeof args.doc_root === "string" ? args.doc_root : "docs",
        worktree: typeof args.worktree === "string" ? args.worktree : process.cwd(),
      })

      return response(id, { content: [{ type: "text", text: output }] })
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      return response(id, {
        isError: true,
        content: [{ type: "text", text: message }],
      })
    }
  }

  return errorResponse(id, -32601, `Method not found: ${method}`)
}

let buffer = Buffer.alloc(0)

process.stdin.on("data", async (chunk) => {
  buffer = Buffer.concat([buffer, chunk])

  while (true) {
    const separator = buffer.indexOf("\r\n\r\n")
    if (separator === -1) break

    const header = buffer.slice(0, separator).toString("utf8")
    const match = header.match(/Content-Length:\s*(\d+)/i)
    if (!match) {
      buffer = Buffer.alloc(0)
      return
    }

    const contentLength = Number(match[1])
    const totalLength = separator + 4 + contentLength
    if (buffer.length < totalLength) break

    const body = buffer.slice(separator + 4, totalLength).toString("utf8")
    buffer = buffer.slice(totalLength)

    let msg
    try {
      msg = JSON.parse(body)
    } catch {
      continue
    }

    const out = await handleRequest(msg)
    if (out && msg.id !== undefined) {
      writeMessage(out)
    }
  }
})
