export type HealthCheckArgs = {
  foo: string
}

export type HealthCheckContext = {
  directory: string
  worktree: string
}

export async function runHealthCheck(args: HealthCheckArgs, context: HealthCheckContext): Promise<string> {
  const { directory, worktree } = context
  return `Hello ${args.foo} from ${directory} (worktree: ${worktree})`
}
