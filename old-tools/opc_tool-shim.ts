type SchemaBuilder = {
  string: () => { default: (value: string) => string }
  array: (_inner: unknown) => { default: (value: string[]) => string[] }
}

type ToolFactory = {
  <T>(definition: T): T
  schema: SchemaBuilder
}

const schema: SchemaBuilder = {
  string: () => ({ default: (value: string) => value }),
  array: () => ({ default: (value: string[]) => value }),
}

export const tool: ToolFactory = Object.assign(
  <T>(definition: T): T => definition,
  { schema },
)
