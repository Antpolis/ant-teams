import { tool } from "./opc_tool-shim"
import { runScript } from "./opc_run-script"

export default tool({
  description: "Run scripts/create-spec.sh",
  args: { args: tool.schema.array(tool.schema.string()).default([]), doc_root: tool.schema.string().default("docs") },
  async execute(args, context) {
    return runScript({ context, scriptName: "create-spec", args: args.args, docRoot: args.doc_root, failureLabel: "create-spec", successLabel: "create-spec" })
  },
})
