import Foundation

/// A coding agent the app knows how to start.
public struct AgentDescriptor: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  /// Looked up on the login shell's PATH.
  public let executable: String
  public let launchArguments: [String]
  /// How to resume the last conversation when a saved agent tab comes back.
  /// `nil` means the tab returns as a plain shell.
  public let resumeArguments: [String]?
  /// How this agent is told about a file: `@` for one that reads mentions,
  /// `nil` for a plain path. Only set where the prompt is known to resolve.
  public let fileMentionPrefix: String?
  /// The mark drawn wherever this agent is at a prompt.
  public let mark: AgentMark
  /// The hex `mark` is drawn at. `nil` draws it in the theme's own text
  /// colour, which is what a project mark that is black or white wants.
  public let markTint: String?

  public init(
    id: String, name: String, executable: String, launchArguments: [String] = [],
    resumeArguments: [String]? = nil, fileMentionPrefix: String? = nil,
    mark: AgentMark, markTint: String? = nil
  ) {
    self.id = id
    self.name = name
    self.executable = executable
    self.launchArguments = launchArguments
    self.resumeArguments = resumeArguments
    self.fileMentionPrefix = fileMentionPrefix
    self.mark = mark
    self.markTint = markTint
  }
}

/// The agents people install, as a static table. Ids are strings in the
/// workspace so a newer build's agent loads harmlessly on an older one.
public enum AgentCatalogue {
  /// A project override that means "no agent here" while the global says
  /// otherwise. A global value of `nil` means the same.
  public static let noneID = "none"
  /// The command the user typed in settings, run as written.
  public static let customID = "custom"
  public static let claudeID = "claude"

  public static let agents: [AgentDescriptor] = [
    AgentDescriptor(
      id: claudeID, name: "Claude Code", executable: "claude", resumeArguments: ["--continue"],
      fileMentionPrefix: "@", mark: .claude, markTint: "#d97757"),
    AgentDescriptor(
      id: "codex", name: "Codex", executable: "codex", resumeArguments: ["resume", "--last"],
      mark: .codex),
    AgentDescriptor(
      id: "gemini", name: "Gemini CLI", executable: "gemini",
      resumeArguments: ["--resume", "latest"], mark: .gemini, markTint: "#8ab4f8"),
    AgentDescriptor(
      id: "copilot", name: "Copilot CLI", executable: "copilot", resumeArguments: ["--continue"],
      mark: .copilot),
    AgentDescriptor(
      id: "opencode", name: "OpenCode", executable: "opencode", resumeArguments: ["--continue"],
      mark: .openCode, markTint: "#fab283"),
  ]

  public static func agent(_ id: String) -> AgentDescriptor? {
    agents.first { $0.id == id }
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
    let chosen = override ?? global
    guard let chosen, !chosen.isEmpty, chosen != noneID else { return nil }
    return chosen
  }
}
