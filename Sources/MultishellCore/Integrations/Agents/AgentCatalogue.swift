/// The agents people install, as a static table. Ids are strings in the
/// workspace so a newer build's agent loads harmlessly on an older one.
public enum AgentCatalogue {
  /// A project override that means "no agent here" while the global says
  /// otherwise. A global value of `nil` means the same.
  public static let noneID = "none"
  /// The command the user typed in settings, run as written.
  public static let customID = "custom"
  public static let claudeID = "claude"
  static let codexID = "codex"
  static let geminiID = "gemini"
  static let copilotID = "copilot"
  static let openCodeID = "opencode"
  /// Agents a build before this one offered, which a state file may still name.
  static let retiredIDs: Set<String> = ["aider", "cursor-agent"]

  public static let agents: [AgentDescriptor] = [
    AgentDescriptor(
      id: claudeID, name: "Claude Code", executable: "claude", resumeArguments: ["--continue"],
      fileMentionPrefix: "@", mark: .claude, markTint: "#d97757"),
    AgentDescriptor(
      id: codexID, name: "Codex", executable: "codex", resumeArguments: ["resume", "--last"],
      mark: .codex),
    AgentDescriptor(
      id: geminiID, name: "Gemini CLI", executable: "gemini",
      resumeArguments: ["--resume", "latest"], mark: .gemini, markTint: "#8ab4f8"),
    AgentDescriptor(
      id: copilotID, name: "Copilot CLI", executable: "copilot", resumeArguments: ["--continue"],
      mark: .copilot),
    AgentDescriptor(
      id: openCodeID, name: "OpenCode", executable: "opencode", resumeArguments: ["--continue"],
      mark: .openCode, markTint: "#fab283"),
  ]

  public static func agent(_ id: String) -> AgentDescriptor? {
    agents.first { $0.id == id }
  }

  /// The custom agent command, which runs as written: each placeholder reads
  /// a variable, so no value is ever shell text. See Docs/design/agents.md.
  public static func customCommandLine(
    _ line: String, values: [AgentPlaceholder: String]
  ) -> ShellLine {
    var tokens: [String: (variable: String, value: String)] = [:]
    for (placeholder, value) in values {
      tokens[placeholder.token] = (placeholder.variable, value)
    }
    return ShellLine(line, substituting: tokens)
  }

  /// What is drawn where this id is at a prompt. A command the user typed and
  /// an id a newer build stored have no mark of their own, so they get letters.
  public static func mark(_ id: String) -> AgentMark {
    if let agent = agent(id) { return agent.mark }
    return .monogram(AgentMark.letters(of: id == customID ? t("option.custom-command") : id))
  }

  /// The agent a shell just started. Matched on the executable alone, so
  /// `npx codex` is nobody: a wrapper is not the agent.
  public static func agent(runningCommand command: String) -> AgentDescriptor? {
    let name = command.lowercased()
    return agents.first { $0.executable.lowercased() == name }
  }

  /// What the mark is drawn in, `nil` for the theme's own text colour.
  public static func markTintRGB(_ id: String) -> RGB? {
    agent(id)?.markTint.flatMap(HexColor.parse)
  }

  /// The id in force for a project: its override when it has one, else the
  /// global. `nil` means no agent, whichever side said so.
  static func effectiveID(global: String?, override: String?) -> String? {
    ChosenID.inForce(global: global, override: override, none: noneID)
  }
}
