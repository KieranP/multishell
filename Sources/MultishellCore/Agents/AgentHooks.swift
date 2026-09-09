import Foundation

/// The agents whose hooks Multishell knows how to write, and the one line
/// they all run.
///
/// Every event runs the helper, through the stable link under the state
/// directory, so a moved app bundle does not break the hooks. The command
/// exits 0 when the helper is missing, so an uninstalled Multishell costs
/// the agent nothing.
public enum AgentHooks {
  public static let subcommand = "agent-hook"
  /// What every hook line and every file of ours names, and how one is
  /// told from a hook of the user's own.
  public static let helperName = "multishell"
  /// What builds before this one wrote into a settings file. Those lines
  /// are still there after an update, and still work.
  public static let claudeSubcommand = "claude-hook"
  /// An agent kills a hook that runs longer than this. The helper connects,
  /// writes one line and exits; anything longer means the app is wedged.
  public static let timeoutSeconds = 5

  /// The helper as a hook should reference it: through `$HOME`, so a synced
  /// dotfile still resolves on another machine.
  public static var helperReference: String {
    let home = FileManager.default.homeDirectoryForCurrentUser.path
    let link = Paths.helperLink.path
    guard link.hasPrefix(home + "/") else { return link }
    return "$HOME" + link.dropFirst(home.count)
  }

  /// The shell outlives the helper and exits 0 whatever became of it. Not
  /// `exec`, which would make the helper's own end the hook's answer:
  /// Copilot denies a tool call on any non-zero exit from a `preToolUse`
  /// hook, and Claude blocks one on exit 2, so a helper killed by Gatekeeper
  /// or dying on a signal would stop the agent working rather than stop the
  /// dots moving. One extra short-lived shell is the price, and the pid the
  /// report carries is unaffected: `ProcessAncestry` walks past shells to
  /// find the agent either way.
  ///
  /// No variable assignment: the line must parse in fish as well as sh,
  /// since which shell an agent runs its hooks through is not ours to
  /// choose. `id` goes in unquoted because the only ids that reach here are
  /// the catalogue's own.
  public static func command(agent id: String, helper: String = helperReference) -> String {
    "[ -x \"\(helper)\" ] && \"\(helper)\" \(subcommand) --agent \(id); exit 0"
  }

  public static func isMultishellHook(_ command: String) -> Bool {
    command.contains(helperName)
      && (command.contains(subcommand) || command.contains(claudeSubcommand))
  }

  public static func integration(for id: String) -> AgentHookIntegration? {
    integrations.first { $0.id == id }
  }

  private static func home(_ path: String) -> URL {
    FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(path)
  }

  public static let integrations: [AgentHookIntegration] = [
    claude, codex, gemini, copilot, openCode,
  ]

  /// Claude Code: `~/.claude/settings.json`. `StopFailure` is the only
  /// event any of these agents has for a turn that ended badly.
  public static let claude = AgentHookIntegration(
    id: AgentCatalogue.claudeID,
    name: "Claude Code",
    file: home(".claude/settings.json"),
    displayPath: "~/.claude/settings.json",
    events: [
      AgentHookEvent("SessionStart", .idle),
      AgentHookEvent("UserPromptSubmit", .running),
      AgentHookEvent("PreToolUse", .running),
      AgentHookEvent("PostToolUse", .running),
      AgentHookEvent("Notification", .attention),
      AgentHookEvent("Stop", .done),
      AgentHookEvent("StopFailure", .error),
      AgentHookEvent("SessionEnd", .idle),
    ],
    format: .sharedSettings(millisecondTimeout: false))

  /// Codex: `~/.codex/hooks.json`, the JSON half of a file it also accepts
  /// as `[hooks]` in `config.toml`, which is not ours to rewrite. Its
  /// permission request is the nearest thing it has to a notification, but
  /// it fires before Codex decides whether anyone need answer, so it counts
  /// as waiting only in a mode that stops for the user. An interrupt ends
  /// the turn without a `Stop`, and clears Working rather than claiming the
  /// turn finished.
  public static let codex = AgentHookIntegration(
    id: "codex",
    name: "Codex",
    file: home(".codex/hooks.json"),
    displayPath: "~/.codex/hooks.json",
    events: [
      AgentHookEvent("SessionStart", .idle),
      AgentHookEvent("UserPromptSubmit", .running),
      AgentHookEvent("PreToolUse", .running),
      AgentHookEvent("PostToolUse", .running),
      AgentHookEvent("PermissionRequest", .attention, onlyWhenPrompting: true),
      AgentHookEvent("Stop", .done),
      AgentHookEvent("Interrupt", .idle),
      AgentHookEvent("SessionEnd", .idle),
    ],
    format: .sharedSettings(millisecondTimeout: false),
    trustNote:
      "Codex runs no hook it has not been told to trust: run /hooks in Codex once and trust this one."
  )

  /// Gemini CLI: `~/.gemini/settings.json`, whose events are named for what
  /// they come before and after, and whose timeout is in milliseconds.
  public static let gemini = AgentHookIntegration(
    id: "gemini",
    name: "Gemini CLI",
    file: home(".gemini/settings.json"),
    displayPath: "~/.gemini/settings.json",
    events: [
      AgentHookEvent("SessionStart", .idle),
      AgentHookEvent("BeforeAgent", .running),
      AgentHookEvent("BeforeTool", .running),
      AgentHookEvent("AfterTool", .running),
      AgentHookEvent("Notification", .attention),
      AgentHookEvent("AfterAgent", .done),
      AgentHookEvent("SessionEnd", .idle),
    ],
    format: .sharedSettings(millisecondTimeout: true))

  /// Copilot CLI reads every JSON file in `~/.copilot/hooks`, so ours is a
  /// file of its own. The event names are its Visual Studio Code spelling,
  /// the one whose payload names the event the way the other three do;
  /// `notification` has no such spelling but reports itself as one. It is
  /// also the one notification here that is not always about waiting — a
  /// background shell finishing raises it too — so it is asked for by type.
  public static let copilot = AgentHookIntegration(
    id: "copilot",
    name: "Copilot CLI",
    file: home(".copilot/hooks/multishell.json"),
    displayPath: "~/.copilot/hooks/multishell.json",
    events: [
      AgentHookEvent("SessionStart", .idle),
      AgentHookEvent("UserPromptSubmit", .running),
      AgentHookEvent("PreToolUse", .running),
      AgentHookEvent("PostToolUse", .running),
      AgentHookEvent(
        "notification", .attention, reported: "Notification",
        matcher: "permission_prompt|elicitation_dialog"),
      AgentHookEvent("Stop", .done),
      AgentHookEvent("SessionEnd", .idle),
    ],
    format: .ownHookFile)

  /// OpenCode has no hooks in its settings: what a session is doing shows
  /// only to a plugin, so it is given one.
  public static let openCode = AgentHookIntegration(
    id: "opencode",
    name: "OpenCode",
    file: home(".config/opencode/plugin/multishell.js"),
    displayPath: "~/.config/opencode/plugin/multishell.js",
    events: [],
    format: .plugin)
}
