import { tool } from "./opc_tool-shim"
import { runScript } from "./opc_run-script"

export default tool({
  description: "Run scripts/create-spec-tasks.sh",
  args: { args: tool.schema.array(tool.schema.string()).default([]), doc_root: tool.schema.string().default("docs") },
  async execute(args, context) {
    return runScript({ context, scriptName: "create-spec-tasks", args: args.args, docRoot: args.doc_root, failureLabel: "create-spec-tasks", successLabel: "create-spec-tasks" })
  },
})
