import Foundation

/// The agents whose hooks Multishell knows how to write, and the one line they
/// all run. See Docs/design/agents.md for why each event was chosen.
public enum AgentHookCatalogue {
  public static let subcommand = "agent-hook"
  /// What builds before this one wrote into a settings file. Those lines are
  /// still there after an update, and still work.
  public static let legacySubcommand = "claude-hook"
  /// An agent kills a hook that runs longer than this. The helper connects,
  /// writes one line and exits; anything longer means the app is wedged.
  static let timeoutSeconds = 5
  /// Codex clamps its exit events' hooks to three seconds and warns at every
  /// start where one asks for more.
  private static let codexExitTimeoutSeconds = 3

  public static func integration(_ id: String) -> AgentHookIntegration? {
    integrations.first { $0.id == id }
  }

  /// `$HOME` first, as the agents themselves read it: the account's home
  /// ignores it, and a test's helper then wrote the developer's own files.
  private static func underHome(_ path: String) -> URL {
    let home = ProcessInfo.processInfo.environment["HOME"]?.presence
    return
      (home.map { URL(fileURLWithPath: $0, isDirectory: true) }
      ?? FileManager.default.homeDirectoryForCurrentUser).appendingPathComponent(path)
  }

  public static let integrations: [AgentHookIntegration] = [
    claude, codex, gemini, copilot, openCode,
  ]

  /// The notification types of Claude's that announce rather than ask, out of
  /// fifteen in its list and two sent outside it. A deny list; see agents.md.
  private static let claudeAnnouncements: Set<String> = [
    "idle_prompt", "agent_completed", "auth_success", "quota_auto_resume_fired",
    "computer_use_enter", "computer_use_exit", "elicitation_complete", "elicitation_response",
    "push_notification",
  ]

  /// Claude Code: `~/.claude/settings.json`, asked for a permission request and a notification.
  /// Subagents go on a roster: `Stop` ends only the main loop, so Done waits for the last one out.
  static let claude = AgentHookIntegration(
    id: AgentCatalogue.claudeID,
    file: underHome(".claude/settings.json"),
    displayPath: "~/.claude/settings.json",
    events: [
      AgentHookEvent("SessionStart", .idle, startsSession: true),
      AgentHookEvent("UserPromptSubmit", .running, isPrompt: true),
      AgentHookEvent("PreToolUse", .running),
      AgentHookEvent("PostToolUse", .running),
      AgentHookEvent(
        "PermissionRequest", .attention, meansWaitingOnlyWhenPrompting: true, isSilent: true),
      AgentHookEvent("Notification", .attention, ignoredNotificationTypes: claudeAnnouncements),
      AgentHookEvent("SubagentStart", .running, subagentPhase: .started),
      AgentHookEvent("SubagentStop", .running, subagentPhase: .ended),
      AgentHookEvent("Stop", .done),
      AgentHookEvent("StopFailure", .failed),
      AgentHookEvent("SessionEnd", .idle),
    ],
    format: .userSettingsFile(timeoutIsInMilliseconds: false),
    resumption: .always, wakingTaskTypes: claudeWakingTaskTypes,
    transcriptQueuesNotices: true)

  /// Claude's own labels for work whose end is announced to the model, read
  /// from its binary; the rest never end or end unannounced. See agents.md.
  private static let claudeWakingTaskTypes: Set<String> = [
    "subagent", "shell", "workflow", "MCP task", "cloud session",
  ]

  /// Codex: `~/.codex/hooks.json`, the JSON half of a file whose `config.toml` half is not ours to
  /// rewrite. It spells its subagent events and their fields as Claude does.
  static let codex = AgentHookIntegration(
    id: AgentCatalogue.codexID,
    file: underHome(".codex/hooks.json"),
    displayPath: "~/.codex/hooks.json",
    events: [
      AgentHookEvent("SessionStart", .idle, startsSession: true),
      AgentHookEvent("UserPromptSubmit", .running, isPrompt: true),
      AgentHookEvent("PreToolUse", .running),
      AgentHookEvent("PostToolUse", .running),
      AgentHookEvent(
        "PermissionRequest", .attention, meansWaitingOnlyWhenPrompting: true, isSilent: true),
      AgentHookEvent("SubagentStart", .running, subagentPhase: .started),
      AgentHookEvent("SubagentStop", .running, subagentPhase: .ended),
      AgentHookEvent("Stop", .done),
      AgentHookEvent("Interrupt", .idle, timeoutSeconds: codexExitTimeoutSeconds),
      AgentHookEvent("SessionEnd", .idle, timeoutSeconds: codexExitTimeoutSeconds),
    ],
    format: .userSettingsFile(timeoutIsInMilliseconds: false),
    trustNote:
      t("agent-hooks.codex-trust")
  )

  /// Gemini CLI: `~/.gemini/settings.json`, whose events are named for what
  /// they come before and after, and whose timeout is in milliseconds.
  static let gemini = AgentHookIntegration(
    id: AgentCatalogue.geminiID,
    file: underHome(".gemini/settings.json"),
    displayPath: "~/.gemini/settings.json",
    events: [
      AgentHookEvent("SessionStart", .idle, startsSession: true),
      AgentHookEvent("BeforeAgent", .running, isPrompt: true),
      AgentHookEvent("BeforeTool", .running),
      AgentHookEvent("AfterTool", .running),
      AgentHookEvent("Notification", .attention),
      AgentHookEvent("AfterAgent", .done),
      AgentHookEvent("SessionEnd", .idle),
    ],
    format: .userSettingsFile(timeoutIsInMilliseconds: true),
    backgroundShellMarker: geminiShellMarker, resumption: .whenGeminiSettingsSay)

  /// In the wrapper every shell-tool command runs in and nothing else does, so
  /// no MCP server matches. Not a documented contract; see agents.md.
  private static let geminiShellMarker = "/gemini-shell-"

  /// Copilot CLI reads every JSON file in `~/.copilot/hooks`. Ours uses its VS Code spelling, where
  /// no SubagentStart names an id, so a worker goes on at its own first event; see agents.md.
  static let copilot = AgentHookIntegration(
    id: AgentCatalogue.copilotID,
    file: underHome(".copilot/hooks/multishell.json"),
    displayPath: "~/.copilot/hooks/multishell.json",
    events: [
      AgentHookEvent("SessionStart", .idle, startsSession: true),
      AgentHookEvent("UserPromptSubmit", .running, isPrompt: true),
      AgentHookEvent("PreToolUse", .running),
      AgentHookEvent("PostToolUse", .running),
      AgentHookEvent(
        "notification", .attention, reportedName: "Notification",
        matcher: "permission_prompt|elicitation_dialog"),
      AgentHookEvent("SubagentStop", .running, subagentPhase: .ended),
      AgentHookEvent("Stop", .done),
      AgentHookEvent("SessionEnd", .idle),
    ],
    format: .ownHookFile, resumption: .always, subagentsAreConversations: true)

  /// OpenCode has no hooks in its settings: what a session is doing shows only
  /// to a plugin, so it is given one.
  static let openCode = AgentHookIntegration(
    id: AgentCatalogue.openCodeID,
    file: underHome(".config/opencode/plugin/multishell.js"),
    displayPath: "~/.config/opencode/plugin/multishell.js",
    events: [],
    format: .plugin)
}
