import { tool } from "./opc_tool-shim"

export default tool({
  description: "Describe scripts/pm-lib.sh helper usage",
  args: {},
  async execute() {
    return "pm-lib.sh is a shared helper library and is not a runnable workflow command."
  },
})
