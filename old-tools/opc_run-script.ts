import { access } from "node:fs/promises"
import { constants } from "node:fs"
import { spawn } from "node:child_process"

async function fileExists(path: string): Promise<boolean> {
  try {
    await access(path, constants.F_OK)
    return true
  } catch {
    return false
  }
}

export async function runScript(input: {
  context: { worktree: string }
  scriptName: string
  args: string[]
  docRoot: string
  failureLabel: string
  successLabel: string
}): Promise<string> {
  const local = `${input.context.worktree}/scripts/${input.scriptName}.sh`
  const fallback = `${import.meta.dir}/../../scripts/${input.scriptName}.sh`
  const script = (await fileExists(local)) ? local : fallback

  const proc = spawn("bash", [script, ...input.args], {
    cwd: input.context.worktree,
    env: { ...process.env, DOC_ROOT: input.docRoot },
  })

  let stdout = ""
  let stderr = ""

  proc.stdout.on("data", (chunk) => {
    stdout += String(chunk)
  })

  proc.stderr.on("data", (chunk) => {
    stderr += String(chunk)
  })

  const code = await new Promise<number>((resolve, reject) => {
    proc.on("error", reject)
    proc.on("close", (exitCode) => resolve(exitCode ?? 1))
  })

  const out = [stdout.trim(), stderr.trim()].filter(Boolean).join("\n")
  if (code !== 0) throw new Error(out || `${input.failureLabel} failed`)
  return out || `Completed ${input.successLabel}`
}
