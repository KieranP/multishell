import Foundation

/// The plugin OpenCode is given, since it runs no hook command. Here and not
/// in `Resources`, which the helper cannot reach; see docs/design/agents.md.
public enum OpenCodePlugin {
  public static func source(helper: String = AgentHooks.helperReference) -> String {
    """
    // Written by Multishell so its tabs can show what a session is doing.
    // Remove it from Settings > Agents, or delete this file.
    import { spawn } from "node:child_process"
    import { homedir } from "node:os"

    const helper = \(javaScriptPath(helper))

    // What is being asked for, from v2's PermissionRequest. Its predecessor
    // carried a `title`, which this read for a while and never found.
    const asked = (properties) => {
      if (!properties) return undefined
      const patterns = properties.patterns
      const detail = Array.isArray(patterns) ? patterns.join(" ") : patterns
      return [properties.tool, detail].filter(Boolean).join(" ") || undefined
    }

    export const MultishellPlugin = async ({ directory, worktree }) => {
      const cwd = worktree || directory
      const report = (state, message) => {
        const args = ["state", state, "--agent", "opencode"]
        if (cwd) args.push("--cwd", cwd)
        if (message) args.push("--message", message)
        try {
          const child = spawn(helper, args, { stdio: "ignore", detached: true })
          child.on("error", () => {})
          child.unref()
        } catch {}
      }
      return {
        "chat.message": async () => report("running"),
        "tool.execute.before": async () => report("running"),
        // Not permission.ask: uncalled since the 1.1 permissions rewrite,
        // and it would report a prompt the bus already reports.
        event: async ({ event }) => {
          if (event.type === "session.idle") report("done")
          else if (event.type === "session.error") report("error")
          else if (event.type === "permission.asked") report("attention", asked(event.properties))
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
