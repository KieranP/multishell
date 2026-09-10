import Foundation

/// The plugin OpenCode is given, since it runs no hook command.
///
/// A plugin is a file of ours in OpenCode's plugin directory, loaded into
/// the process that runs the session. It calls the helper the way any
/// script would, `multishell state …`, so nothing in the app knows about
/// OpenCode beyond this file: no reading of the payload, no event names to
/// keep up with. It spawns and forgets, and swallows every error, because
/// the process it is running in is the user's agent.
///
/// It is the one integration that hears the answer to a permission as well
/// as the question: `permission.replied` arrives whether the user allowed
/// or denied, so an OpenCode pane leaves Waiting the moment the user
/// answers. The others have no such event, and sit amber until the next
/// tool call. Both come off the event bus, which is where a permission is
/// actually announced.
///
/// Written here rather than as a `Resources` script, which is how the shell
/// integration ships its own: the helper writes this file, and the helper
/// is installed in the bundle's `Contents/Helpers`, from where the resource
/// bundle in `Contents/Resources` is not reachable.
public enum OpenCodePlugin {
  public static func source(helper: String = AgentHooks.helperReference) -> String {
    """
    // Written by Multishell so its tabs can show what an OpenCode session is
    // doing. Remove it from Settings > Agents, or delete this file; nothing
    // else reads it.
    import { spawn } from "node:child_process"
    import { homedir } from "node:os"

    const helper = \(javaScriptPath(helper))

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
        // Not the permission.ask hook: it is in the plugin types but
        // nothing has called it since the 1.1 permissions rewrite, and the
        // day it is called again it would report the same prompt the bus
        // already reports.
        event: async ({ event }) => {
          if (event.type === "session.idle") report("done")
          else if (event.type === "session.error") report("error")
          else if (event.type === "permission.asked") report("attention", event.properties?.title)
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
