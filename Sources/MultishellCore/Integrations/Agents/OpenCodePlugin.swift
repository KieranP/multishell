import Foundation

/// The plugin OpenCode is given, since it runs no hook command. Here and not
/// in `Resources`, which the helper cannot reach; see Docs/design/agents.md.
enum OpenCodePlugin {
  static func source(helper: String = AgentHooks.helperReference) -> String {
    """
    // Written by Multishell so its tabs can show what a session is doing.
    // Remove it from Settings > Agents, or delete this file.
    import { spawn } from "node:child_process"
    import { homedir } from "node:os"

    const helper = \(javaScriptPath(helper))

    // What is being asked for, from v2's PermissionRequest: its `tool` is the
    // call's ids, and the permission names the tool.
    const asked = (properties) => {
      if (!properties) return undefined
      const patterns = properties.patterns
      const detail = Array.isArray(patterns) ? patterns.join(" ") : patterns
      const name = typeof properties.permission === "string" ? properties.permission : undefined
      return [name, detail].filter(Boolean).join(" ") || undefined
    }

    export const MultishellPlugin = async ({ directory, worktree }) => {
      const cwd = worktree || directory
      // A subagent is a child session, so its events are told by its id.
      // What each runs as is kept from its creation.
      const workers = new Map()
      const report = (state, message, worker, newTurn) => {
        const args = ["state", state, "--agent", "opencode"]
        if (cwd) args.push("--cwd", cwd)
        if (message) args.push("--message", message)
        if (newTurn) args.push("--new-turn", "true")
        if (worker) {
          args.push("--subagent", worker.id, "--subagent-phase", worker.phase)
          if (worker.type) args.push("--subagent-type", worker.type)
        }
        try {
          const child = spawn(helper, args, { stdio: "ignore", detached: true })
          child.on("error", () => {})
          child.unref()
        } catch {}
      }
      const worker = (id, phase) => {
        const entry = workers.get(id)
        return entry && !entry.done ? { id, phase, type: entry.type } : undefined
      }
      // A child's id is kept past its end, so a late event of its own is not
      // read as the parent's; only a busy status puts it back on the roster.
      const ended = []
      const finish = (id) => {
        const entry = workers.get(id)
        if (!entry || entry.done) return
        entry.done = true
        // One place per child, so a child going busy and idle over and over
        // neither grows the list nor pushes other children's ids out of it.
        const seen = ended.indexOf(id)
        if (seen >= 0) ended.splice(seen, 1)
        ended.push(id)
        while (ended.length > 64) {
          const old = ended.shift()
          const value = workers.get(old)
          // Busy again since it ended: it stays in the map, and it is off the
          // list until its next end puts it back.
          if (value && value.done) workers.delete(old)
        }
      }
      const under = (id, newTurn) => {
        const child = worker(id, "working")
        if (child) report("running", undefined, child)
        else if (!workers.has(id)) report("running", undefined, undefined, newTurn)
      }
      return {
        // A prompt in the parent starts a turn; one in a child is its work.
        // With no session in either argument, no new turn: that empties the roster.
        "chat.message": async (input, output) => {
          const message = output && output.message
          const id = (input && input.sessionID) || (message && message.sessionID)
          if (id) under(id, true)
          else report("running")
        },
        "tool.execute.before": async (input) => under(input && input.sessionID, false),
        // Not permission.ask: uncalled since the 1.1 permissions rewrite,
        // and it would report a prompt the bus already reports.
        event: async ({ event }) => {
          const properties = event.properties || {}
          const info = properties.info
          // session.idle is deprecated in favour of session.status, so an end
          // is taken from either, in the parent as in a child.
          const status = event.type === "session.status" && properties.status && properties.status.type
          const idle = event.type === "session.idle" || status === "idle"
          if (event.type === "session.created" && info && info.parentID) {
            workers.set(info.id, { type: info.agent })
            report("running", undefined, { id: info.id, phase: "started", type: info.agent })
          } else if (workers.has(properties.sessionID)) {
            const id = properties.sessionID
            if (idle || event.type === "session.error") {
              const child = worker(id, "ended")
              if (child) {
                report("running", undefined, child)
                finish(id)
              }
              return
            }
            if (status === "busy") workers.get(id).done = false
            const child = worker(id, "working")
            if (!child) return
            if (status === "busy") report("running", undefined, child)
            // A child's permission is a prompt of that worker's.
            else if (event.type === "permission.asked") report("attention", asked(properties), child)
            else if (event.type === "permission.replied") report("running", undefined, child)
          } else if (idle) report("done")
          else if (event.type === "session.error") report("error")
          else if (event.type === "permission.asked") report("attention", asked(properties))
          else if (event.type === "permission.replied") report("running")
        },
      }
    }

    """
  }

  /// `$HOME` is the shell's, not JavaScript's, so the plugin asks the
  /// runtime for the home directory and keeps the rest of the path.
  private static func javaScriptPath(_ helper: String) -> String {
    let prefix = "$HOME"
    guard helper.hasPrefix(prefix) else { return quoted(helper) }
    return "homedir() + " + quoted(String(helper.dropFirst(prefix.count)))
  }

  private static func quoted(_ value: String) -> String {
    var escaped = ""
    for character in value.unicodeScalars {
      switch character {
      case "\\", "\"": escaped += "\\" + String(character)
      case "\n": escaped += "\\n"
      default: escaped.unicodeScalars.append(character)
      }
    }
    return "\"\(escaped)\""
  }
}
