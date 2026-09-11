import Foundation

/// The agents whose hooks Multishell knows how to write, and the one line they
/// all run. See docs/design/agents.md for why each event was chosen.
public enum AgentHooks {
  public static let subcommand = "agent-hook"
  /// What every hook line and every file of ours names, and how one is told
  /// from a hook of the user's own.
  public static let helperName = "multishell"
  /// What builds before this one wrote into a settings file. Those lines are
  /// still there after an update, and still work.
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

  /// Runs the helper rather than `exec`ing it, and exits 0 whatever became of
  /// it; parses in fish as well as sh. See docs/design/agents.md.
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

  /// Which of Claude's fourteen notification types is someone being asked
  /// something. Sorted from the payload, not by matcher; see agents.md.
  public static let claudeQuestions: Set<String> = [
    "permission_prompt", "worker_permission_prompt", "elicitation_dialog",
    "elicitation_url_dialog", "agent_needs_input",
  ]

  /// Claude Code: `~/.claude/settings.json`. The one agent asked for both a
  /// permission request and a notification; see docs/design/agents.md.
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
      AgentHookEvent("PermissionRequest", .attention, onlyWhenPrompting: true, silent: true),
      AgentHookEvent("Notification", .attention, notificationTypes: claudeQuestions),
      AgentHookEvent("Stop", .done),
      AgentHookEvent("StopFailure", .error),
      AgentHookEvent("SessionEnd", .idle),
    ],
    format: .sharedSettings(millisecondTimeout: false))

  /// Codex: `~/.codex/hooks.json`, the JSON half of a file it also accepts as
  /// `[hooks]` in `config.toml`, which is not ours to rewrite.
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
      AgentHookEvent("PermissionRequest", .attention, onlyWhenPrompting: true, silent: true),
      AgentHookEvent("Stop", .done),
      AgentHookEvent("Interrupt", .idle),
      AgentHookEvent("SessionEnd", .idle),
    ],
    format: .sharedSettings(millisecondTimeout: false),
    trustNote:
      t("agent-hooks.codex-trust")
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
  /// file of its own. Event names are its Visual Studio Code spelling.
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

  /// OpenCode has no hooks in its settings: what a session is doing shows only
  /// to a plugin, so it is given one.
  public static let openCode = AgentHookIntegration(
    id: "opencode",
    name: "OpenCode",
    file: home(".config/opencode/plugin/multishell.js"),
    displayPath: "~/.config/opencode/plugin/multishell.js",
    events: [],
    format: .plugin)
}
