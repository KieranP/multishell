extension OpenCodePlugin {
  /// The service runs every tab's sessions in the environment of the tab that
  /// started it, so its helper is handed none of the tab's variables.
  private static let tabVariables = [
    SessionEnvironment.sessionVariable, SessionEnvironment.worktreeVariable,
    SessionEnvironment.socketVariable, SessionEnvironment.appPIDVariable,
  ].map { "\"\($0)\"" }.joined(separator: ", ")

  /// The helper calls the reports make.
  static let reporter = """
    // The background service runs every tab's sessions; see Docs/design/agents.md.
    const runsUnderTheService = process.argv.includes("--service")

    // Under the service the helper finds the app's socket itself and marks the
    // worktree by its directory.
    const helperEnvironment = () => {
      if (!runsUnderTheService) return undefined
      const env = { ...process.env }
      for (const name of [\(tabVariables)]) delete env[name]
      return env
    }

    // One helper at a time, each once the last has exited: started together
    // they land in either order; see Docs/design/agents.md.
    const reporter = () => {
      const env = helperEnvironment()
      const pending = []
      let sending = false
      const isQuietWorking = (args) => {
        if (args[1] !== "running" || args.includes("--new-turn")) return false
        const phase = args.indexOf("--subagent-phase")
        return phase < 0 || args[phase + 1] === "working"
      }
      const pump = () => {
        const args = pending.shift()
        sending = args !== undefined
        if (!sending) return
        let finished = false
        const next = () => {
          if (finished) return
          finished = true
          clearTimeout(timer)
          pump()
        }
        // A helper that never exits holds the rest no longer than this.
        const timer = setTimeout(next, 2000)
        if (timer.unref) timer.unref()
        try {
          const options = { stdio: "ignore", detached: true }
          if (env) options.env = env
          const child = spawn(helper, args, options)
          child.on("error", next)
          child.on("exit", next)
          child.unref()
        } catch { next() }
      }
      return (args) => {
        // One already queued, with only quiet Workings behind it, says what this would.
        if (isQuietWorking(args)) {
          const key = args.join("\0")
          for (let index = pending.length - 1; index >= 0 && isQuietWorking(pending[index]); index -= 1) {
            if (pending[index].join("\0") === key) return
          }
        }
        pending.push(args)
        if (!sending) pump()
      }
    }

    """
}
