import { tool } from "./opc_tool-shim"

export default tool({
  description: "Run scripts/record-release.sh",
  args: { args: tool.schema.array(tool.schema.string()).default([]), doc_root: tool.schema.string().default("docs") },
  async execute(args, context) {
    const local = `${context.worktree}/scripts/record-release.sh`
    const fallback = `${import.meta.dir}/../../scripts/record-release.sh`
    const script = (await Bun.file(local).exists()) ? local : fallback
    const proc = Bun.spawn(["bash", script, ...args.args], { cwd: context.worktree, env: { ...process.env, DOC_ROOT: args.doc_root }, stdout: "pipe", stderr: "pipe" })
    const [stdout, stderr, code] = await Promise.all([new Response(proc.stdout).text(), new Response(proc.stderr).text(), proc.exited])
    const out = [stdout.trim(), stderr.trim()].filter(Boolean).join("\n")
    if (code !== 0) throw new Error(out || "record-release failed")
    return out || "Completed record-release"
  },
})
